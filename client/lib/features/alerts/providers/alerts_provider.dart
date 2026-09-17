import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../system/providers/system_provider.dart';
import '../models/system_alert.dart';

/// Available alert filter criteria.
enum AlertFilter {
  all(label: 'All'),
  active(label: 'Active (Unacknowledged)'),
  critical(label: 'Critical'),
  warning(label: 'Warning');

  const AlertFilter({required this.label});
  final String label;
}

/// Currently selected alert filter in the UI.
final alertFilterProvider = StateProvider<AlertFilter>((ref) {
  return AlertFilter.active;
});

/// Live stream of unacknowledged alert count for the active system.
///
/// Powers the notification badge on the bottom navigation bar and dashboard header.
final unreadAlertsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final systemId = ref.watch(activeSystemIdProvider);
  if (systemId == null) return Stream.value(0);

  final client = ref.watch(supabaseClientProvider);

  return client
      .from('alerts')
      .stream(primaryKey: ['id'])
      .eq('system_id', systemId)
      .map((rows) => rows.where((r) => r['is_acknowledged'] == false).length);
});

/// Manages fetching, filtering, real-time sync, and acknowledging of alerts.
final alertsProvider =
    AutoDisposeAsyncNotifierProvider<AlertsNotifier, List<SystemAlert>>(
        AlertsNotifier.new);

class AlertsNotifier extends AutoDisposeAsyncNotifier<List<SystemAlert>> {
  @override
  Future<List<SystemAlert>> build() async {
    final systemId = ref.watch(activeSystemIdProvider);
    if (systemId == null) return [];

    // Also listen to Supabase realtime so new alerts refresh the state
    _subscribeToAlerts(systemId);

    return _fetchAlerts(systemId);
  }

  void _subscribeToAlerts(String systemId) {
    final client = ref.read(supabaseClientProvider);
    final subscription = client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('system_id', systemId)
        .listen((rows) {
      if (state.hasValue) {
        final existingAlerts = state.value!;
        final incoming = rows.map((r) => SystemAlert.fromJson(r)).toList();

        // Merge without duplicating
        final map = {for (final a in existingAlerts) a.id: a};
        for (final a in incoming) {
          map[a.id] = a;
        }

        final merged = map.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = AsyncData(merged);
      }
    });

    ref.onDispose(subscription.cancel);
  }

  Future<List<SystemAlert>> _fetchAlerts(String systemId) async {
    // 1. Try fetching via FastAPI backend endpoint
    try {
      final url = Uri.parse(
        '${AppConfig.backendBaseUrl}/alerts?system_id=$systemId&limit=100',
      );
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final alertList = json['alerts'] as List<dynamic>? ?? [];
        return alertList
            .map((item) => SystemAlert.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Backend error/timeout, fall back to direct Supabase query
    }

    // 2. Direct Supabase fallback
    final client = ref.read(supabaseClientProvider);
    final rows = await client
        .from('alerts')
        .select()
        .eq('system_id', systemId)
        .order('created_at', ascending: false)
        .limit(100);

    return (rows as List<dynamic>)
        .map((r) => SystemAlert.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Mark an alert as acknowledged.
  Future<void> acknowledgeAlert(String alertId) async {
    final previousState = state.value ?? [];

    // Optimistic update
    state = AsyncData([
      for (final a in previousState)
        if (a.id == alertId)
          a.copyWith(
            isAcknowledged: true,
            acknowledgedAt: DateTime.now(),
          )
        else
          a,
    ]);

    final client = ref.read(supabaseClientProvider);
    final currentUserId = client.auth.currentUser?.id;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final ackPayload = <String, dynamic>{};
    if (currentUserId != null) {
      ackPayload['acknowledged_by'] = currentUserId;
    }

    final supabaseUpdateData = <String, dynamic>{
      'is_acknowledged': true,
      'acknowledged_at': nowIso,
    };
    if (currentUserId != null) {
      supabaseUpdateData['acknowledged_by'] = currentUserId;
    }

    try {
      final url = Uri.parse(
        '${AppConfig.backendBaseUrl}/alerts/$alertId/acknowledge',
      );
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(ackPayload),
      ).timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) {
        // Fallback: direct Supabase update
        await client.from('alerts').update(supabaseUpdateData).eq('id', alertId);
      }
    } catch (_) {
      // Fallback: direct Supabase update
      try {
        await client.from('alerts').update(supabaseUpdateData).eq('id', alertId);
      } catch (e) {
        // Rollback on fatal failure
        state = AsyncData(previousState);
        rethrow;
      }
    }
  }
}

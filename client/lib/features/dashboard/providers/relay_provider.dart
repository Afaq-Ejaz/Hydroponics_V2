import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../system/providers/system_provider.dart';

/// Provider managing the active relay (pump/actuator) state for the primary device.
final relayStateProvider =
    AutoDisposeAsyncNotifierProvider<RelayStateNotifier, bool>(
        RelayStateNotifier.new);

class RelayStateNotifier extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final device = ref.watch(primaryDeviceProvider);
    if (device == null) return false;

    return _fetchRelayState(device.id);
  }

  Future<bool> _fetchRelayState(String deviceId) async {
    try {
      final url = Uri.parse(
        '${AppConfig.backendBaseUrl}/devices/$deviceId/relay-state',
      );
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['relay_on'] as bool? ?? false;
      }
    } catch (_) {
      // Backend offline or unreachable
    }
    return false;
  }

  /// Toggle or explicitly set the relay state.
  Future<void> toggleRelay(bool desiredState) async {
    final device = ref.read(primaryDeviceProvider);
    if (device == null) return;

    final previousState = state.valueOrNull ?? false;
    // Optimistic update
    state = AsyncData(desiredState);

    try {
      final url = Uri.parse(
        '${AppConfig.backendBaseUrl}/devices/${device.id}/relay-state',
      );
      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'relay_on': desiredState}),
          )
          .timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) {
        // Rollback
        state = AsyncData(previousState);
        throw Exception('Failed to update relay state (HTTP ${response.statusCode})');
      }
    } catch (e) {
      state = AsyncData(previousState);
      rethrow;
    }
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../system/providers/system_provider.dart';

/// Model for a single pump event.
class PumpEvent {
  final String id;
  final String message;
  final DateTime createdAt;
  final bool isPumpOn;

  PumpEvent({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.isPumpOn,
  });

  factory PumpEvent.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as String? ?? '';
    return PumpEvent(
      id: json['id'] as String? ?? '',
      message: message,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPumpOn: message.contains('ON'),
    );
  }
}

/// Provider that fetches pump history from the backend.
final pumpHistoryProvider =
    FutureProvider.autoDispose<List<PumpEvent>>((ref) async {
  final device = ref.watch(primaryDeviceProvider);
  if (device == null) return [];

  final url = Uri.parse(
    '${AppConfig.backendBaseUrl}/devices/${device.id}/pump-history?limit=50',
  );

  try {
    final response = await http.get(url).timeout(AppConfig.httpTimeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final events = (data['events'] as List<dynamic>?) ?? [];
      return events
          .map((e) => PumpEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {
    // Backend offline
  }
  return [];
});

/// History screen showing pump ON/OFF events with timestamps.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pumpHistoryAsync = ref.watch(pumpHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Pump History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(pumpHistoryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Water pump activity log',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),

            // ── Event List ──────────────────────────────────────────
            Expanded(
              child: pumpHistoryAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => _buildErrorState(context, ref),
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState();
                  }
                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(pumpHistoryProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildEventCard(context, events[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, PumpEvent event) {
    final isOn = event.isPumpOn;
    final timeStr = DateFormat('MMM d, yyyy – h:mm a').format(event.createdAt.toLocal());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOn
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // ── Status icon ──
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOn
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOn
                  ? Icons.power_settings_new_rounded
                  : Icons.power_off_rounded,
              size: 20,
              color: isOn ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 14),

          // ── Details ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOn ? 'Pump Turned ON' : 'Pump Turned OFF',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOn
                            ? AppColors.primarySurface
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isOn ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOn
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 64,
            color: AppColors.textTertiary,
          ),
          SizedBox(height: 16),
          Text(
            'No pump events yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Toggle the pump from the dashboard to see history',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load pump history',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => ref.invalidate(pumpHistoryProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

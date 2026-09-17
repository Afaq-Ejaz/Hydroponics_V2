import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../system/providers/system_provider.dart';
import '../models/sensor_meta.dart';
import '../providers/device_status_provider.dart';
import '../providers/sensor_stream_provider.dart';
import '../widgets/device_status_badge.dart';
import '../widgets/sensor_card.dart';
import '../widgets/system_status_banner.dart';

/// Live sensor dashboard — the heart of the HAT app.
///
/// Consumes:
/// - [sensorStreamProvider] for real-time sensor values (Step 5)
/// - [deviceStatusProvider] for online/offline badge (Step 6)
/// - [activeSystemProvider] for system context (Step 4)
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensorAsync = ref.watch(sensorStreamProvider);
    final deviceStatusAsync = ref.watch(deviceStatusProvider);
    final activeSystem = ref.watch(activeSystemProvider);

    final deviceStatus = deviceStatusAsync.valueOrNull;
    final reading = sensorAsync.valueOrNull;

    // Check if ANY sensor value is null for the footnote
    final hasNullValues = reading == null ||
        SensorMeta.all.any(
            (meta) => reading.valueForField(meta.fieldName) == null);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Smart IoT Hub'),
        actions: [
          // Online/Offline badge
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DeviceStatusBadge(status: deviceStatus),
          ),
          IconButton(
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_outlined),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          // Invalidate the one-shot provider to force a refetch
          ref.invalidate(latestReadingProvider);
          ref.invalidate(deviceStatusProvider);
          // Small delay to show the indicator
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Status Banner ───────────────────────────────────────
              SystemStatusBanner(
                deviceStatus: deviceStatus,
                systemName: activeSystem?.name ?? 'Hydroponics',
                isLoading: deviceStatusAsync.isLoading,
              ),

              const SizedBox(height: 24),

              // ── Section Title ───────────────────────────────────────
              Text(
                activeSystem?.name ?? 'Hydroponics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              _buildAutoRefreshingLabel(context, reading),

              const SizedBox(height: 16),

              // ── Sensor Grid: Loading State ─────────────────────────
              if (sensorAsync.isLoading && reading == null)
                _buildLoadingGrid(context),

              // ── Sensor Grid: Error State ───────────────────────────
              if (sensorAsync.hasError && reading == null)
                _buildErrorState(context, ref, sensorAsync.error),

              // ── Sensor Grid: Data ──────────────────────────────────
              if (reading != null || !sensorAsync.isLoading)
                _buildSensorGrid(context, reading),

              // ── Footnote ───────────────────────────────────────────
              if (hasNullValues) ...[
                const SizedBox(height: 16),
                Text(
                  '* Sensor not connected or data unavailable',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 600.ms),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Sub-builders
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAutoRefreshingLabel(
      BuildContext context, dynamic reading) {
    final lastUpdated = reading?.recordedAt;
    final timeText = lastUpdated != null
        ? DateFormat.jm().format(lastUpdated.toLocal())
        : null;

    return Row(
      children: [
        Text(
          'Auto-refreshing',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
        if (timeText != null) ...[
          const Spacer(),
          Text(
            'Last: $timeText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildSensorGrid(BuildContext context, dynamic reading) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: SensorMeta.all.map((meta) {
        final value = reading?.valueForField(meta.fieldName) as double?;
        return SensorCard(
          meta: meta,
          value: value,
          showFootnoteMarker: value == null,
        );
      }).toList(),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildLoadingGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: SensorMeta.all.map((meta) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 20, color: meta.color),
              ),
              const Spacer(),
              Text(meta.label,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              SizedBox(
                width: 48,
                height: 12,
                child: LinearProgressIndicator(
                  color: meta.color.withValues(alpha: 0.4),
                  backgroundColor: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1500.ms, color: AppColors.border);
  }

  Widget _buildErrorState(
      BuildContext context, WidgetRef ref, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.alertCritical),
            const SizedBox(height: 12),
            Text(
              'Failed to load sensor data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(sensorStreamProvider);
                ref.invalidate(deviceStatusProvider);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

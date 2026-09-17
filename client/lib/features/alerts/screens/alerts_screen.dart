import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../system/providers/system_provider.dart';
import '../models/system_alert.dart';
import '../providers/alerts_provider.dart';
import '../widgets/alert_card.dart';

/// Step 8: Complete Alert Management screen with filtering and live acknowledgment.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSystem = ref.watch(activeSystemProvider);
    final alertsAsync = ref.watch(alertsProvider);
    final filter = ref.watch(alertFilterProvider);
    final unreadCount = ref.watch(unreadAlertsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(activeSystem?.name != null
            ? '${activeSystem!.name} Alerts'
            : 'Alerts & Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Alerts',
            onPressed: () => ref.invalidate(alertsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Header & Filter Bar ───────────────────────────────────
          Container(
            color: AppColors.cardBackground,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Alert Center',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.alertCritical.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount active',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.alertCritical,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'All clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: AlertFilter.values.map((f) {
                      final isSelected = f == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f.label),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(alertFilterProvider.notifier).state = f;
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.surfaceVariant,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Alerts List ───────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(alertsProvider);
                await ref.read(alertsProvider.future);
              },
              child: alertsAsync.when(
                data: (alerts) => _buildAlertsList(context, ref, alerts, filter),
                loading: () => _buildLoadingSkeleton(),
                error: (error, _) => _buildErrorState(context, ref, error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList(
    BuildContext context,
    WidgetRef ref,
    List<SystemAlert> alerts,
    AlertFilter filter,
  ) {
    // Apply filter
    final filtered = alerts.where((a) {
      switch (filter) {
        case AlertFilter.all:
          return true;
        case AlertFilter.active:
          return !a.isAcknowledged;
        case AlertFilter.critical:
          return a.severity == AlertSeverity.critical;
        case AlertFilter.warning:
          return a.severity == AlertSeverity.warning;
      }
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                filter == AlertFilter.active
                    ? 'No Active Alerts'
                    : 'No Matching Alerts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                filter == AlertFilter.active
                    ? 'All system thresholds are nominal and all past events are acknowledged.'
                    : 'No alerts match the selected criteria.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final alert = filtered[index];
        return AlertCard(
          key: ValueKey(alert.id),
          alert: alert,
          onAcknowledge: () async {
            try {
              await ref.read(alertsProvider.notifier).acknowledgeAlert(alert.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Alert acknowledged'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to acknowledge alert. Please retry.'),
                    backgroundColor: AppColors.alertCritical,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 40))
            .slideY(begin: 0.04, end: 0);
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: AppColors.border.withValues(alpha: 0.5),
            );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sync_problem_rounded,
                size: 56, color: AppColors.alertCritical),
            const SizedBox(height: 16),
            Text(
              'Failed to load alerts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please check network connectivity or backend status.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(alertsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

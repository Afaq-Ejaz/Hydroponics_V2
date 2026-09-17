import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../dashboard/providers/device_status_provider.dart';
import '../../dashboard/widgets/device_status_badge.dart';
import '../../system/providers/system_provider.dart';
import '../models/hourly_telemetry.dart';
import '../providers/charts_provider.dart';
import '../widgets/telemetry_chart_card.dart';

/// Step 7: Historical Telemetry Charts screen matching the Figma design.
class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSystem = ref.watch(activeSystemProvider);
    final deviceStatus = ref.watch(deviceStatusProvider).valueOrNull;
    final category = ref.watch(chartCategoryProvider);
    final timeRange = ref.watch(chartTimeRangeProvider);
    final telemetryAsync = ref.watch(hourlyTelemetryProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(activeSystem?.name ?? 'Sensor Analytics'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DeviceStatusBadge(status: deviceStatus),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Charts',
            onPressed: () => ref.invalidate(hourlyTelemetryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Header & Filter Chips ─────────────────────────────────
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
                      'System Sensor Trends',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    Text(
                      'Aggregated Rollups',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ChartCategory.values.map((cat) {
                      final isSelected = cat == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.label),
                          selected: isSelected,
                          onSelected: (_) {
                            ref.read(chartCategoryProvider.notifier).state = cat;
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

          // ── Scrollable Chart Feed ─────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(hourlyTelemetryProvider);
                await ref.read(hourlyTelemetryProvider.future);
              },
              child: telemetryAsync.when(
                data: (data) => _buildChartList(context, data, category),
                loading: () => _buildLoadingSkeleton(),
                error: (error, _) => _buildErrorState(context, ref, error),
              ),
            ),
          ),

          // ── Bottom Time Range Selector ────────────────────────────
          _buildTimeRangeBar(context, ref, timeRange),
        ],
      ),
    );
  }

  Widget _buildChartList(
    BuildContext context,
    List<HourlyTelemetry> data,
    ChartCategory category,
  ) {
    final showNutrient =
        category == ChartCategory.all || category == ChartCategory.phAndEc;
    final showThermal =
        category == ChartCategory.all || category == ChartCategory.temperature;
    final showClimate =
        category == ChartCategory.all || category == ChartCategory.environment;
    final showReservoir =
        category == ChartCategory.all || category == ChartCategory.water;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (showNutrient)
          TelemetryChartCard(
            title: 'Nutrient Balance',
            subtitle: 'pH & Electrical Conductivity',
            data: data,
            series: const [
              ChartSeriesConfig(
                name: 'pH Level',
                fieldName: 'ph',
                color: AppColors.sensorPh,
                unit: 'pH',
                targetMin: 5.5,
                targetMax: 6.5,
              ),
              ChartSeriesConfig(
                name: 'EC / TDS',
                fieldName: 'ec',
                color: AppColors.sensorEc,
                unit: 'µS/cm',
                targetMin: 1.2,
                targetMax: 2.0,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

        if (showThermal)
          TelemetryChartCard(
            title: 'Thermal Dynamics',
            subtitle: 'Water vs. Ambient Temperature',
            data: data,
            series: const [
              ChartSeriesConfig(
                name: 'Water Temp',
                fieldName: 'water_temperature',
                color: AppColors.sensorWaterTemp,
                unit: '°C',
                targetMin: 18.0,
                targetMax: 24.0,
              ),
              ChartSeriesConfig(
                name: 'Air Temp',
                fieldName: 'air_temperature',
                color: AppColors.sensorAirTemp,
                unit: '°C',
                targetMin: 20.0,
                targetMax: 28.0,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),

        if (showClimate)
          TelemetryChartCard(
            title: 'Climate Monitoring',
            subtitle: 'Relative Humidity & Substrate Moisture',
            data: data,
            series: const [
              ChartSeriesConfig(
                name: 'Humidity',
                fieldName: 'humidity',
                color: AppColors.sensorHumidity,
                unit: '%',
                targetMin: 50.0,
                targetMax: 75.0,
              ),
              ChartSeriesConfig(
                name: 'Moisture',
                fieldName: 'moisture',
                color: AppColors.sensorMoisture,
                unit: '%',
                targetMin: 60.0,
                targetMax: 85.0,
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),

        if (showReservoir)
          TelemetryChartCard(
            title: 'Reservoir & Water Flow',
            subtitle: 'Water Level Tracking & Flow Sensor Rate',
            data: data,
            series: const [
              ChartSeriesConfig(
                name: 'Water Level',
                fieldName: 'water_level',
                color: AppColors.sensorWaterLevel,
                unit: '%',
                targetMin: 40.0,
                targetMax: 90.0,
              ),
              ChartSeriesConfig(
                name: 'Flow Rate',
                fieldName: 'flow_rate',
                color: AppColors.sensorFlow,
                unit: 'L/min',
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, end: 0),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTimeRangeBar(
    BuildContext context,
    WidgetRef ref,
    ChartTimeRange currentRange,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: const Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: ChartTimeRange.values.map((range) {
              final isSelected = range == currentRange;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(chartTimeRangeProvider.notifier).state = range;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: 240,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
        ).animate(onPlay: (c) => c.repeat()).shimmer(
              duration: 1200.ms,
              color: AppColors.border.withValues(alpha: 0.5),
            );
      },
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    Object? error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AppColors.alertCritical),
            const SizedBox(height: 16),
            Text(
              'Could not load chart data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Backend service may be offline or unreachable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(hourlyTelemetryProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

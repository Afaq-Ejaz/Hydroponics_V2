import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/hourly_telemetry.dart';

/// Configuration for a single data series plotted on the chart.
class ChartSeriesConfig {
  const ChartSeriesConfig({
    required this.name,
    required this.fieldName,
    required this.color,
    required this.unit,
    this.targetMin,
    this.targetMax,
    this.isBarChart = false,
  });

  final String name;
  final String fieldName;
  final Color color;
  final String unit;
  final double? targetMin;
  final double? targetMax;
  final bool isBarChart;
}

/// A premium, concise card displaying 1 or 2 historical trend lines with fl_chart.
class TelemetryChartCard extends StatefulWidget {
  const TelemetryChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.series,
    required this.data,
  });

  final String title;
  final String subtitle;
  final List<ChartSeriesConfig> series;
  final List<HourlyTelemetry> data;

  @override
  State<TelemetryChartCard> createState() => _TelemetryChartCardState();
}

class _TelemetryChartCardState extends State<TelemetryChartCard> {
  @override
  Widget build(BuildContext context) {
    // Reverse data so oldest is on the left and newest is on the right
    final sortedData = widget.data.reversed.toList();

    // Check if any series actually has non-null data points
    final seriesHasData = <String, bool>{};
    for (final s in widget.series) {
      seriesHasData[s.fieldName] = sortedData.any(
        (item) => item.valueForField(s.fieldName) != null,
      );
    }

    final hasAnyData = seriesHasData.values.any((hasData) => hasData);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title & Subtitle ──────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Chart Area ────────────────────────────────────────────
          SizedBox(
            height: 180,
            child: sortedData.isEmpty || !hasAnyData
                ? _buildEmptyState()
                : _buildChart(sortedData, seriesHasData),
          ),

          const SizedBox(height: 14),

          // ── Legend & Probe Connection Status ──────────────────────
          _buildLegend(seriesHasData),
        ],
      ),
    );
  }

  Widget _buildTargetBadges() {
    final targets = widget.series.where((s) => s.targetMin != null && s.targetMax != null).toList();
    if (targets.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      children: targets.map((t) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: t.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.color.withValues(alpha: 0.2)),
          ),
          child: Text(
            'Target: ${t.targetMin}–${t.targetMax} ${t.unit}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: t.color,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.query_builder_rounded,
              size: 36, color: AppColors.textTertiary.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          const Text(
            'No telemetry recorded yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Values will appear once readings are aggregated',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(
    List<HourlyTelemetry> sortedData,
    Map<String, bool> seriesHasData,
  ) {
    final lineBars = <LineChartBarData>[];

    for (final s in widget.series) {
      if (!(seriesHasData[s.fieldName] ?? false)) continue;

      final spots = <FlSpot>[];
      for (int i = 0; i < sortedData.length; i++) {
        final val = sortedData[i].valueForField(s.fieldName);
        if (val != null) {
          spots.add(FlSpot(i.toDouble(), val));
        }
      }

      if (spots.isEmpty) continue;

      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: s.color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: spots.length <= 5,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 3,
              color: Colors.white,
              strokeWidth: 2,
              strokeColor: s.color,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.22),
                s.color.withValues(alpha: 0.01),
              ],
            ),
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        lineBarsData: lineBars,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null, // fl_chart auto calculates intervals
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withValues(alpha: 0.8),
            strokeWidth: 0.8,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(value < 10 ? 1 : 0),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: sortedData.length > 10 ? (sortedData.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedData.length) {
                  return const SizedBox.shrink();
                }
                final bucket = sortedData[index].bucket.toLocal();
                final isToday = sortedData.length <= 24;
                final label = isToday
                    ? DateFormat.Hm().format(bucket)
                    : DateFormat.Md().format(bucket);

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary.withValues(alpha: 0.9),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final seriesConfig = widget.series.firstWhere(
                  (s) => s.color == spot.bar.color,
                  orElse: () => widget.series.first,
                );
                return LineTooltipItem(
                  '${seriesConfig.name}: ${spot.y.toStringAsFixed(1)} ${seriesConfig.unit}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(Map<String, bool> seriesHasData) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: widget.series.map((s) {
        final hasData = seriesHasData[s.fieldName] ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: hasData ? s.color : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              s.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasData ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ),
            if (!hasData) ...[
              const SizedBox(width: 4),
              Text(
                '(offline)',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}

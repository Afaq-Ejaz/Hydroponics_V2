import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/sensor_meta.dart';

/// A single sensor gauge card matching the Figma dashboard design.
///
/// Shows the sensor icon, label, current value + unit, and an accent colour.
/// When [value] is `null`, displays `--` with an optional `*` footnote marker.
class SensorCard extends StatelessWidget {
  const SensorCard({
    super.key,
    required this.meta,
    required this.value,
    this.showFootnoteMarker = false,
  });

  /// Metadata (label, unit, icon, colour) for this sensor.
  final SensorMeta meta;

  /// Current live value, or `null` if no data / sensor disconnected.
  final double? value;

  /// If `true`, appends a `*` superscript when value is null.
  final bool showFootnoteMarker;

  @override
  Widget build(BuildContext context) {
    final displayValue = meta.formatValue(value);
    final isNull = value == null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Icon badge ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 20, color: meta.color),
              ),
            ],
          ),

          const Spacer(),

          // ── Label ──
          Text(
            meta.label,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),

          // ── Value + unit ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  displayValue,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isNull
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isNull && showFootnoteMarker)
                Text(
                  ' *',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              if (!isNull) ...[
                const SizedBox(width: 4),
                Text(
                  meta.unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

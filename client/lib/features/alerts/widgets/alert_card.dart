import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../models/system_alert.dart';

/// Interactive card representing an individual alert.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.alert,
    required this.onAcknowledge,
    this.isAcknowledging = false,
  });

  final SystemAlert alert;
  final VoidCallback onAcknowledge;
  final bool isAcknowledging;

  @override
  Widget build(BuildContext context) {
    final severity = alert.severity;
    final formattedTime = DateFormat('MMM d, h:mm a').format(alert.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert.isAcknowledged
              ? AppColors.border
              : severity.color.withValues(alpha: 0.3),
          width: alert.isAcknowledged ? 0.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Severity badge, Device & Timestamp ──────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severity.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(severity.icon, size: 14, color: severity.color),
                      const SizedBox(width: 4),
                      Text(
                        severity.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: severity.color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alert.deviceId != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      alert.deviceId!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Message ───────────────────────────────────────────────
            Text(
              alert.message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: alert.isAcknowledged ? FontWeight.w500 : FontWeight.w600,
                color: alert.isAcknowledged
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 14),

            // ── Bottom Row: Status / Action ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (alert.isAcknowledged)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Acknowledged',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryDark.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'Requires attention',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textTertiary,
                    ),
                  ),

                if (!alert.isAcknowledged)
                  FilledButton.tonalIcon(
                    onPressed: isAcknowledging ? null : onAcknowledge,
                    icon: isAcknowledging
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Acknowledge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySurface,
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../models/device_status.dart';

/// Banner at the top of the dashboard showing system health.
///
/// - Green when all devices are online.
/// - Red with device name when any device is offline.
/// - Neutral when status is still loading.
class SystemStatusBanner extends StatelessWidget {
  const SystemStatusBanner({
    super.key,
    required this.deviceStatus,
    required this.systemName,
    this.isLoading = false,
  });

  final DeviceStatus? deviceStatus;
  final String systemName;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isOnline = deviceStatus?.isOnline ?? false;
    final hasStatus = deviceStatus != null;

    final Color bgColor;
    final Color textColor;
    final Color dotColor;
    final String message;

    if (isLoading || !hasStatus) {
      bgColor = AppColors.surfaceVariant;
      textColor = AppColors.textSecondary;
      dotColor = AppColors.textTertiary;
      message = 'Checking system status…';
    } else if (isOnline) {
      bgColor = AppColors.primarySurface;
      textColor = AppColors.primaryDark;
      dotColor = AppColors.online;
      message = 'System Active • All Systems Operational';
    } else {
      bgColor = AppColors.offline.withValues(alpha: 0.08);
      textColor = AppColors.offline;
      dotColor = AppColors.offline;
      final ago = deviceStatus!.minutesSinceLastSeen;
      final agoText = ago != null ? ' (${ago.round()} min ago)' : '';
      message = 'Device Offline$agoText';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.05, end: 0);
  }
}

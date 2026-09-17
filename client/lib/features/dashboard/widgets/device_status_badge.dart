import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/device_status.dart';

/// Green/red pill badge showing the device's online/offline state.
class DeviceStatusBadge extends StatelessWidget {
  const DeviceStatusBadge({
    super.key,
    required this.status,
  });

  final DeviceStatus? status;

  @override
  Widget build(BuildContext context) {
    final isOnline = status?.isOnline ?? false;
    final label = status != null
        ? (isOnline ? 'ONLINE' : 'OFFLINE')
        : 'UNKNOWN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.online.withValues(alpha: 0.1)
            : AppColors.offline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
              ? AppColors.online.withValues(alpha: 0.3)
              : AppColors.offline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            color: isOnline ? AppColors.online : AppColors.offline,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isOnline ? AppColors.online : AppColors.offline,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/relay_provider.dart';

/// Step 9: Interactive Relay Control Card on the dashboard.
class RelayControlCard extends ConsumerStatefulWidget {
  const RelayControlCard({super.key});

  @override
  ConsumerState<RelayControlCard> createState() => _RelayControlCardState();
}

class _RelayControlCardState extends ConsumerState<RelayControlCard> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final relayStateAsync = ref.watch(relayStateProvider);
    final isOn = relayStateAsync.valueOrNull ?? false;
    final isLoading = relayStateAsync.isLoading || _isSwitching;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOn ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
          width: isOn ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isOn
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon indicator ──────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOn ? AppColors.primarySurface : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 22,
              color: isOn ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 14),

          // ── Description ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Actuator Relay',
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
                        isOn ? 'ENGAGED' : 'STANDBY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOn ? AppColors.primary : AppColors.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOn
                      ? 'Water pump & irrigation circuit active'
                      : 'Actuator circuit powered off',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),

          // ── Switch Control ──────────────────────────────────────────
          if (_isSwitching)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Switch.adaptive(
              value: isOn,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.4),
              inactiveThumbColor: AppColors.textTertiary,
              inactiveTrackColor: AppColors.surfaceVariant,
              onChanged: isLoading
                  ? null
                  : (bool newValue) async {
                      setState(() => _isSwitching = true);
                      try {
                        await ref
                            .read(relayStateProvider.notifier)
                            .toggleRelay(newValue);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to update relay state. Backend may be offline.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isSwitching = false);
                        }
                      }
                    },
            ),
        ],
      ),
    );
  }
}

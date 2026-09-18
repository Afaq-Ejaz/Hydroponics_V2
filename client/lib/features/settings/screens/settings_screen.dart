import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../system/providers/system_provider.dart';

/// Settings screen with profile info, system info, about, and sign-out.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull?.user;
    final system = ref.watch(activeSystemProvider);
    final device = ref.watch(primaryDeviceProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    _getInitials(user?.userMetadata?['full_name'] as String? ??
                        user?.email ??
                        '?'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.userMetadata?['full_name'] as String? ??
                            'User',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Settings Items ────────────────────────────────────────
          _buildSectionTitle(context, 'General'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                // ── Profile Expandable ──
                _ExpandableSettingsTile(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Manage your account',
                  expandedContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name',
                          user?.userMetadata?['full_name'] as String? ??
                              'Not set'),
                      _buildInfoRow('Email', user?.email ?? 'Unknown'),
                      _buildInfoRow(
                          'User ID',
                          user?.id?.substring(0, 8) ?? 'N/A'),
                      _buildInfoRow(
                        'Created',
                        user?.createdAt != null
                            ? _formatDate(user!.createdAt)
                            : 'N/A',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── System Info Expandable ──
                _ExpandableSettingsTile(
                  icon: Icons.memory_outlined,
                  title: 'System Info',
                  subtitle: 'View connected devices',
                  expandedContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('System', system?.name ?? 'Not linked'),
                      _buildInfoRow(
                          'Device ID', device?.id ?? 'No device'),
                      _buildInfoRow('Device Name',
                          device?.name ?? 'Unknown'),
                      _buildInfoRow(
                          'Active',
                          device?.isActive == true ? 'Yes' : 'No'),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── About Expandable ──
                _ExpandableSettingsTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'HAT v2.0.0',
                  expandedContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('App', 'HAT - Hydroponics Automation'),
                      _buildInfoRow('Version', '2.0.0'),
                      _buildInfoRow('Backend', 'FastAPI + Supabase'),
                      _buildInfoRow('Hardware', 'ESP32-S3 DevKitC-1'),
                      _buildInfoRow('Sensors',
                          'pH, EC, Moisture, DHT22, Ultrasonic, Flow'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Sign Out ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleSignOut(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.alertCritical),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.alertCritical),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.alertCritical),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.alertCritical),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An expandable settings tile with smooth animation.
class _ExpandableSettingsTile extends StatefulWidget {
  const _ExpandableSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.expandedContent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget expandedContent;

  @override
  State<_ExpandableSettingsTile> createState() =>
      _ExpandableSettingsTileState();
}

class _ExpandableSettingsTileState extends State<_ExpandableSettingsTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isExpanded
                  ? AppColors.primarySurface
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: _isExpanded
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
          title: Text(widget.title,
              style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(widget.subtitle,
              style: Theme.of(context).textTheme.bodySmall),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.chevron_right,
                color: AppColors.textTertiary),
          ),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.scaffoldBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.expandedContent,
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}

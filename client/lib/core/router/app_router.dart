import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/providers/alerts_provider.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/charts/screens/charts_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/system/providers/system_provider.dart';
import '../../features/system/screens/no_system_screen.dart';
import '../theme/app_colors.dart';

/// Navigation key for the shell route (bottom nav).
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter provider — rebuilds routes when auth state changes.
///
/// The redirect logic watches [authProvider]:
/// - Signed out → redirect to `/login`
/// - Signed in → redirect to `/dashboard`
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    debugLogDiagnostics: false,

    // ── Auth redirect ─────────────────────────────────────────────────
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      final isNoSystemRoute = state.matchedLocation == '/no-system';

      // Not logged in and not on an auth page → go to login
      if (!isLoggedIn && !isAuthRoute) return '/login';

      // Logged in but on an auth page → go to dashboard
      if (isLoggedIn && isAuthRoute) return '/dashboard';

      // No-system route is only valid when logged in
      if (isNoSystemRoute && !isLoggedIn) return '/login';

      // No redirect needed
      return null;
    },

    // ── Routes ────────────────────────────────────────────────────────
    routes: [
      // Auth routes (no bottom nav)
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),

      // No-system fallback
      GoRoute(
        path: '/no-system',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NoSystemScreen(),
      ),

      // App shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return _SystemContextGate(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/charts',
            builder: (context, state) => const ChartsScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Wraps the app shell to ensure the system context is loaded before
/// showing any dashboard screen.
///
/// On first load after login:
/// 1. Fetches the user's systems via [userSystemsProvider].
/// 2. Auto-selects the first system into [activeSystemProvider].
/// 3. If the user has 0 systems, redirects to `/no-system`.
///
/// Once loaded, the child (dashboard/charts/etc.) renders normally.
class _SystemContextGate extends ConsumerStatefulWidget {
  const _SystemContextGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_SystemContextGate> createState() =>
      _SystemContextGateState();
}

class _SystemContextGateState extends ConsumerState<_SystemContextGate> {
  bool _hasAutoSelected = false;

  @override
  Widget build(BuildContext context) {
    final systemsAsync = ref.watch(userSystemsProvider);
    final activeSystem = ref.watch(activeSystemProvider);
    final currentIndex = _currentIndex(context);

    // If systems are still loading, show a spinner inside the shell
    if (systemsAsync.isLoading) {
      return _buildShell(
        context,
        currentIndex,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // If there was an error fetching systems
    if (systemsAsync.hasError) {
      return _buildShell(
        context,
        currentIndex,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.alertCritical),
              const SizedBox(height: 12),
              Text('Failed to load systems',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(userSystemsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final systems = systemsAsync.value!;

    // No systems → redirect to no-system screen
    if (systems.isEmpty) {
      // Use addPostFrameCallback to avoid build-phase navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/no-system');
      });
      return const SizedBox.shrink();
    }

    // Auto-select first system if not yet selected
    if (activeSystem == null && !_hasAutoSelected) {
      _hasAutoSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeSystemProvider.notifier).select(systems.first);
      });
      return _buildShell(
        context,
        currentIndex,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // System is selected — render the actual screen
    return _buildShell(context, currentIndex, child: widget.child);
  }

  /// Map of tab paths in order.
  static const _tabs = [
    '/dashboard',
    '/charts',
    '/history',
    '/alerts',
    '/settings',
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexOf(location);
    return index >= 0 ? index : 0;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_tabs[index]);
  }

  Widget _buildShell(BuildContext context, int currentIndex,
      {required Widget child}) {
    final unreadAlerts = ref.watch(unreadAlertsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onTap(context, index),
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 64,
            indicatorColor: AppColors.primarySurface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon:
                    Icon(Icons.grid_view_rounded, color: AppColors.primary),
                label: 'Dashboard',
              ),
              const NavigationDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon:
                    Icon(Icons.show_chart_rounded, color: AppColors.primary),
                label: 'Charts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon:
                    Icon(Icons.history_rounded, color: AppColors.primary),
                label: 'History',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('$unreadAlerts'),
                  isLabelVisible: unreadAlerts > 0,
                  backgroundColor: AppColors.alertCritical,
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  label: Text('$unreadAlerts'),
                  isLabelVisible: unreadAlerts > 0,
                  backgroundColor: AppColors.alertCritical,
                  child: const Icon(Icons.notifications_rounded,
                      color: AppColors.primary),
                ),
                label: 'Alerts',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon:
                    Icon(Icons.settings_rounded, color: AppColors.primary),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

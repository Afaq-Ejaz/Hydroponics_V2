import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../models/device.dart';
import '../models/hydroponic_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  User's Systems
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches ALL hydroponic systems the current user belongs to via the
/// `system_members` ↔ `hydroponic_systems` join.
///
/// Returns an empty list (not an error) when the user has no memberships.
final userSystemsProvider =
    FutureProvider.autoDispose<List<HydroponicSystem>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return [];

  final response = await client
      .from('system_members')
      .select('system_id, role, hydroponic_systems(id, name, description)')
      .eq('user_id', user.id);

  final rows = response as List<dynamic>;
  return rows
      .map((row) => HydroponicSystem.fromMembershipRow(
          row as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
//  Active System
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the currently selected system.
///
/// - Auto-selects the first system on login.
/// - If the user has multiple systems, a picker can update this.
/// - Steps 5–9 all read from this to scope their API calls.
class ActiveSystemNotifier extends Notifier<HydroponicSystem?> {
  @override
  HydroponicSystem? build() => null;

  void select(HydroponicSystem system) {
    state = system;
  }

  void clear() {
    state = null;
  }
}

final activeSystemProvider =
    NotifierProvider<ActiveSystemNotifier, HydroponicSystem?>(
        ActiveSystemNotifier.new);

/// Convenience provider that returns just the active system's UUID string,
/// or `null` if none is selected.
final activeSystemIdProvider = Provider<String?>((ref) {
  return ref.watch(activeSystemProvider)?.id;
});

// ─────────────────────────────────────────────────────────────────────────────
//  Devices for Active System
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches devices that belong to the currently active system.
///
/// Re-fetches automatically when the active system changes.
final systemDevicesProvider =
    FutureProvider.autoDispose<List<Device>>((ref) async {
  final systemId = ref.watch(activeSystemIdProvider);
  if (systemId == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('devices')
      .select('*')
      .eq('system_id', systemId);

  final rows = response as List<dynamic>;
  return rows
      .map((row) => Device.fromMap(row as Map<String, dynamic>))
      .toList();
});

/// Convenience: the first (primary) device, or `null`.
///
/// Most HAT setups have a single ESP32 per system. This simplifies
/// dashboard and status code that just needs "the device".
final primaryDeviceProvider = Provider.autoDispose<Device?>((ref) {
  final devices = ref.watch(systemDevicesProvider).valueOrNull;
  if (devices == null || devices.isEmpty) return null;
  // Prefer active devices
  return devices.firstWhere(
    (d) => d.isActive,
    orElse: () => devices.first,
  );
});

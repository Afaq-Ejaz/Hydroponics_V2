import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../system/providers/system_provider.dart';
import '../models/device_status.dart';

/// Provides the online/offline status of the primary device,
/// auto-polling every [AppConfig.deviceStatusPollInterval].
///
/// Returns `null` when no primary device is available.
final deviceStatusProvider =
    AutoDisposeAsyncNotifierProvider<DeviceStatusNotifier, DeviceStatus?>(
        DeviceStatusNotifier.new);

class DeviceStatusNotifier extends AutoDisposeAsyncNotifier<DeviceStatus?> {
  Timer? _pollTimer;

  @override
  Future<DeviceStatus?> build() async {
    final device = ref.watch(primaryDeviceProvider);
    if (device == null) return null;

    // Cancel any prior timer when the provider rebuilds
    _pollTimer?.cancel();

    // Set up periodic polling
    _pollTimer = Timer.periodic(
      AppConfig.deviceStatusPollInterval,
      (_) => _refresh(device.id),
    );

    // Clean up on dispose
    ref.onDispose(() => _pollTimer?.cancel());

    // Fetch initial status
    return _fetchStatus(device.id);
  }

  Future<void> _refresh(String deviceId) async {
    state = AsyncData(await _fetchStatus(deviceId));
  }

  Future<DeviceStatus?> _fetchStatus(String deviceId) async {
    try {
      final url = Uri.parse(
          '${AppConfig.backendBaseUrl}/devices/$deviceId/status');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DeviceStatus.fromJson(json);
      }
      // Non-200 → return offline placeholder
      return null;
    } catch (_) {
      // Network error → return null (UI will show "unknown" state)
      return null;
    }
  }
}

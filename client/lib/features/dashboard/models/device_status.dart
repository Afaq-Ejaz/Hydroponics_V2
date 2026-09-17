/// Online/offline status of an IoT device, as returned by
/// `GET /devices/{device_id}/status` on the FastAPI backend.
class DeviceStatus {
  const DeviceStatus({
    required this.deviceId,
    required this.systemId,
    required this.name,
    required this.isActive,
    required this.status,
    this.lastSeen,
    this.minutesSinceLastSeen,
  });

  final String deviceId;
  final String systemId;
  final String name;
  final bool isActive;

  /// `"online"` or `"offline"`.
  final String status;
  final DateTime? lastSeen;
  final double? minutesSinceLastSeen;

  bool get isOnline => status == 'online';

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceId: json['device_id'] as String,
      systemId: json['system_id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool,
      status: json['status'] as String,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      minutesSinceLastSeen: json['minutes_since_last_seen'] != null
          ? (json['minutes_since_last_seen'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() => 'DeviceStatus($deviceId: $status)';
}

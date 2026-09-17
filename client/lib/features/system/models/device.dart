/// Data model for an IoT device (e.g. ESP32) registered under a system.
///
/// Mapped from the `devices` table in Supabase.
class Device {
  const Device({
    required this.id,
    required this.systemId,
    required this.name,
    required this.isActive,
    this.lastSeen,
    this.relayState = false,
  });

  /// Device identifier, e.g. `"ESP32_01"`.
  final String id;

  /// The hydroponic system this device belongs to.
  final String systemId;

  /// Human-readable device name.
  final String name;

  /// Whether the device is administratively enabled.
  final bool isActive;

  /// Last time the device sent telemetry (UTC).
  final DateTime? lastSeen;

  /// Desired or active relay state (pump, actuator).
  final bool relayState;

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      systemId: map['system_id'] as String,
      name: map['name'] as String,
      isActive: map['is_active'] as bool,
      lastSeen: map['last_seen'] != null
          ? DateTime.parse(map['last_seen'] as String)
          : null,
      relayState: map['relay_state'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'Device(id: $id, name: $name, active: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

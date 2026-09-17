/// A single snapshot of all sensor values from the `sensor_readings` table.
///
/// Every field is nullable because:
/// - Active sensors can occasionally return NaN (→ null in DB).
/// - Excluded sensors (pH, water temp, light, flow) are always null.
class SensorReading {
  const SensorReading({
    required this.systemId,
    required this.deviceId,
    required this.recordedAt,
    this.ph,
    this.ec,
    this.waterTemperature,
    this.waterLevel,
    this.airTemperature,
    this.humidity,
    this.lightIntensity,
    this.moisture,
    this.flowRate,
  });

  final String systemId;
  final String deviceId;
  final DateTime recordedAt;

  // ── Active sensors (ESP32 sends these) ──
  final double? ec;
  final double? moisture;
  final double? airTemperature;
  final double? humidity;
  final double? waterLevel;

  // ── Excluded sensors (always null for now) ──
  final double? ph;
  final double? waterTemperature;
  final double? lightIntensity;
  final double? flowRate;

  /// Parse a row from the Supabase `sensor_readings` table.
  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      systemId: map['system_id'] as String,
      deviceId: map['device_id'] as String,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      ph: _toDouble(map['ph']),
      ec: _toDouble(map['ec']),
      waterTemperature: _toDouble(map['water_temperature']),
      waterLevel: _toDouble(map['water_level']),
      airTemperature: _toDouble(map['air_temperature']),
      humidity: _toDouble(map['humidity']),
      lightIntensity: _toDouble(map['light_intensity']),
      moisture: _toDouble(map['moisture']),
      flowRate: _toDouble(map['flow_rate']),
    );
  }

  /// Look up a sensor value by its database column name.
  double? valueForField(String fieldName) {
    switch (fieldName) {
      case 'ec':
        return ec;
      case 'moisture':
        return moisture;
      case 'air_temperature':
        return airTemperature;
      case 'humidity':
        return humidity;
      case 'water_level':
        return waterLevel;
      case 'ph':
        return ph;
      case 'water_temperature':
        return waterTemperature;
      case 'light_intensity':
        return lightIntensity;
      case 'flow_rate':
        return flowRate;
      default:
        return null;
    }
  }

  /// Safely convert a Supabase numeric value (which can arrive as int,
  /// double, or String) to a Dart double.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

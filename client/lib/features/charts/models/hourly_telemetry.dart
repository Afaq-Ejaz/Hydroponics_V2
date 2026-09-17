/// A single hourly rollup bucket of sensor telemetry from the backend.
///
/// Corresponds to the schema returned by:
/// `GET /systems/{system_id}/telemetry/hourly?limit=...`
class HourlyTelemetry {
  const HourlyTelemetry({
    required this.bucket,
    required this.systemId,
    required this.deviceId,
    this.avgPh,
    this.avgEc,
    this.avgWaterTemp,
    this.avgWaterLevel,
    this.avgAirTemp,
    this.avgHumidity,
    this.avgLightIntensity,
    this.avgMoisture,
    this.avgFlowRate,
    this.sampleCount = 0,
  });

  final DateTime bucket;
  final String systemId;
  final String deviceId;
  final double? avgPh;
  final double? avgEc;
  final double? avgWaterTemp;
  final double? avgWaterLevel;
  final double? avgAirTemp;
  final double? avgHumidity;
  final double? avgLightIntensity;
  final double? avgMoisture;
  final double? avgFlowRate;
  final int sampleCount;

  factory HourlyTelemetry.fromJson(Map<String, dynamic> json) {
    return HourlyTelemetry(
      bucket: DateTime.parse(json['bucket'] as String),
      systemId: (json['system_id'] ?? '').toString(),
      deviceId: (json['device_id'] ?? '').toString(),
      avgPh: _toDouble(json['avg_ph']),
      avgEc: _toDouble(json['avg_ec']),
      avgWaterTemp: _toDouble(json['avg_water_temp']),
      avgWaterLevel: _toDouble(json['avg_water_level']),
      avgAirTemp: _toDouble(json['avg_air_temp']),
      avgHumidity: _toDouble(json['avg_humidity']),
      avgLightIntensity: _toDouble(json['avg_light_intensity']),
      avgMoisture: _toDouble(json['avg_moisture']),
      avgFlowRate: _toDouble(json['avg_flow_rate']),
      sampleCount: (json['sample_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Get the average value for a given sensor field name.
  double? valueForField(String fieldName) {
    switch (fieldName) {
      case 'ph':
        return avgPh;
      case 'ec':
        return avgEc;
      case 'water_temperature':
        return avgWaterTemp;
      case 'water_level':
        return avgWaterLevel;
      case 'air_temperature':
        return avgAirTemp;
      case 'humidity':
        return avgHumidity;
      case 'light_intensity':
        return avgLightIntensity;
      case 'moisture':
        return avgMoisture;
      case 'flow_rate':
        return avgFlowRate;
      default:
        return null;
    }
  }

  static double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }
}

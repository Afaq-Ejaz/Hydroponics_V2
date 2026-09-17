import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Static metadata for each sensor type displayed on the dashboard.
///
/// This is the **single source of truth** for:
/// - Which sensors exist in the system
/// - Which are currently connected (active probe on ESP32)
/// - How to display them (label, unit, icon, colour)
///
/// Steps 7 (Charts) and beyond can reuse this for labels and colours.
class SensorMeta {
  const SensorMeta({
    required this.fieldName,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.isActiveProbe,
    this.decimalPlaces = 1,
  });

  /// Database column name in `sensor_readings`, e.g. `'ec'`.
  final String fieldName;

  /// Human-readable label, e.g. `'EC (Conductivity)'`.
  final String label;

  /// Unit string, e.g. `'µS/cm'`.
  final String unit;

  /// Icon shown on the sensor card.
  final IconData icon;

  /// Accent colour for the card.
  final Color color;

  /// Whether the ESP32 currently sends this value.
  /// `false` → sensor not connected (pH, water temp, light, flow).
  final bool isActiveProbe;

  /// Number of decimal places when formatting the value.
  final int decimalPlaces;

  /// Format a sensor value for display.
  /// Returns `'--'` when the value is null.
  String formatValue(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(decimalPlaces);
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  SENSOR REGISTRY — ordered as they appear on the dashboard
  // ═══════════════════════════════════════════════════════════════════════

  /// The 5 sensors actively wired to the ESP32.
  static const List<SensorMeta> activeSensors = [
    SensorMeta(
      fieldName: 'ec',
      label: 'EC (Conductivity)',
      unit: 'µS/cm',
      icon: Icons.science_outlined,
      color: AppColors.sensorEc,
      isActiveProbe: true,
      decimalPlaces: 2,
    ),
    SensorMeta(
      fieldName: 'air_temperature',
      label: 'Air Temp',
      unit: '°C',
      icon: Icons.thermostat_outlined,
      color: AppColors.sensorAirTemp,
      isActiveProbe: true,
    ),
    SensorMeta(
      fieldName: 'humidity',
      label: 'Humidity',
      unit: '%',
      icon: Icons.water_drop_outlined,
      color: AppColors.sensorHumidity,
      isActiveProbe: true,
    ),
    SensorMeta(
      fieldName: 'water_level',
      label: 'Water Level',
      unit: '%',
      icon: Icons.waves_outlined,
      color: AppColors.sensorWaterLevel,
      isActiveProbe: true,
    ),
    SensorMeta(
      fieldName: 'moisture',
      label: 'Moisture',
      unit: '%',
      icon: Icons.grass_outlined,
      color: AppColors.sensorMoisture,
      isActiveProbe: true,
    ),
  ];

  /// Sensors that exist in the DB schema but are NOT wired to the ESP32.
  /// Shown with a `*` footnote on the dashboard.
  static const List<SensorMeta> inactiveSensors = [
    SensorMeta(
      fieldName: 'ph',
      label: 'pH Level',
      unit: 'pH',
      icon: Icons.opacity_outlined,
      color: AppColors.sensorPh,
      isActiveProbe: false,
    ),
    SensorMeta(
      fieldName: 'water_temperature',
      label: 'Water Temp',
      unit: '°C',
      icon: Icons.pool_outlined,
      color: AppColors.sensorWaterTemp,
      isActiveProbe: false,
    ),
    SensorMeta(
      fieldName: 'light_intensity',
      label: 'Light Intensity',
      unit: 'lux',
      icon: Icons.wb_sunny_outlined,
      color: AppColors.sensorLight,
      isActiveProbe: false,
      decimalPlaces: 0,
    ),
    SensorMeta(
      fieldName: 'flow_rate',
      label: 'Flow Rate',
      unit: 'L/min',
      icon: Icons.water_outlined,
      color: AppColors.sensorFlow,
      isActiveProbe: false,
      decimalPlaces: 2,
    ),
  ];

  /// All sensors combined (active first, then inactive).
  static const List<SensorMeta> all = [
    ...activeSensors,
    ...inactiveSensors,
  ];

  /// Fast lookup of metadata by database column name.
  static SensorMeta? find(String fieldName) {
    for (final meta in all) {
      if (meta.fieldName == fieldName) return meta;
    }
    return null;
  }
}

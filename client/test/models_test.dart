import 'package:flutter_test/flutter_test.dart';
import 'package:hat_client/features/alerts/models/system_alert.dart';
import 'package:hat_client/features/charts/models/hourly_telemetry.dart';
import 'package:hat_client/features/dashboard/models/sensor_meta.dart';
import 'package:hat_client/features/dashboard/models/sensor_reading.dart';
import 'package:hat_client/features/system/models/device.dart';

void main() {
  group('SensorMeta & Clean Architecture', () {
    test('Flow sensor is registered in metadata', () {
      final flowMeta = SensorMeta.find('flow_rate');
      expect(flowMeta, isNotNull);
      expect(flowMeta!.label, 'Flow Rate');
      expect(flowMeta.unit, 'L/min');
      expect(flowMeta.decimalPlaces, 2);
    });

    test('Active vs inactive sensor classification', () {
      expect(SensorMeta.activeSensors.length, 5);
      expect(SensorMeta.inactiveSensors.any((s) => s.fieldName == 'flow_rate'), isTrue);
      expect(SensorMeta.all.length, 9);
    });
  });

  group('SensorReading & Null Handling', () {
    test('Correctly parses live readings including flow_rate', () {
      final reading = SensorReading.fromMap({
        'system_id': 'sys-123',
        'device_id': 'ESP32_01',
        'recorded_at': '2026-09-17T05:00:00Z',
        'ec': 1.85,
        'air_temperature': 24.5,
        'humidity': 65.0,
        'water_level': 85.0,
        'moisture': 55.0,
        'flow_rate': 4.25,
      });

      expect(reading.ec, 1.85);
      expect(reading.flowRate, 4.25);
      expect(reading.ph, isNull);
      expect(reading.valueForField('flow_rate'), 4.25);
      expect(reading.valueForField('ph'), isNull);
    });
  });

  group('HourlyTelemetry', () {
    test('Correctly maps hourly rollups', () {
      final telemetry = HourlyTelemetry.fromJson({
        'bucket': '2026-09-17T05:00:00Z',
        'system_id': 'sys-123',
        'device_id': 'ESP32_01',
        'avg_ec': 1.72,
        'avg_flow_rate': 3.80,
        'sample_count': 60,
      });

      expect(telemetry.avgEc, 1.72);
      expect(telemetry.avgFlowRate, 3.80);
      expect(telemetry.sampleCount, 60);
      expect(telemetry.valueForField('flow_rate'), 3.80);
    });
  });

  group('SystemAlert', () {
    test('Parses alert severity and acknowledgment', () {
      final alert = SystemAlert.fromJson({
        'id': 'alert-1',
        'system_id': 'sys-123',
        'device_id': 'ESP32_01',
        'severity': 'critical',
        'message': 'Water temperature critical',
        'is_acknowledged': false,
        'created_at': '2026-09-17T05:10:00Z',
      });

      expect(alert.severity, AlertSeverity.critical);
      expect(alert.isAcknowledged, isFalse);

      final acknowledged = alert.copyWith(isAcknowledged: true);
      expect(acknowledged.isAcknowledged, isTrue);
    });
  });

  group('Device Model & Database Mapping', () {
    test('Correctly maps device with relay_state', () {
      final device = Device.fromMap({
        'id': 'ESP32_01',
        'system_id': 'sys-123',
        'name': 'Main ESP32 Controller',
        'is_active': true,
        'relay_state': true,
      });

      expect(device.id, 'ESP32_01');
      expect(device.relayState, isTrue);
    });

    test('Defaults relay_state to false when absent from older rows', () {
      final device = Device.fromMap({
        'id': 'ESP32_02',
        'system_id': 'sys-123',
        'name': 'Secondary Controller',
        'is_active': true,
      });

      expect(device.relayState, isFalse);
    });
  });
}

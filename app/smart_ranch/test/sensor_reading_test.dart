import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/models/sensor_reading.dart';

void main() {
  group('SensorReading.calculateThi', () {
    test('returns correct THI for known values', () {
      // THI = (1.8 × T + 32) − (0.55 − 0.0055 × RH) × (1.8 × T − 26)
      // T=35°C, RH=50%: THI = (1.8*35+32) - (0.55-0.0055*50) * (1.8*35-26)
      //                     = 95 - (0.275) * (37) = 95 - 10.175 = 84.825
      final thi = SensorReading.calculateThi(35.0, 50.0);
      expect(thi, closeTo(84.83, 0.01));
    });

    test('returns low THI for cool dry conditions', () {
      final thi = SensorReading.calculateThi(20.0, 30.0);
      expect(thi, lessThan(72.0)); // Should be normal
    });

    test('returns high THI for hot humid conditions', () {
      final thi = SensorReading.calculateThi(45.0, 70.0);
      expect(thi, greaterThan(89.0)); // Should be emergency
    });

    test('handles edge case: 0°C and 0% humidity', () {
      final thi = SensorReading.calculateThi(0.0, 0.0);
      expect(thi, isNotNaN);
      expect(thi, lessThan(72.0));
    });

    test('handles extreme heat (Sonora max: 48°C, 75%)', () {
      final thi = SensorReading.calculateThi(48.0, 75.0);
      expect(thi, greaterThan(89.0)); // Emergency level
    });
  });

  group('SensorReading.thiLevelFromValue', () {
    test('returns "normal" for THI < 72', () {
      expect(SensorReading.thiLevelFromValue(65.0), 'normal');
      expect(SensorReading.thiLevelFromValue(71.9), 'normal');
    });

    test('returns "alert" for 72 <= THI < 79', () {
      expect(SensorReading.thiLevelFromValue(72.0), 'alert');
      expect(SensorReading.thiLevelFromValue(75.0), 'alert');
      expect(SensorReading.thiLevelFromValue(78.9), 'alert');
    });

    test('returns "danger" for 79 <= THI < 89', () {
      expect(SensorReading.thiLevelFromValue(79.0), 'danger');
      expect(SensorReading.thiLevelFromValue(84.0), 'danger');
      expect(SensorReading.thiLevelFromValue(88.9), 'danger');
    });

    test('returns "emergency" for THI >= 89', () {
      expect(SensorReading.thiLevelFromValue(89.0), 'emergency');
      expect(SensorReading.thiLevelFromValue(95.0), 'emergency');
      expect(SensorReading.thiLevelFromValue(100.0), 'emergency');
    });

    test('returns "normal" for zero', () {
      expect(SensorReading.thiLevelFromValue(0.0), 'normal');
    });
  });

  group('SensorReading.fromMqttJson', () {
    test('parses valid MQTT JSON payload', () {
      const json = '''
      {
        "device_id": "vaca_001",
        "animal_name": "Lupita",
        "body_temp": 39.2,
        "ambient_temp": 35.0,
        "humidity": 50.0,
        "accel_x": 0.5,
        "accel_y": -0.3,
        "accel_z": 9.8,
        "movement_intensity": 1.2,
        "uptime_ms": 60000,
        "rssi": -55,
        "msg_count": 12
      }
      ''';

      final reading = SensorReading.fromMqttJson(json);

      expect(reading.deviceId, 'vaca_001');
      expect(reading.animalName, 'Lupita');
      expect(reading.bodyTemp, 39.2);
      expect(reading.ambientTemp, 35.0);
      expect(reading.humidity, 50.0);
      expect(reading.accelX, 0.5);
      expect(reading.accelY, -0.3);
      expect(reading.accelZ, 9.8);
      expect(reading.movementIntensity, 1.2);
      // THI is recalculated from ambient_temp & humidity
      expect(reading.thi, SensorReading.calculateThi(35.0, 50.0));
      expect(reading.thiLevel, SensorReading.thiLevelFromValue(reading.thi));
    });

    test('handles missing optional fields', () {
      const json = '''
      {
        "body_temp": 38.0,
        "ambient_temp": 30.0,
        "humidity": 40.0
      }
      ''';

      final reading = SensorReading.fromMqttJson(json);

      expect(reading.deviceId, 'unknown');
      expect(reading.animalName, '');
      expect(reading.accelX, 0.0);
      expect(reading.accelY, 0.0);
      expect(reading.accelZ, 0.0);
      expect(reading.movementIntensity, 0.0);
    });

    test('throws on invalid JSON', () {
      expect(() => SensorReading.fromMqttJson('not-json'), throwsFormatException);
    });
  });

  group('SensorReading.fromApiJson', () {
    test('parses REST API response', () {
      final data = {
        'device_id': 'vaca_003',
        'animal_name': 'Canela',
        'body_temp': 40.1,
        'ambient_temp': 42.0,
        'humidity': 60.0,
        'thi': 92.5,
        'thi_level': 'emergency',
        'accel_x': 2.1,
        'accel_y': 0.8,
        'accel_z': 10.2,
        'movement_intensity': 3.5,
        'timestamp': '2026-03-18T10:00:00',
      };

      final reading = SensorReading.fromApiJson(data);

      expect(reading.deviceId, 'vaca_003');
      expect(reading.thi, 92.5);
      expect(reading.thiLevel, 'emergency');
      expect(reading.timestamp, DateTime(2026, 3, 18, 10, 0, 0));
    });

    test('handles all-null optional fields gracefully', () {
      final data = <String, dynamic>{};

      final reading = SensorReading.fromApiJson(data);

      expect(reading.deviceId, 'unknown');
      expect(reading.bodyTemp, 0.0);
      expect(reading.thi, 0.0);
      expect(reading.thiLevel, 'unknown');
    });
  });

  group('SensorReading constructor', () {
    test('timestamp defaults to now', () {
      final before = DateTime.now();
      final reading = SensorReading(
        deviceId: 'test',
        bodyTemp: 38.0,
        ambientTemp: 30.0,
        humidity: 40.0,
        thi: 70.0,
        thiLevel: 'normal',
      );
      final after = DateTime.now();

      expect(reading.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(reading.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

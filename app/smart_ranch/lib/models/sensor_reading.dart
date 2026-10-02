import 'dart:convert';

/// Represents a single telemetry reading from an ESP32 device (one animal).
class SensorReading {
  final String deviceId;
  final String animalName;
  final double bodyTemp;
  final double ambientTemp;
  final double humidity;
  final double thi;
  final String thiLevel;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double movementIntensity;
  final double estrusScore;       // 0.0-1.0, high = possible estrus
  final String healthStatus;      // 'healthy', 'fever', 'lethargy', 'sick_suspected'
  final double batteryPercent;    // 0-100%
  final double batteryVoltage;    // 3.0 - 4.2V
  final DateTime timestamp;

  SensorReading({
    required this.deviceId,
    this.animalName = '',
    required this.bodyTemp,
    required this.ambientTemp,
    required this.humidity,
    required this.thi,
    required this.thiLevel,
    this.accelX = 0,
    this.accelY = 0,
    this.accelZ = 0,
    this.movementIntensity = 0,
    this.estrusScore = 0,
    this.healthStatus = 'healthy',
    this.batteryPercent = 88.0,
    this.batteryVoltage = 4.05,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Calculate THI from ambient temperature and humidity.
  static double calculateThi(double ambientTemp, double humidity) {
    final thi =
        (1.8 * ambientTemp + 32) -
        (0.55 - 0.0055 * humidity) * (1.8 * ambientTemp - 26);
    return double.parse(thi.toStringAsFixed(2));
  }

  /// Determine THI level from value.
  static String thiLevelFromValue(double thi) {
    if (thi >= 89) return 'emergency';
    if (thi >= 79) return 'danger';
    if (thi >= 72) return 'alert';
    return 'normal';
  }

  /// Parse from MQTT JSON payload.
  factory SensorReading.fromMqttJson(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final ambientTemp = (data['ambient_temp'] as num).toDouble();
    final humidity = (data['humidity'] as num).toDouble();
    final thi = calculateThi(ambientTemp, humidity);

    return SensorReading(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      bodyTemp: (data['body_temp'] as num).toDouble(),
      ambientTemp: ambientTemp,
      humidity: humidity,
      thi: thi,
      thiLevel: thiLevelFromValue(thi),
      accelX: (data['accel_x'] as num?)?.toDouble() ?? 0,
      accelY: (data['accel_y'] as num?)?.toDouble() ?? 0,
      accelZ: (data['accel_z'] as num?)?.toDouble() ?? 0,
      movementIntensity: (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      estrusScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      healthStatus: data['health_status'] as String? ?? 'healthy',
      batteryPercent: (data['battery_pct'] as num?)?.toDouble() ?? 88.0,
      batteryVoltage: (data['battery_v'] as num?)?.toDouble() ?? 4.05,
    );
  }

  /// Parse from REST API JSON.
  factory SensorReading.fromApiJson(Map<String, dynamic> data) {
    return SensorReading(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      bodyTemp: (data['body_temp'] as num?)?.toDouble() ?? 0,
      ambientTemp: (data['ambient_temp'] as num?)?.toDouble() ?? 0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0,
      thi: (data['thi'] as num?)?.toDouble() ?? 0,
      thiLevel: data['thi_level'] as String? ?? 'unknown',
      accelX: (data['accel_x'] as num?)?.toDouble() ?? 0,
      accelY: (data['accel_y'] as num?)?.toDouble() ?? 0,
      accelZ: (data['accel_z'] as num?)?.toDouble() ?? 0,
      movementIntensity: (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      estrusScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      healthStatus: data['health_status'] as String? ?? 'healthy',
      batteryPercent: (data['battery_pct'] as num?)?.toDouble() ?? 88.0,
      batteryVoltage: (data['battery_v'] as num?)?.toDouble() ?? 4.05,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Represents a health alert for an animal (fever, lethargy, or combined).
class HealthAlert {
  final String deviceId;
  final String animalName;
  final String type; // 'fever', 'lethargy', 'sick_suspected'
  final double bodyTemp;
  final double movementIntensity;
  final DateTime detectedAt;

  HealthAlert({
    required this.deviceId,
    this.animalName = '',
    required this.type,
    this.bodyTemp = 0,
    this.movementIntensity = 0,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  factory HealthAlert.fromJson(Map<String, dynamic> data) {
    return HealthAlert(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      type: data['type'] as String? ?? 'unknown',
      bodyTemp: (data['body_temp'] as num?)?.toDouble() ?? 0,
      movementIntensity:
          (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      detectedAt: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get label => switch (type) {
    'fever' => '🌡️ Fiebre',
    'lethargy' => '😴 Letargo',
    'sick_suspected' => '🏥 Posible Enfermedad',
    _ => 'Desconocido',
  };

  String get description => switch (type) {
    'fever' => 'Temperatura corporal elevada sostenida',
    'lethargy' => 'Actividad muy baja sostenida',
    'sick_suspected' => '¡Fiebre + letargo! Revisar al animal',
    _ => 'Estado desconocido',
  };
}

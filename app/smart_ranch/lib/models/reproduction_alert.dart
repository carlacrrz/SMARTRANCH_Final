/// Represents a detected estrus (celo) event for an animal.
class ReproductionAlert {
  final String deviceId;
  final String animalName;
  final double activityScore;   // 0.0-1.0, high = likely estrus
  final double movementIntensity;
  final DateTime detectedAt;

  ReproductionAlert({
    required this.deviceId,
    this.animalName = '',
    required this.activityScore,
    this.movementIntensity = 0,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  factory ReproductionAlert.fromJson(Map<String, dynamic> data) {
    return ReproductionAlert(
      deviceId: data['device_id'] as String? ?? 'unknown',
      animalName: data['animal_name'] as String? ?? '',
      activityScore: (data['estrus_score'] as num?)?.toDouble() ?? 0,
      movementIntensity:
          (data['movement_intensity'] as num?)?.toDouble() ?? 0,
      detectedAt: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

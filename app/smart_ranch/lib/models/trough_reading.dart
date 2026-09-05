/// Represents a water level reading from a trough sensor.
class TroughReading {
  final String troughId;
  final String troughName;
  final double levelPercent;
  final double distanceCm;
  final double tankDepthCm;
  final DateTime timestamp;

  TroughReading({
    required this.troughId,
    this.troughName = '',
    required this.levelPercent,
    this.distanceCm = 0,
    this.tankDepthCm = 100,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TroughReading.fromJson(Map<String, dynamic> data) {
    return TroughReading(
      troughId: data['trough_id'] as String? ?? 'unknown',
      troughName: data['trough_name'] as String? ?? '',
      levelPercent: (data['level_percent'] as num?)?.toDouble() ?? 0,
      distanceCm: (data['distance_cm'] as num?)?.toDouble() ?? 0,
      tankDepthCm: (data['tank_depth_cm'] as num?)?.toDouble() ?? 100,
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Human-readable status.
  String get statusLabel {
    if (levelPercent <= 10) return '⚠️ Crítico';
    if (levelPercent <= 20) return '🔶 Bajo';
    if (levelPercent <= 50) return '💧 Medio';
    return '✅ Lleno';
  }

  bool get isLow => levelPercent <= 20;
}

// Data models for PostgreSQL-backed ranch management.

class Animal {
  final int id;
  final String? deviceId;
  final String name;
  final String? earTag;
  final String? breed;
  final String sex;
  final DateTime? birthDate;
  final double? weightKg;
  final String category;
  final int? motherId;
  final int? fatherId;
  final String status;
  final String? photoUrl;
  final String? notes;
  final DateTime? createdAt;

  Animal({
    required this.id,
    this.deviceId,
    required this.name,
    this.earTag,
    this.breed,
    required this.sex,
    this.birthDate,
    this.weightKg,
    this.category = 'cow',
    this.motherId,
    this.fatherId,
    this.status = 'active',
    this.photoUrl,
    this.notes,
    this.createdAt,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as int,
      deviceId: json['device_id'] as String?,
      name: json['name'] as String,
      earTag: json['ear_tag'] as String?,
      breed: json['breed'] as String?,
      sex: json['sex'] as String,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'cow',
      motherId: json['mother_id'] as int?,
      fatherId: json['father_id'] as int?,
      status: json['status'] as String? ?? 'active',
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'name': name,
      'ear_tag': earTag,
      'breed': breed,
      'sex': sex,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'weight_kg': weightKg,
      'category': category,
      'mother_id': motherId,
      'father_id': fatherId,
      'status': status,
      'photo_url': photoUrl,
      'notes': notes,
    };
  }

  /// Age in a readable format
  String get ageDisplay {
    if (birthDate == null) return '—';
    final diff = DateTime.now().difference(birthDate!);
    if (diff.inDays > 365) {
      final years = diff.inDays ~/ 365;
      return '$years ${years == 1 ? 'año' : 'años'}';
    } else if (diff.inDays > 30) {
      final months = diff.inDays ~/ 30;
      return '$months ${months == 1 ? 'mes' : 'meses'}';
    }
    return '${diff.inDays} días';
  }

  /// Category display name in Spanish
  String get categoryDisplay {
    switch (category) {
      case 'calf':
        return 'Becerro/a';
      case 'heifer':
        return 'Novillona';
      case 'cow':
        return 'Vaca';
      case 'bull':
        return 'Toro';
      case 'steer':
        return 'Novillo';
      default:
        return category;
    }
  }

  /// Status display name in Spanish
  String get statusDisplay {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'sold':
        return 'Vendido';
      case 'dead':
        return 'Muerto';
      case 'transferred':
        return 'Transferido';
      case 'quarantine':
        return 'Cuarentena';
      default:
        return status;
    }
  }
}

class MedicalRecord {
  final int id;
  final int animalId;
  final String recordType;
  final String? productName;
  final String? dose;
  final String? administeredBy;
  final double? cost;
  final String? notes;
  final DateTime? nextDueDate;
  final int withdrawalDays;
  final DateTime? recordedAt;

  MedicalRecord({
    required this.id,
    required this.animalId,
    required this.recordType,
    this.productName,
    this.dose,
    this.administeredBy,
    this.cost,
    this.notes,
    this.nextDueDate,
    this.withdrawalDays = 0,
    this.recordedAt,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    return MedicalRecord(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      recordType: json['record_type'] as String,
      productName: json['product_name'] as String?,
      dose: json['dose'] as String?,
      administeredBy: json['administered_by'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      nextDueDate: json['next_due_date'] != null
          ? DateTime.tryParse(json['next_due_date'] as String)
          : null,
      withdrawalDays: json['withdrawal_days'] as int? ?? 0,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'animal_id': animalId,
      'record_type': recordType,
      'product_name': productName,
      'dose': dose,
      'administered_by': administeredBy,
      'cost': cost,
      'notes': notes,
      'next_due_date': nextDueDate?.toIso8601String().split('T').first,
      'withdrawal_days': withdrawalDays,
    };
  }

  String get recordTypeDisplay {
    switch (recordType) {
      case 'vaccine':
        return '💉 Vacuna';
      case 'treatment':
        return '💊 Tratamiento';
      case 'deworming':
        return '🪱 Desparasitación';
      case 'surgery':
        return '🔪 Cirugía';
      case 'exam':
        return '🩺 Examen';
      default:
        return '📋 Otro';
    }
  }
}

class ReproductiveEvent {
  final int id;
  final int animalId;
  final String eventType;
  final String? bullOrSemen;
  final bool? pregnancyConfirmed;
  final DateTime? expectedBirthDate;
  final int? calfId;
  final String? notes;
  final DateTime? recordedAt;

  ReproductiveEvent({
    required this.id,
    required this.animalId,
    required this.eventType,
    this.bullOrSemen,
    this.pregnancyConfirmed,
    this.expectedBirthDate,
    this.calfId,
    this.notes,
    this.recordedAt,
  });

  factory ReproductiveEvent.fromJson(Map<String, dynamic> json) {
    return ReproductiveEvent(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      eventType: json['event_type'] as String,
      bullOrSemen: json['bull_or_semen'] as String?,
      pregnancyConfirmed: json['pregnancy_confirmed'] as bool?,
      expectedBirthDate: json['expected_birth_date'] != null
          ? DateTime.tryParse(json['expected_birth_date'] as String)
          : null,
      calfId: json['calf_id'] as int?,
      notes: json['notes'] as String?,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }

  String get eventTypeDisplay {
    switch (eventType) {
      case 'heat_detected':
        return '💕 Celo detectado';
      case 'mating':
        return '🐂 Monta natural';
      case 'artificial_insemination':
        return '💉 Inseminación artificial';
      case 'pregnancy_check':
        return '🤰 Diagnóstico de gestación';
      case 'birth':
        return '🐣 Parto';
      case 'weaning':
        return '🍼 Destete';
      case 'abortion':
        return '⚠️ Aborto';
      default:
        return '📋 Otro';
    }
  }
}

class WeightRecord {
  final int id;
  final int animalId;
  final double weightKg;
  final int? bodyConditionScore;
  final String? notes;
  final DateTime? recordedAt;

  WeightRecord({
    required this.id,
    required this.animalId,
    required this.weightKg,
    this.bodyConditionScore,
    this.notes,
    this.recordedAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      weightKg: (json['weight_kg'] as num).toDouble(),
      bodyConditionScore: json['body_condition_score'] as int?,
      notes: json['notes'] as String?,
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'] as String)
          : null,
    );
  }
}

class AlertLog {
  final int id;
  final int? animalId;
  final String? deviceId;
  final String alertType;
  final String severity;
  final String? message;
  final Map<String, dynamic>? metadata;
  final bool acknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final DateTime? createdAt;

  AlertLog({
    required this.id,
    this.animalId,
    this.deviceId,
    required this.alertType,
    required this.severity,
    this.message,
    this.metadata,
    this.acknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.createdAt,
  });

  factory AlertLog.fromJson(Map<String, dynamic> json) {
    return AlertLog(
      id: json['id'] as int,
      animalId: json['animal_id'] as int?,
      deviceId: json['device_id'] as String?,
      alertType: json['alert_type'] as String,
      severity: json['severity'] as String,
      message: json['message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      acknowledged: json['acknowledged'] as bool? ?? false,
      acknowledgedBy: json['acknowledged_by'] as String?,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get severityEmoji {
    switch (severity) {
      case 'emergency':
        return '🔴';
      case 'danger':
        return '🟠';
      case 'warning':
        return '🟡';
      default:
        return '🔵';
    }
  }
}

class DashboardStats {
  final int totalActive;
  final Map<String, int> animalsByStatus;
  final Map<String, int> animalsByCategory;
  final int upcomingMedical7d;
  final int expectedBirths30d;
  final int unacknowledgedAlerts;

  DashboardStats({
    required this.totalActive,
    required this.animalsByStatus,
    required this.animalsByCategory,
    required this.upcomingMedical7d,
    required this.expectedBirths30d,
    required this.unacknowledgedAlerts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalActive: json['total_active'] as int? ?? 0,
      animalsByStatus: (json['animals_by_status'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      animalsByCategory:
          (json['animals_by_category'] as Map<String, dynamic>?)
                  ?.map((k, v) => MapEntry(k, v as int)) ??
              {},
      upcomingMedical7d: json['upcoming_medical_7d'] as int? ?? 0,
      expectedBirths30d: json['expected_births_30d'] as int? ?? 0,
      unacknowledgedAlerts: json['unacknowledged_alerts'] as int? ?? 0,
    );
  }
}

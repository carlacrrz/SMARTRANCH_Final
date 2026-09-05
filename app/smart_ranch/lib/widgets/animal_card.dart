import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/sensor_reading.dart';
import 'thi_gauge.dart';

/// Card widget displaying an animal's current status — desktop optimized.
class AnimalCard extends StatefulWidget {
  final SensorReading reading;
  final VoidCallback? onTap;
  final bool hasEstrusAlert;
  final String? healthAlertType;

  const AnimalCard({
    super.key,
    required this.reading,
    this.onTap,
    this.hasEstrusAlert = false,
    this.healthAlertType,
  });

  @override
  State<AnimalCard> createState() => _AnimalCardState();
}

class _AnimalCardState extends State<AnimalCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final color = AppTheme.thiColor(reading.thiLevel);
    final isDanger =
        reading.thiLevel == 'danger' || reading.thiLevel == 'emergency';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.cardBright : AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDanger ? color.withAlpha(150) : color.withAlpha(40),
              width: isDanger ? 1.5 : 1,
            ),
            boxShadow: [
              if (isDanger)
                BoxShadow(
                  color: color.withAlpha(30),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              if (_hovered)
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Icon + Name + Badges
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pets_rounded,
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reading.animalName.isNotEmpty
                                ? reading.animalName
                                : reading.deviceId,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            reading.deviceId,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Health badge
                    if (widget.healthAlertType != null &&
                        widget.healthAlertType != 'healthy')
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _IconBadge(
                          icon: widget.healthAlertType == 'sick_suspected'
                              ? Icons.local_hospital_rounded
                              : widget.healthAlertType == 'fever'
                                  ? Icons.device_thermostat_rounded
                                  : Icons.bedtime_rounded,
                          color: const Color(0xFFFF1744),
                          tooltip: widget.healthAlertType == 'sick_suspected'
                              ? 'Enfermo sospechado'
                              : widget.healthAlertType == 'fever'
                                  ? 'Fiebre'
                                  : 'Letargia',
                        ),
                      ),
                    // Estrus badge
                    if (widget.hasEstrusAlert)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _IconBadge(
                          icon: Icons.favorite_rounded,
                          color: const Color(0xFFE91E63),
                          tooltip: 'Celo detectado',
                        ),
                      ),
                    _StatusBadge(level: reading.thiLevel),
                  ],
                ),
                const SizedBox(height: 10),

                // THI Gauge (centered)
                Center(
                  child: ThiGauge(
                    value: reading.thi,
                    level: reading.thiLevel,
                    size: 85,
                  ),
                ),
                const SizedBox(height: 10),

                // Stats grid — 2x2 for desktop density
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      icon: Icons.thermostat_rounded,
                      label: '${reading.bodyTemp.toStringAsFixed(1)}°C',
                      sublabel: 'Corporal',
                      color: reading.bodyTemp > 40
                          ? AppTheme.thiDanger
                          : AppTheme.textSecondary,
                    ),
                    _StatChip(
                      icon: Icons.wb_sunny_rounded,
                      label: '${reading.ambientTemp.toStringAsFixed(1)}°C',
                      sublabel: 'Ambiente',
                      color: AppTheme.textSecondary,
                    ),
                    _StatChip(
                      icon: Icons.water_drop_rounded,
                      label: '${reading.humidity.toStringAsFixed(0)}%',
                      sublabel: 'Humedad',
                      color: AppTheme.textSecondary,
                    ),
                    _StatChip(
                      icon: Icons.directions_walk_rounded,
                      label: reading.movementIntensity.toStringAsFixed(0),
                      sublabel: 'Movimiento',
                      color: reading.movementIntensity > 80
                          ? AppTheme.thiAlert
                          : AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Material icon badge replacing emoji badges.
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  const _IconBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String level;
  const _StatusBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.thiColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.thiIcon(level), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            AppTheme.thiLabel(level),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

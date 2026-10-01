import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/trough_reading.dart';

/// Card widget displaying a trough's current water level — desktop.
class TroughCard extends StatefulWidget {
  final TroughReading reading;

  const TroughCard({super.key, required this.reading});

  @override
  State<TroughCard> createState() => _TroughCardState();
}

class _TroughCardState extends State<TroughCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final isLow = reading.isLow;
    final color = _levelColor(reading.levelPercent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: _hovered ? AppTheme.cardBright : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLow ? const Color(0xFFFF1744).withAlpha(120) : color.withAlpha(40),
          width: isLow ? 1.5 : 1,
        ),
        boxShadow: [
          if (isLow)
            BoxShadow(
              color: const Color(0xFFFF1744).withAlpha(25),
              blurRadius: 16,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header
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
                    Icons.water_drop_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reading.troughName.isNotEmpty
                            ? reading.troughName
                            : reading.troughId,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        reading.troughId,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF1744).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF1744).withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: const Color(0xFFFF1744)),
                        const SizedBox(width: 3),
                        Text(
                          'BAJO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF1744),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Water Level Gauge (vertical bar)
            Expanded(
              child: _WaterGauge(
                level: reading.levelPercent,
              ),
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _TroughStat(
                  icon: Icons.water_drop_rounded,
                  value: '${reading.levelPercent.toStringAsFixed(0)}%',
                  label: 'Nivel',
                  color: color,
                ),
                _TroughStat(
                  icon: Icons.straighten_rounded,
                  value: '${reading.distanceCm.toStringAsFixed(0)}cm',
                  label: 'Distancia',
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Color _levelColor(double level) {
    if (level <= 10) return const Color(0xFFFF1744);
    if (level <= 20) return const Color(0xFFFF6D00);
    if (level <= 50) return const Color(0xFFFFD600);
    return const Color(0xFF00E5FF);
  }
}

/// Vertical water level gauge.
class _WaterGauge extends StatelessWidget {
  final double level; // 0-100

  const _WaterGauge({required this.level});

  @override
  Widget build(BuildContext context) {
    final fraction = (level / 100).clamp(0.0, 1.0);
    final color = level <= 10
        ? const Color(0xFFFF1744)
        : level <= 20
            ? const Color(0xFFFF6D00)
            : level <= 50
                ? const Color(0xFFFFD600)
                : const Color(0xFF00E5FF);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
              ),
              // Water fill (from bottom)
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  height: constraints.maxHeight * fraction,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withAlpha(80),
                        color.withAlpha(200),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: const Radius.circular(8),
                      top: Radius.circular(fraction > 0.95 ? 8 : 2),
                    ),
                  ),
                ),
              ),
              // Percentage label
              Center(
                child: Text(
                  '${level.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black.withAlpha(120),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TroughStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _TroughStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

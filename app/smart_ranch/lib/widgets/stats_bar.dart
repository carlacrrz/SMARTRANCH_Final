import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A summary stats bar for the top of the dashboard.
class StatsBar extends StatelessWidget {
  final int totalAnimals;
  final int normalCount;
  final int alertCount;
  final int dangerCount;
  final int emergencyCount;
  final double avgThi;
  final bool isConnected;

  const StatsBar({
    super.key,
    required this.totalAnimals,
    this.normalCount = 0,
    this.alertCount = 0,
    this.dangerCount = 0,
    this.emergencyCount = 0,
    this.avgThi = 0,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Connection status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? AppTheme.thiNormal.withAlpha(20)
                    : AppTheme.thiEmergency.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 14,
                    color: isConnected
                        ? AppTheme.thiNormal
                        : AppTheme.thiEmergency,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected ? 'En Línea' : 'Sin Conexión',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isConnected
                          ? AppTheme.thiNormal
                          : AppTheme.thiEmergency,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Total animals
            _StatItem(
              icon: Icons.pets,
              value: '$totalAnimals',
              label: 'Cabezas',
            ),
            const SizedBox(width: 16),

            // By level
            _LevelDot(
              color: AppTheme.thiNormal,
              count: normalCount,
              label: 'Normal',
            ),
            SizedBox(width: 10),
            _LevelDot(
              color: AppTheme.thiAlert,
              count: alertCount,
              label: 'Alerta',
            ),
            SizedBox(width: 10),
            _LevelDot(
              color: AppTheme.thiDanger,
              count: dangerCount,
              label: 'Peligro',
            ),
            SizedBox(width: 10),
            _LevelDot(
              color: AppTheme.thiEmergency,
              count: emergencyCount,
              label: 'Emergencia',
            ),
            const SizedBox(width: 16),

            // Average THI
            _StatItem(
              icon: Icons.analytics_outlined,
              value: avgThi.toStringAsFixed(1),
              label: 'THI Prom.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
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
        ),
      ],
    );
  }
}

class _LevelDot extends StatelessWidget {
  final Color color;
  final int count;
  final String label;
  const _LevelDot({
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/demo_service.dart';
import '../widgets/trough_card.dart';

/// Dashboard screen for monitoring water trough levels.
class WaterDashboardScreen extends StatelessWidget {
  final DemoService demoService;

  const WaterDashboardScreen({super.key, required this.demoService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoService,
      builder: (context, _) {
        final troughs = demoService.troughReadings.values.toList();
        final lowCount = troughs.where((t) => t.isLow).length;

        return Column(
          children: [
            // Water Stats Bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WaterStat(
                    icon: Icons.water_drop_rounded,
                    label: 'Bebederos',
                    value: '${troughs.length}',
                    color: const Color(0xFF00E5FF),
                  ),
                  _WaterStat(
                    icon: Icons.warning_amber_rounded,
                    label: 'Nivel Bajo',
                    value: '$lowCount',
                    color: lowCount > 0
                        ? const Color(0xFFFF1744)
                        : AppTheme.textSecondary,
                  ),
                  _WaterStat(
                    icon: Icons.water,
                    label: 'Promedio',
                    value: troughs.isNotEmpty
                        ? '${(troughs.map((t) => t.levelPercent).reduce((a, b) => a + b) / troughs.length).toStringAsFixed(0)}%'
                        : '--',
                    color: const Color(0xFF00E5FF),
                  ),
                ],
              ),
            ),

            // Trough Grid
            Expanded(
              child: troughs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.water_drop_outlined,
                            size: 48,
                            color: AppTheme.textSecondary.withAlpha(60),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sin datos de bebederos',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Los datos aparecerán automáticamente',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withAlpha(120),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 4
                              : constraints.maxWidth > 600
                                  ? 3
                                  : 2;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: troughs.length,
                            itemBuilder: (context, index) {
                              return TroughCard(reading: troughs[index]);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _WaterStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WaterStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

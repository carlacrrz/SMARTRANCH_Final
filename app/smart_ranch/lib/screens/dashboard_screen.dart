import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/demo_service.dart';
import '../widgets/animal_card.dart';
import '../widgets/stats_bar.dart';
import 'animal_detail_screen.dart';

/// THI Monitor dashboard — desktop optimized with multi-column grid.
class DashboardScreen extends StatelessWidget {
  final DemoService demoService;

  const DashboardScreen({super.key, required this.demoService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: demoService,
      builder: (context, _) {
        final readings = demoService.latestReadings;
        final animals = readings.values.toList();

        // Sort: emergencies first
        animals.sort((a, b) {
          const order = {
            'emergency': 0,
            'danger': 1,
            'alert': 2,
            'normal': 3,
          };
          return (order[a.thiLevel] ?? 4).compareTo(order[b.thiLevel] ?? 4);
        });

        // Calculate stats
        final counts = {
          'normal': 0,
          'alert': 0,
          'danger': 0,
          'emergency': 0,
        };
        double totalThi = 0;
        for (final a in animals) {
          counts[a.thiLevel] = (counts[a.thiLevel] ?? 0) + 1;
          totalThi += a.thi;
        }
        final avgThi = animals.isNotEmpty ? totalThi / animals.length : 0.0;

        return Column(
          children: [
            // Stats Bar — compact desktop strip
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: StatsBar(
                isConnected: demoService.isRunning,
                totalAnimals: animals.length,
                normalCount: counts['normal']!,
                alertCount: counts['alert']!,
                dangerCount: counts['danger']!,
                emergencyCount: counts['emergency']!,
                avgThi: avgThi,
              ),
            ),

            // Animal Grid — wider cards, tighter spacing
            Expanded(
              child: animals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Esperando datos de telemetría...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Responsive columns: 2 for narrow, 3 for medium, 4+ for wide
                          final crossAxisCount = constraints.maxWidth > 1200
                              ? 4
                              : constraints.maxWidth > 800
                                  ? 3
                                  : constraints.maxWidth > 600
                                      ? 2
                                      : 1;
                          return GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 360,
                            ),
                            itemCount: animals.length,
                            itemBuilder: (context, index) {
                              final animal = animals[index];
                              return AnimalCard(
                                reading: animal,
                                hasEstrusAlert: demoService.activeEstrusAlerts
                                    .containsKey(animal.deviceId),
                                healthAlertType: demoService
                                    .activeHealthAlerts[animal.deviceId]
                                    ?.type,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AnimalDetailScreen(
                                        deviceId: animal.deviceId,
                                        demoService: demoService,
                                      ),
                                    ),
                                  );
                                },
                              );
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

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config/app_theme.dart';
import '../models/sensor_reading.dart';
import '../services/demo_service.dart';
import '../widgets/thi_gauge.dart';

/// Detail screen for a single animal, showing live data and THI history chart.
class AnimalDetailScreen extends StatefulWidget {
  final String deviceId;
  final DemoService demoService;

  const AnimalDetailScreen({
    super.key,
    required this.deviceId,
    required this.demoService,
  });

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.demoService.addListener(_onUpdate);
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.demoService.removeListener(_onUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.demoService.latestReadings[widget.deviceId];
    final history =
        widget.demoService.readingHistory[widget.deviceId] ?? <SensorReading>[];

    if (reading == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(widget.deviceId),
          backgroundColor: AppTheme.surface,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final color = AppTheme.thiColor(reading.thiLevel);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          reading.animalName.isNotEmpty ? reading.animalName : reading.deviceId,
        ),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppTheme.thiIcon(reading.thiLevel),
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  AppTheme.thiLabel(reading.thiLevel),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Gauges + Readings + Chart
            Expanded(
              flex: 3,
              child: Column(
                children: [
            // --- THI Gauge + Current Values ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withAlpha(40)),
              ),
              child: Column(
                children: [
                  ThiGauge(
                    value: reading.thi,
                    level: reading.thiLevel,
                    size: 140,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _thiDescription(reading.thiLevel),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Live Readings Grid ---
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _ReadingTile(
                  icon: Icons.thermostat_rounded,
                  label: 'Temp. Corporal',
                  value: '${reading.bodyTemp.toStringAsFixed(1)}°C',
                  color: reading.bodyTemp > 40
                      ? AppTheme.thiDanger
                      : AppTheme.primary,
                ),
                _ReadingTile(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Temp. Ambiente',
                  value: '${reading.ambientTemp.toStringAsFixed(1)}°C',
                  color: AppTheme.secondary,
                ),
                _ReadingTile(
                  icon: Icons.water_drop_rounded,
                  label: 'Humedad',
                  value: '${reading.humidity.toStringAsFixed(0)}%',
                  color: const Color(0xFF40C4FF),
                ),
                _ReadingTile(
                  icon: Icons.speed_rounded,
                  label: 'Movimiento',
                  value: reading.movementIntensity.toStringAsFixed(2),
                  color: reading.movementIntensity > 2
                      ? AppTheme.thiAlert
                      : AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- THI History Chart ---
            if (history.length > 2)
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial THI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildThiChart(history)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // --- Accelerometer Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acelerómetro',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _AccelAxis(label: 'X', value: reading.accelX, color: AppTheme.thiEmergency),
                      _AccelAxis(label: 'Y', value: reading.accelY, color: AppTheme.primary),
                      _AccelAxis(label: 'Z', value: reading.accelZ, color: const Color(0xFF40C4FF)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      reading.movementIntensity > 2.0
                          ? 'Alta actividad — posible jadeo'
                          : reading.movementIntensity > 0.5
                          ? 'Actividad normal'
                          : 'Inactivo — posible letargo',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Right Column: Health + Reproduction + Device
            Expanded(
              flex: 2,
              child: Column(
                children: [
            // --- Health Status Card ---
            _HealthStatusCard(reading: reading),
            const SizedBox(height: 16),

            // --- Reproduction Activity Card ---
            _ReproductionCard(
              reading: reading,
              hasEstrusAlert: widget.demoService.activeEstrusAlerts
                  .containsKey(widget.deviceId),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información del Dispositivo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'ID', value: reading.deviceId),
                  _InfoRow(
                    label: 'Nombre',
                    value: reading.animalName.isNotEmpty
                        ? reading.animalName
                        : 'No asignado',
                  ),
                  _InfoRow(
                    label: 'Última lectura',
                    value: _formatTime(reading.timestamp),
                  ),
                ],
              ),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThiChart(List<SensorReading> history) {
    final spots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].thi));
    }

    return LineChart(
      LineChartData(
        minY: 60,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 10,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.divider, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: AppTheme.divider, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 10,
              reservedSize: 35,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: 72,
              color: AppTheme.thiAlert.withAlpha(80),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            HorizontalLine(
              y: 79,
              color: AppTheme.thiDanger.withAlpha(80),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            HorizontalLine(
              y: 89,
              color: AppTheme.thiEmergency.withAlpha(80),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 2.5,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withAlpha(50),
                  AppTheme.primary.withAlpha(5),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _thiDescription(String level) => switch (level) {
    'normal' => 'Condiciones normales. Sin acción requerida.',
    'alert' => 'Estrés leve. Monitorear de cerca y asegurar acceso a agua.',
    'danger' => 'Estrés moderado. Proveer sombra y agua inmediatamente.',
    'emergency' =>
      'EMERGENCIA — Intervención inmediata requerida. Riesgo de muerte.',
    _ => 'Estado desconocido.',
  };

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}

class _ReadingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReadingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccelAxis extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AccelAxis({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          'm/s²',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing the real-time health status of the animal.
class _HealthStatusCard extends StatelessWidget {
  final SensorReading reading;
  const _HealthStatusCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final status = reading.healthStatus;
    final isHealthy = status == 'healthy';

    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;
    final String statusDesc;

    switch (status) {
      case 'fever':
        statusColor = const Color(0xFFFF6D00);
        statusIcon = Icons.thermostat_rounded;
        statusLabel = 'Fiebre Detectada';
        statusDesc = 'Temp. corporal elevada sostenida (>${reading.bodyTemp.toStringAsFixed(1)}°C)';
      case 'lethargy':
        statusColor = const Color(0xFFFFD600);
        statusIcon = Icons.hotel_rounded;
        statusLabel = 'Letargo Detectado';
        statusDesc = 'Actividad muy baja sostenida';
      case 'sick_suspected':
        statusColor = const Color(0xFFFF1744);
        statusIcon = Icons.local_hospital_rounded;
        statusLabel = 'Posible Enfermedad';
        statusDesc = 'Fiebre + letargo — revisar al animal inmediatamente';
      default:
        statusColor = AppTheme.thiNormal;
        statusIcon = Icons.favorite_rounded;
        statusLabel = 'Saludable';
        statusDesc = 'Sin anomalías detectadas';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHealthy ? AppTheme.divider : statusColor.withAlpha(100),
          width: isHealthy ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: 8),
              Text(
                'Estado de Salud',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(isHealthy ? 10 : 20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing estrus/reproduction detection status.
class _ReproductionCard extends StatelessWidget {
  final SensorReading reading;
  final bool hasEstrusAlert;

  const _ReproductionCard({
    required this.reading,
    required this.hasEstrusAlert,
  });

  @override
  Widget build(BuildContext context) {
    final score = reading.estrusScore;
    final Color barColor = hasEstrusAlert
        ? const Color(0xFFE91E63)
        : score > 0.5
            ? const Color(0xFFFF9800)
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasEstrusAlert
              ? const Color(0xFFE91E63).withAlpha(100)
              : AppTheme.divider,
          width: hasEstrusAlert ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasEstrusAlert ? 'Celo' : 'Normal',
                style: const TextStyle(fontSize: 14),
              ),
              Icon(
                hasEstrusAlert ? Icons.favorite_rounded : Icons.biotech_rounded,
                size: 18,
                color: hasEstrusAlert
                    ? const Color(0xFFE91E63)
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Actividad / Reproducción',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estrus Score Bar
          Row(
            children: [
              Text(
                'Indicador de celo:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status text
          if (hasEstrusAlert)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63).withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE91E63).withAlpha(40),
                ),
              ),
              child: Text(
                'Posible celo detectado — actividad elevada sostenida. '
                'Considerar inseminación.',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFE91E63),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              reading.movementIntensity > 2.0
                  ? 'Actividad alta — monitorear'
                  : reading.movementIntensity > 0.5
                  ? 'Actividad normal'
                  : 'Actividad baja',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';

/// Weight tracking screen — 2-column desktop layout: chart | table.
class PesoScreen extends StatefulWidget {
  const PesoScreen({super.key});

  @override
  State<PesoScreen> createState() => _PesoScreenState();
}

class _PesoScreenState extends State<PesoScreen> {
  List<WeightRecord> _records = [];
  bool _isLoading = true;

  static final _demoRecords = [
    WeightRecord(id: 1, animalId: 1, weightKg: 420, bodyConditionScore: 6,
        notes: 'Condición normal', recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 2, animalId: 1, weightKg: 415, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 30))),
    WeightRecord(id: 3, animalId: 1, weightKg: 408, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 60))),
    WeightRecord(id: 4, animalId: 1, weightKg: 395, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 90))),
    WeightRecord(id: 5, animalId: 2, weightKg: 380, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 6, animalId: 2, weightKg: 372, bodyConditionScore: 5,
        recordedAt: DateTime.now().subtract(const Duration(days: 30))),
    WeightRecord(id: 7, animalId: 3, weightKg: 350, bodyConditionScore: 7,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 8, animalId: 4, weightKg: 450, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
    WeightRecord(id: 9, animalId: 5, weightKg: 400, bodyConditionScore: 6,
        recordedAt: DateTime.now().subtract(const Duration(days: 0))),
  ];

  static const _animalNames = {
    1: 'Lupita', 2: 'Estrella', 3: 'Canela', 4: 'Luna', 5: 'Valentina',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await RanchApiService.getWeightRecords();
      setState(() { _records = records; _isLoading = false; });
    } catch (_) {
      setState(() { _records = _demoRecords; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final latestByAnimal = <int, WeightRecord>{};
    for (final r in _records) {
      if (!latestByAnimal.containsKey(r.animalId) ||
          (r.recordedAt ?? DateTime(2000)).isAfter(latestByAnimal[r.animalId]!.recordedAt ?? DateTime(2000))) {
        latestByAnimal[r.animalId] = r;
      }
    }

    final avgWeight = latestByAnimal.values.isEmpty
        ? 0.0
        : latestByAnimal.values.map((r) => r.weightKg).reduce((a, b) => a + b) / latestByAnimal.values.length;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Stats strip
          _buildStatsRow(latestByAnimal, avgWeight),
          const SizedBox(height: 8),

          // 2-column layout: chart | table
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — Weight chart
              Expanded(flex: 6, child: _buildWeightChart()),
              const SizedBox(width: 8),
              // Right — Latest weights
              Expanded(flex: 4, child: _buildLatestWeights(latestByAnimal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<int, WeightRecord> latestByAnimal, double avgWeight) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatColumn(icon: Icons.monitor_weight_rounded, label: 'Pesados', value: '${latestByAnimal.length}'),
          _StatColumn(icon: Icons.bar_chart_rounded, label: 'Promedio', value: '${avgWeight.toStringAsFixed(0)} kg'),
          _StatColumn(icon: Icons.analytics_rounded, label: 'Registros', value: '${_records.length}'),
        ],
      ),
    );
  }

  Widget _buildWeightChart() {
    final lupitaRecords = _records.where((r) => r.animalId == 1).toList()
      ..sort((a, b) => (a.recordedAt ?? DateTime.now()).compareTo(b.recordedAt ?? DateTime.now()));

    if (lupitaRecords.length < 2) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 32, color: AppTheme.textSecondary.withAlpha(80)),
              SizedBox(height: 8),
              Text('Datos insuficientes para gráfica',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final spots = lupitaRecords.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg);
    }).toList();

    final minW = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 10;
    final maxW = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 10;

    final firstW = lupitaRecords.first.weightKg;
    final lastW = lupitaRecords.last.weightKg;
    final daysDiff = (lupitaRecords.last.recordedAt ?? DateTime.now())
        .difference(lupitaRecords.first.recordedAt ?? DateTime.now()).inDays;
    final gdp = daysDiff > 0 ? (lastW - firstW) / daysDiff : 0.0;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Curva de Peso — ${_animalNames[1] ?? 'Animal'}',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: gdp >= 0 ? AppTheme.primary.withAlpha(15) : AppTheme.thiDanger.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(gdp >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 12, color: gdp >= 0 ? AppTheme.primary : AppTheme.thiDanger),
                    const SizedBox(width: 3),
                    Text(
                      'GDP: ${gdp >= 0 ? '+' : ''}${(gdp * 1000).toStringAsFixed(0)}g/día',
                      style: TextStyle(
                        color: gdp >= 0 ? AppTheme.primary : AppTheme.thiDanger,
                        fontSize: 10, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minW,
                maxY: maxW,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.divider, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= lupitaRecords.length) return const SizedBox.shrink();
                        final dt = lupitaRecords[idx].recordedAt;
                        if (dt == null) return SizedBox.shrink();
                        return Text('${dt.day}/${dt.month}',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(radius: 3, color: AppTheme.primary,
                              strokeWidth: 1.5, strokeColor: Colors.white),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withAlpha(15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestWeights(Map<int, WeightRecord> latestByAnimal) {
    final sorted = latestByAnimal.entries.toList()
      ..sort((a, b) => b.value.weightKg.compareTo(a.value.weightKg));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered_rounded, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text('Últimos Pesos', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...sorted.map((entry) {
            final record = entry.value;
            final name = _animalNames[entry.key] ?? 'Animal ${entry.key}';
            final bcs = record.bodyConditionScore;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(80))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(record.weightKg.toStringAsFixed(0),
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(
                            color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                        Row(
                          children: [
                            Text('${record.weightKg.toStringAsFixed(1)} kg',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            if (bcs != null) ...[
                              const SizedBox(width: 8),
                              _buildBcsIndicator(bcs),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (record.recordedAt != null)
                    Text('${record.recordedAt!.day}/${record.recordedAt!.month}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBcsIndicator(int bcs) {
    final color = bcs <= 3
        ? AppTheme.thiDanger
        : bcs <= 5
            ? AppTheme.thiAlert
            : bcs <= 7
                ? AppTheme.primary
                : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('CC $bcs/9',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _StatColumn({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

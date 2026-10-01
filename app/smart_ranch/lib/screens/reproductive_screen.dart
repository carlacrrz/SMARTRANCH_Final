import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../models/reproduction_alert.dart';
import '../models/sensor_reading.dart';
import '../services/demo_service.dart';
import '../services/ranch_api_service.dart';

/// Reproductive management dashboard — 3-panel desktop layout.
/// Left: IoT celo detection. Center: Gestation calendar. Right: Event timeline.
class ReproductiveScreen extends StatefulWidget {
  final DemoService demoService;
  const ReproductiveScreen({super.key, required this.demoService});

  @override
  State<ReproductiveScreen> createState() => _ReproductiveScreenState();
}

class _ReproductiveScreenState extends State<ReproductiveScreen> {
  List<ReproductiveEvent> _events = [];
  bool _isLoading = true;
  String _filterType = 'all';

  // Demo data
  static final _demoEvents = [
    ReproductiveEvent(
      id: 1, animalId: 1, eventType: 'heat_detected',
      notes: 'Actividad elevada detectada por sensor IoT',
      recordedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ReproductiveEvent(
      id: 2, animalId: 1, eventType: 'artificial_insemination',
      bullOrSemen: 'Angus Premium #4521',
      notes: 'Inseminación a tiempo fijo',
      expectedBirthDate: DateTime.now().add(const Duration(days: 253)),
      recordedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    ReproductiveEvent(
      id: 3, animalId: 4, eventType: 'pregnancy_check',
      pregnancyConfirmed: true, bullOrSemen: 'Toro Canelo',
      expectedBirthDate: DateTime.now().add(const Duration(days: 90)),
      recordedAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    ReproductiveEvent(
      id: 4, animalId: 2, eventType: 'birth',
      bullOrSemen: 'Brahman #231', calfId: 6,
      notes: 'Parto normal, becerro macho 32kg',
      recordedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ReproductiveEvent(
      id: 5, animalId: 5, eventType: 'mating',
      bullOrSemen: 'Toro Negro',
      notes: 'Monta natural observada',
      expectedBirthDate: DateTime.now().add(const Duration(days: 238)),
      recordedAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    ReproductiveEvent(
      id: 6, animalId: 3, eventType: 'weaning',
      notes: 'Destete a 8 meses, peso becerro: 180kg',
      recordedAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    ReproductiveEvent(
      id: 7, animalId: 2, eventType: 'pregnancy_check',
      pregnancyConfirmed: true, bullOrSemen: 'Angus Premium #4521',
      expectedBirthDate: DateTime.now().add(const Duration(days: 160)),
      recordedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.demoService.addListener(_onIoTUpdate);
  }

  void _onIoTUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.demoService.removeListener(_onIoTUpdate);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final events = await RanchApiService.getReproductiveEvents();
      setState(() { _events = events; _isLoading = false; });
    } catch (_) {
      setState(() { _events = _demoEvents; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    final pregnantCount = _events.where((e) =>
        e.eventType == 'pregnancy_check' && e.pregnancyConfirmed == true).length;
    final birthsCount = _events.where((e) => e.eventType == 'birth').length;
    final heatsCount = _events.where((e) => e.eventType == 'heat_detected').length;
    final inseminations = _events.where((e) =>
        e.eventType == 'artificial_insemination' || e.eventType == 'mating').length;

    // IoT data
    final estrusAlerts = widget.demoService.activeEstrusAlerts;
    final readings = widget.demoService.latestReadings;

    return Column(
      children: [
        // KPI Strip
        Container(
          margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _KpiChip(icon: Icons.favorite_rounded, label: 'Celos IoT',
                    value: '${estrusAlerts.length}', color: Colors.pinkAccent),
                _KpiChip(icon: Icons.science_rounded, label: 'Inseminaciones',
                    value: '$inseminations', color: AppTheme.secondary),
                _KpiChip(icon: Icons.pregnant_woman_rounded, label: 'Gestantes',
                    value: '$pregnantCount', color: Color(0xFFAB47BC)),
                _KpiChip(icon: Icons.child_care_rounded, label: 'Partos',
                    value: '$birthsCount', color: AppTheme.primary),
                _KpiChip(icon: Icons.sensors_rounded, label: 'Celos det.',
                    value: '$heatsCount', color: Colors.pinkAccent),
                _KpiChip(icon: Icons.event_note_rounded, label: 'Total',
                    value: '${_events.length}', color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 3-panel body
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT — IoT Celo en tiempo real
                      SizedBox(
                        height: 300,
                        child: _buildCeloPanel(estrusAlerts, readings),
                      ),
                      const SizedBox(height: 12),
                      // CENTER — Gestaciones activas
                      SizedBox(
                        height: 350,
                        child: _buildGestationPanel(),
                      ),
                      const SizedBox(height: 12),
                      // RIGHT — Timeline de eventos
                      SizedBox(
                        height: 400,
                        child: _buildTimelinePanel(),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT — IoT Celo en tiempo real
                  Expanded(
                    flex: 3,
                    child: _buildCeloPanel(estrusAlerts, readings),
                  ),
                  const SizedBox(width: 8),

                  // CENTER — Gestaciones activas
                  Expanded(
                    flex: 4,
                    child: _buildGestationPanel(),
                  ),
                  const SizedBox(width: 8),

                  // RIGHT — Timeline de eventos
                  Expanded(
                    flex: 3,
                    child: _buildTimelinePanel(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── LEFT PANEL: IoT Estrus Detection ─────────────────────────

  Widget _buildCeloPanel(
    Map<String, ReproductionAlert> alerts,
    Map<String, SensorReading> readings,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 0, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, size: 16, color: Colors.pinkAccent),
                SizedBox(width: 6),
                Text('Celo en Tiempo Real',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: alerts.isNotEmpty ? Colors.pinkAccent : AppTheme.textSecondary,
                  ),
                ),
                SizedBox(width: 4),
                Text(alerts.isNotEmpty ? '${alerts.length} activo' : 'Sin alertas',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
          ),

          // THI Warning
          Builder(builder: (context) {
            final dangerousReadings = readings.values
                .where((r) => r.thiLevel == 'danger' || r.thiLevel == 'emergency')
                .toList();
            if (dangerousReadings.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.thiDanger.withAlpha(15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.thiDanger.withAlpha(40)),
              ),
              child: Row(
                children: [
                  Icon(Icons.thermostat_rounded, size: 14, color: AppTheme.thiDanger),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'THI alto — estrés térmico reduce fertilidad',
                      style: TextStyle(fontSize: 10, color: AppTheme.thiDanger, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Alerts List
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monitor_heart_outlined, size: 32,
                            color: AppTheme.textSecondary.withAlpha(80)),
                        SizedBox(height: 8),
                        Text('Monitoreando actividad...',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        SizedBox(height: 4),
                        Text('Las alertas de celo aparecerán aquí',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withAlpha(120))),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: alerts.values.map((alert) {
                      final reading = readings[alert.deviceId];
                      return _CeloAlertCard(alert: alert, reading: reading);
                    }).toList(),
                  ),
          ),

          // All cows activity summary
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Actividad por vaca',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                ...readings.entries.map((e) {
                  final r = e.value;
                  final score = r.estrusScore;
                  final barColor = score > 0.7
                      ? Colors.pinkAccent
                      : score > 0.4
                          ? AppTheme.thiAlert
                          : AppTheme.textSecondary.withAlpha(60);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(r.animalName.isNotEmpty ? r.animalName : r.deviceId,
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: score.clamp(0.0, 1.0),
                              backgroundColor: AppTheme.divider,
                              valueColor: AlwaysStoppedAnimation<Color>(barColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${(score * 100).toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                color: barColor)),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── CENTER PANEL: Gestation Calendar ─────────────────────────

  Widget _buildGestationPanel() {
    final gestations = _events.where((e) =>
        e.expectedBirthDate != null &&
        e.expectedBirthDate!.isAfter(DateTime.now().subtract(const Duration(days: 30)))
    ).toList()
      ..sort((a, b) => a.expectedBirthDate!.compareTo(b.expectedBirthDate!));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: const Color(0xFFAB47BC)),
                SizedBox(width: 6),
                Text('Gestaciones Activas',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAB47BC).withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${gestations.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: const Color(0xFFAB47BC))),
                ),
              ],
            ),
          ),

          // Gantt-like gestation bars
          Expanded(
            child: gestations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pregnant_woman_rounded, size: 32,
                            color: AppTheme.textSecondary.withAlpha(80)),
                        SizedBox(height: 8),
                        Text('Sin gestaciones activas',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(10),
                    children: gestations.map((e) => _GestationBar(event: e)).toList(),
                  ),
          ),

          // Summer heat warning
          Builder(builder: (context) {
            final summerBirths = gestations.where((e) {
              final m = e.expectedBirthDate!.month;
              return m >= 6 && m <= 9; // June–September = extreme heat
            }).toList();
            if (summerBirths.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.thiDanger.withAlpha(12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.thiDanger.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, size: 14, color: AppTheme.thiDanger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${summerBirths.length} parto(s) en verano — riesgo estrés térmico en Sonora',
                      style: TextStyle(fontSize: 10, color: AppTheme.thiDanger, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── RIGHT PANEL: Improved Event Timeline ─────────────────────

  Widget _buildTimelinePanel() {
    final filtered = _filterType == 'all'
        ? _events
        : _events.where((e) => e.eventType == _filterType).toList();

    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Filter
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline_rounded, size: 16, color: AppTheme.textSecondary),
                SizedBox(width: 6),
                Text('Eventos',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                _FilterDropdown(
                  value: _filterType,
                  onChanged: (v) => setState(() => _filterType = v),
                ),
              ],
            ),
          ),

          // Event list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('Sin eventos de este tipo',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _EventCard(
                      event: filtered[index],
                      isLast: index == filtered.length - 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _KpiChip({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Celo Alert Card ────────────────────────────────────────────

class _CeloAlertCard extends StatelessWidget {
  final ReproductionAlert alert;
  final SensorReading? reading;

  const _CeloAlertCard({required this.alert, this.reading});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.pinkAccent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: Colors.pinkAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  alert.animalName.isNotEmpty ? alert.animalName : alert.deviceId,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(alert.activityScore * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.pinkAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: alert.activityScore.clamp(0.0, 1.0),
              backgroundColor: AppTheme.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
              minHeight: 4,
            ),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.directions_walk_rounded, size: 12, color: AppTheme.textSecondary),
              SizedBox(width: 4),
              Text('Mov: ${alert.movementIntensity.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Spacer(),
              if (reading != null) ...[
                Icon(Icons.thermostat_rounded, size: 12, color: AppTheme.textSecondary),
                SizedBox(width: 2),
                Text('THI: ${reading!.thi.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10,
                        color: AppTheme.thiColor(reading!.thiLevel))),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Programar inseminación',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: Colors.pinkAccent, decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }
}

// ─── Gestation Gantt Bar ────────────────────────────────────────

class _GestationBar extends StatelessWidget {
  final ReproductiveEvent event;
  const _GestationBar({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final birthDate = event.expectedBirthDate!;
    final daysLeft = birthDate.difference(now).inDays;

    // Estimate conception: 283 days before expected birth
    final conceptionDate = birthDate.subtract(const Duration(days: 283));
    final totalDays = 283.0;
    final elapsed = now.difference(conceptionDate).inDays.toDouble();
    final progress = (elapsed / totalDays).clamp(0.0, 1.0);

    final barColor = daysLeft < 0
        ? AppTheme.thiEmergency // overdue
        : daysLeft < 30
            ? AppTheme.thiDanger // imminent
            : daysLeft < 90
                ? AppTheme.thiAlert // approaching
                : AppTheme.primary; // normal

    final isSummer = birthDate.month >= 6 && birthDate.month <= 9;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: barColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pregnant_woman_rounded, size: 14, color: barColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.bullOrSemen ?? 'Monta #${event.id}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSummer)
                Tooltip(
                  message: 'Parto en verano — riesgo calor extremo',
                  child: Icon(Icons.wb_sunny_rounded, size: 14,
                      color: AppTheme.thiDanger),
                ),
              const SizedBox(width: 6),
              Text(
                daysLeft >= 0 ? '$daysLeft días' : '${-daysLeft}d atrasado',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Gantt bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmtDate(conceptionDate),
                  style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
              Text('Parto: ${_fmtDate(birthDate)}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: barColor)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Filter Dropdown ────────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  static const _types = {
    'all': 'Todos',
    'heat_detected': 'Celo',
    'artificial_insemination': 'IA',
    'mating': 'Monta',
    'pregnancy_check': 'Gestación',
    'birth': 'Parto',
    'weaning': 'Destete',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      initialValue: value,
      tooltip: 'Filtrar eventos',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 12, color: AppTheme.textSecondary),
            SizedBox(width: 4),
            Text(_types[value] ?? 'Todos',
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
      itemBuilder: (_) => _types.entries
          .map((e) => PopupMenuItem(
                value: e.key,
                height: 32,
                child: Text(e.value, style: const TextStyle(fontSize: 12)),
              ))
          .toList(),
    );
  }
}

// ─── Event Timeline Card ────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final ReproductiveEvent event;
  final bool isLast;

  const _EventCard({required this.event, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final eventColor = switch (event.eventType) {
      'heat_detected' => Colors.pinkAccent,
      'mating' || 'artificial_insemination' => AppTheme.secondary,
      'pregnancy_check' => Color(0xFFAB47BC),
      'birth' => AppTheme.primary,
      'weaning' => Color(0xFF42A5F5),
      'abortion' => AppTheme.thiDanger,
      _ => AppTheme.textSecondary,
    };

    final eventIcon = switch (event.eventType) {
      'heat_detected' => Icons.favorite_rounded,
      'mating' => Icons.pets_rounded,
      'artificial_insemination' => Icons.science_rounded,
      'pregnancy_check' => Icons.pregnant_woman_rounded,
      'birth' => Icons.child_care_rounded,
      'weaning' => Icons.no_stroller_rounded,
      'abortion' => Icons.warning_rounded,
      _ => Icons.event_rounded,
    };

    final eventLabel = switch (event.eventType) {
      'heat_detected' => 'Celo detectado',
      'mating' => 'Monta natural',
      'artificial_insemination' => 'Inseminación artificial',
      'pregnancy_check' => 'Diagnóstico de gestación',
      'birth' => 'Parto',
      'weaning' => 'Destete',
      'abortion' => 'Aborto',
      _ => 'Otro',
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: eventColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.card, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: AppTheme.divider)),
              ],
            ),
          ),
          // Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(eventIcon, size: 12, color: eventColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(eventLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: eventColor)),
                      ),
                      if (event.recordedAt != null)
                        Text('${event.recordedAt!.day}/${event.recordedAt!.month}',
                            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                    ],
                  ),
                  if (event.bullOrSemen != null) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.pets_rounded, size: 10, color: AppTheme.textSecondary),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(event.bullOrSemen!,
                              style: TextStyle(fontSize: 10, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                  if (event.pregnancyConfirmed != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          event.pregnancyConfirmed! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 10,
                          color: event.pregnancyConfirmed! ? AppTheme.primary : AppTheme.thiDanger,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          event.pregnancyConfirmed! ? 'Confirmada' : 'No gestante',
                          style: TextStyle(fontSize: 10,
                              color: event.pregnancyConfirmed! ? AppTheme.primary : AppTheme.thiDanger),
                        ),
                      ],
                    ),
                  ],
                  if (event.expectedBirthDate != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 10, color: Colors.pinkAccent),
                        const SizedBox(width: 3),
                        Text('Parto: ${event.expectedBirthDate!.day}/${event.expectedBirthDate!.month}/${event.expectedBirthDate!.year}',
                            style: TextStyle(fontSize: 9, color: Colors.pinkAccent)),
                      ],
                    ),
                  ],
                  if (event.notes != null) ...[
                    SizedBox(height: 4),
                    Text(event.notes!,
                        style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

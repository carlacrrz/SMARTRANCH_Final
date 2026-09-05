import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/health_alert.dart';
import '../models/ranch_models.dart';
import '../services/demo_service.dart';
import '../services/ranch_api_service.dart';

/// Sanidad (Medical/Health) screen — 2-column desktop layout.
/// Left: IoT health alerts in real-time. Right: Medical records with tabs.
class SanidadScreen extends StatefulWidget {
  final DemoService? demoService;
  const SanidadScreen({super.key, this.demoService});

  @override
  State<SanidadScreen> createState() => _SanidadScreenState();
}

class _SanidadScreenState extends State<SanidadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MedicalRecord> _records = [];
  List<Map<String, dynamic>> _upcoming = [];
  bool _isLoading = true;

  static final _demoRecords = [
    MedicalRecord(id: 1, animalId: 1, recordType: 'vaccine',
        productName: 'Pasturela bovina', dose: '5ml IM',
        administeredBy: 'Dr. Ramírez', cost: 180.0,
        nextDueDate: DateTime.now().add(const Duration(days: 180)),
        recordedAt: DateTime.now().subtract(const Duration(days: 15))),
    MedicalRecord(id: 2, animalId: 2, recordType: 'deworming',
        productName: 'Ivermectina 1%', dose: '10ml SC',
        administeredBy: 'Dr. Ramírez', cost: 95.0,
        nextDueDate: DateTime.now().add(const Duration(days: 90)),
        recordedAt: DateTime.now().subtract(const Duration(days: 10))),
    MedicalRecord(id: 3, animalId: 3, recordType: 'treatment',
        productName: 'Penicilina + Estreptomicina', dose: '15ml IM',
        administeredBy: 'Juan', cost: 220.0, withdrawalDays: 30,
        recordedAt: DateTime.now().subtract(const Duration(days: 5))),
    MedicalRecord(id: 4, animalId: 4, recordType: 'vaccine',
        productName: 'Brucelosis (RB51)', dose: '2ml SC',
        administeredBy: 'Dr. Ramírez', cost: 350.0,
        recordedAt: DateTime.now().subtract(const Duration(days: 45))),
    MedicalRecord(id: 5, animalId: 1, recordType: 'exam',
        productName: 'Análisis de sangre', dose: 'Muestra 10ml',
        administeredBy: 'Dr. Ramírez', cost: 500.0, notes: 'Resultados normales',
        recordedAt: DateTime.now().subtract(const Duration(days: 60))),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    widget.demoService?.addListener(_onIoT);
  }

  void _onIoT() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    widget.demoService?.removeListener(_onIoT);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final records = await RanchApiService.getMedicalRecords();
      final upcoming = await RanchApiService.getUpcomingMedical(days: 14);
      setState(() { _records = records; _upcoming = upcoming; _isLoading = false; });
    } catch (_) {
      setState(() {
        _records = _demoRecords;
        _upcoming = [
          {'animal_name': 'Lupita', 'product_name': 'Pasturela bovina', 'next_due_date': DateTime.now().add(const Duration(days: 3)).toIso8601String()},
          {'animal_name': 'Estrella', 'product_name': 'Ivermectina 1%', 'next_due_date': DateTime.now().add(const Duration(days: 10)).toIso8601String()},
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthAlerts = widget.demoService?.activeHealthAlerts ?? {};

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT — IoT Health Alerts
        SizedBox(
          width: 280,
          child: _buildHealthAlertsPanel(healthAlerts),
        ),
        const SizedBox(width: 8),

        // RIGHT — Medical Records
        Expanded(child: _buildRecordsPanel()),
      ],
    );
  }

  Widget _buildHealthAlertsPanel(Map<String, HealthAlert> alerts) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 0, 12),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.monitor_heart_rounded, size: 16, color: AppTheme.thiDanger),
                const SizedBox(width: 6),
                const Text('Alertas IoT Salud',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const Spacer(),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: alerts.isNotEmpty ? AppTheme.thiDanger : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Upcoming banner
          if (_upcoming.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withAlpha(12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.secondary.withAlpha(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: AppTheme.secondary),
                      const SizedBox(width: 4),
                      Text('${_upcoming.length} evento(s) próximos',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.secondary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ..._upcoming.take(3).map((u) => Text(
                    '${u['animal_name'] ?? ''} — ${u['product_name'] ?? ''}',
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ],
              ),
            ),

          // Health alerts list
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 32,
                            color: AppTheme.primary.withAlpha(80)),
                        const SizedBox(height: 8),
                        const Text('Sin alertas de salud',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Monitoreando temp + actividad...',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withAlpha(120))),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: alerts.values.map((HealthAlert alert) {
                      final t = alert.type;
                      final alertColor = t == 'sick_suspected'
                          ? AppTheme.thiEmergency
                          : t == 'fever'
                              ? AppTheme.thiDanger
                              : AppTheme.thiAlert;
                      final alertIcon = t == 'sick_suspected'
                          ? Icons.local_hospital_rounded
                          : t == 'fever'
                              ? Icons.thermostat_rounded
                              : Icons.trending_down_rounded;
                      final alertLabel = t == 'sick_suspected'
                          ? 'Posible enfermedad'
                          : t == 'fever'
                              ? 'Fiebre detectada'
                              : 'Letargo detectado';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: alertColor.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: alertColor.withAlpha(40)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(alertIcon, size: 14, color: alertColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(alert.animalName.isNotEmpty ? alert.animalName : alert.deviceId,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(alertLabel,
                                style: TextStyle(fontSize: 10, color: alertColor, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.thermostat_rounded, size: 10, color: AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Text('${alert.bodyTemp.toStringAsFixed(1)}°C',
                                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                                const SizedBox(width: 8),
                                const Icon(Icons.directions_walk_rounded, size: 10, color: AppTheme.textSecondary),
                                const SizedBox(width: 2),
                                Text('Mov: ${alert.movementIntensity.toStringAsFixed(1)}',
                                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppTheme.divider,
            tabs: const [
              Tab(icon: Icon(Icons.vaccines_rounded, size: 16), text: 'Vacunas'),
              Tab(icon: Icon(Icons.medical_services_rounded, size: 16), text: 'Tratamientos'),
              Tab(icon: Icon(Icons.bug_report_rounded, size: 16), text: 'Desparasit.'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecordsList('vaccine'),
                      _buildRecordsList('treatment'),
                      _buildRecordsList('deworming'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(String type) {
    final filtered = _records.where((r) => r.recordType == type).toList();
    if (filtered.isEmpty) {
      final icon = type == 'vaccine' ? Icons.vaccines_rounded
          : type == 'treatment' ? Icons.medical_services_rounded
          : Icons.bug_report_rounded;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            const Text('Sin registros', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final record = filtered[index];
        final typeIcon = record.recordType == 'vaccine' ? Icons.vaccines_rounded
            : record.recordType == 'treatment' ? Icons.medical_services_rounded
            : record.recordType == 'exam' ? Icons.biotech_rounded
            : Icons.bug_report_rounded;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
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
                  Icon(typeIcon, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(record.productName ?? record.recordType,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (record.cost != null)
                    Text('\$${record.cost!.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (record.dose != null) ...[
                    Icon(Icons.medication_liquid_rounded, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(record.dose!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const SizedBox(width: 12),
                  ],
                  if (record.administeredBy != null) ...[
                    Icon(Icons.person_outline_rounded, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(record.administeredBy!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
              if (record.withdrawalDays > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.thiAlert.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 10, color: AppTheme.thiAlert),
                      const SizedBox(width: 3),
                      Text('Retiro: ${record.withdrawalDays} días',
                          style: const TextStyle(color: AppTheme.thiAlert, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              if (record.nextDueDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 12, color: AppTheme.secondary),
                    const SizedBox(width: 3),
                    Text('Próximo: ${record.nextDueDate!.day}/${record.nextDueDate!.month}/${record.nextDueDate!.year}',
                        style: const TextStyle(color: AppTheme.secondary, fontSize: 10)),
                  ],
                ),
              ],
              if (record.recordedAt != null) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('${record.recordedAt!.day}/${record.recordedAt!.month}/${record.recordedAt!.year}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

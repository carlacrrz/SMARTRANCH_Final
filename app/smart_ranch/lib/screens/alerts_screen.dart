import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';

/// Centralized alerts screen — desktop 2-column layout.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertLog> _alerts = [];
  bool _isLoading = true;
  bool _showOnlyUnacknowledged = true;

  static final _demoAlerts = [
    AlertLog(id: 1, deviceId: 'vaca_001', alertType: 'thi_danger', severity: 'danger',
        message: 'PELIGRO: THI=82.5 — Proveer sombra y agua', createdAt: DateTime.now().subtract(const Duration(minutes: 12))),
    AlertLog(id: 2, deviceId: 'vaca_005', alertType: 'geofence_exit', severity: 'warning',
        message: 'Valentina salió de zona: Potrero Sur', createdAt: DateTime.now().subtract(const Duration(minutes: 25))),
    AlertLog(id: 3, deviceId: 'vaca_003', alertType: 'estrus_detected', severity: 'info',
        message: 'Posible celo detectado en Canela (score=0.92)', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    AlertLog(id: 4, deviceId: 'vaca_004', alertType: 'health_fever', severity: 'warning',
        message: 'Fiebre detectada en Luna — temp corporal 40.3°C', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    AlertLog(id: 5, deviceId: 'vaca_002', alertType: 'vaccine_due', severity: 'info',
        message: 'Estrella necesita refuerzo de vacuna pasturela en 3 días',
        createdAt: DateTime.now().subtract(const Duration(hours: 5))),
    AlertLog(id: 6, deviceId: 'vaca_001', alertType: 'thi_emergency', severity: 'emergency',
        message: 'EMERGENCIA: THI=91.2 — Intervención inmediata requerida',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)), acknowledged: true, acknowledgedBy: 'admin'),
  ];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      final alerts = await RanchApiService.getAlerts(unacknowledged: _showOnlyUnacknowledged);
      setState(() { _alerts = alerts; _isLoading = false; });
    } catch (_) {
      setState(() {
        _alerts = _showOnlyUnacknowledged
            ? _demoAlerts.where((a) => !a.acknowledged).toList()
            : _demoAlerts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unackCount = _alerts.where((a) => !a.acknowledged).length;

    // Group by severity
    final emergencyAlerts = _alerts.where((a) => a.severity == 'emergency' || a.severity == 'danger').toList();
    final otherAlerts = _alerts.where((a) => a.severity != 'emergency' && a.severity != 'danger').toList();

    return Column(
      children: [
        // Header strip
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Icon(
                unackCount > 0 ? Icons.notifications_active_rounded : Icons.check_circle_rounded,
                size: 22,
                color: unackCount > 0 ? AppTheme.thiDanger : AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unackCount > 0
                          ? '$unackCount alerta${unackCount == 1 ? '' : 's'} sin atender'
                          : 'Sin alertas pendientes',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text('Total: ${_alerts.length} alertas',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              FilterChip(
                avatar: Icon(Icons.filter_list_rounded, size: 14,
                    color: _showOnlyUnacknowledged ? AppTheme.primary : AppTheme.textSecondary),
                label: Text(_showOnlyUnacknowledged ? 'Pendientes' : 'Todas',
                    style: const TextStyle(fontSize: 11)),
                selected: _showOnlyUnacknowledged,
                selectedColor: AppTheme.primary.withAlpha(30),
                backgroundColor: AppTheme.surface,
                onSelected: (_) {
                  setState(() => _showOnlyUnacknowledged = !_showOnlyUnacknowledged);
                  _loadAlerts();
                },
              ),
            ],
          ),
        ),

        // 2-column layout
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 48,
                              color: AppTheme.primary.withAlpha(80)),
                          const SizedBox(height: 12),
                          const Text('Todo en orden', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left — Critical alerts
                        Expanded(
                          flex: 5,
                          child: _buildAlertList('Alertas Críticas', emergencyAlerts,
                              Icons.error_rounded, AppTheme.thiDanger),
                        ),
                        // Right — Info/warnings
                        Expanded(
                          flex: 5,
                          child: _buildAlertList('Avisos e Información', otherAlerts,
                              Icons.info_rounded, AppTheme.textSecondary),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildAlertList(String title, List<AlertLog> alerts, IconData icon, Color titleColor) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: titleColor),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: titleColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${alerts.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: titleColor)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Expanded(
            child: alerts.isEmpty
                ? Center(child: Text('Sin alertas', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertLog alert) {
    final severityColors = {
      'emergency': AppTheme.thiEmergency,
      'danger': AppTheme.thiDanger,
      'warning': AppTheme.thiAlert,
      'info': AppTheme.primary,
    };
    final color = severityColors[alert.severity] ?? AppTheme.textSecondary;
    final severityIcon = switch (alert.severity) {
      'emergency' => Icons.crisis_alert_rounded,
      'danger' => Icons.warning_rounded,
      'warning' => Icons.warning_amber_rounded,
      'info' => Icons.info_outline_rounded,
      _ => Icons.circle,
    };
    final typeIcon = switch (alert.alertType) {
      'thi_danger' || 'thi_emergency' => Icons.thermostat_rounded,
      'health_fever' => Icons.local_hospital_rounded,
      'health_lethargy' => Icons.trending_down_rounded,
      'estrus_detected' => Icons.favorite_rounded,
      'geofence_exit' || 'geofence_enter' => Icons.location_off_rounded,
      'vaccine_due' => Icons.vaccines_rounded,
      'weight_loss' => Icons.trending_down_rounded,
      'low_battery' => Icons.battery_alert_rounded,
      _ => Icons.notifications_rounded,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: alert.acknowledged ? AppTheme.surface : color.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alert.acknowledged ? AppTheme.divider : color.withAlpha(30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3, height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(severityIcon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withAlpha(15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_alertTypeLabel(alert.alertType),
                          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(_formatTimeAgo(alert.createdAt),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(alert.message ?? alert.alertType,
                    style: TextStyle(
                      color: alert.acknowledged ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 11,
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (alert.acknowledged) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 10, color: AppTheme.primary),
                      const SizedBox(width: 3),
                      Text('Atendida por ${alert.acknowledgedBy ?? 'sistema'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    ],
                  ),
                ],
                if (!alert.acknowledged && alert.deviceId != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(typeIcon, size: 10, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(alert.deviceId!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _alertTypeLabel(String type) => switch (type) {
    'thi_danger' => 'THI Peligro',
    'thi_emergency' => 'THI Emergencia',
    'health_fever' => 'Fiebre',
    'health_lethargy' => 'Letargo',
    'health_sick' => 'Enfermedad',
    'estrus_detected' => 'Celo',
    'geofence_exit' => 'Fuera de zona',
    'geofence_enter' => 'Entró a zona',
    'vaccine_due' => 'Vacuna pendiente',
    'birth_expected' => 'Parto esperado',
    'weight_loss' => 'Pérdida de peso',
    'low_battery' => 'Batería baja',
    _ => type,
  };

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return 'hace ${diff.inDays}d';
  }
}

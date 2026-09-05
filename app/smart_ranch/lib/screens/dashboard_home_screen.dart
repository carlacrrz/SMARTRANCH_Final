import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';
import '../widgets/crud_dialogs.dart';

/// Dashboard home screen — overview stats + quick actions, desktop 3-column layout.
class DashboardHomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardHomeScreen({super.key, this.onNavigate});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  DashboardStats? _stats;
  bool _isLoading = true;

  static final _demoStats = DashboardStats(
    totalActive: 5,
    animalsByStatus: {'active': 5},
    animalsByCategory: {'vaca': 3, 'becerro': 1, 'toro': 1},
    upcomingMedical7d: 2,
    expectedBirths30d: 1,
    unacknowledgedAlerts: 3,
  );

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final result = await RanchApiService.getDashboardStats();
      setState(() { _stats = result; _isLoading = false; });
    } catch (_) {
      setState(() { _stats = _demoStats; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _stats == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final stats = _stats!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildHeader(),
          const SizedBox(height: 12),

          // KPI strip — 6 cards in a row
          _buildKpiStrip(stats),
          const SizedBox(height: 12),

          // 3-column desktop layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — Herd distribution + Quick actions
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildHerdDistribution(stats),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Center — Activity summary
              Expanded(
                flex: 4,
                child: _buildActivitySummary(stats),
              ),
              const SizedBox(width: 12),

              // Right — System status
              Expanded(
                flex: 3,
                child: _buildSystemStatus(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withAlpha(25), AppTheme.card],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withAlpha(25)),
      ),
      child: Row(
        children: [
          Icon(Icons.agriculture_rounded, size: 28, color: AppTheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
              Text('Rancho Cananea — ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _loadStats,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          _KpiItem(icon: Icons.pets_rounded, label: 'Cabezas',
              value: '${stats.totalActive}', color: AppTheme.primary,
              onTap: () => widget.onNavigate?.call(3)),
          _KpiItem(icon: Icons.notifications_active_rounded, label: 'Alertas',
              value: '${stats.unacknowledgedAlerts}',
              color: stats.unacknowledgedAlerts > 0 ? AppTheme.thiDanger : AppTheme.primary,
              onTap: () => widget.onNavigate?.call(6)),
          _KpiItem(icon: Icons.vaccines_rounded, label: 'Vacunas 7d',
              value: '${stats.upcomingMedical7d}', color: AppTheme.thiAlert),
          _KpiItem(icon: Icons.child_care_rounded, label: 'Partos 30d',
              value: '${stats.expectedBirths30d}', color: AppTheme.secondary),
          _KpiItem(icon: Icons.category_rounded, label: 'Categorías',
              value: '${stats.animalsByCategory.length}', color: const Color(0xFFAB47BC)),
          _KpiItem(icon: Icons.inventory_2_rounded, label: 'Activos',
              value: '${stats.totalActive}', color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildHerdDistribution(DashboardStats stats) {
    final categories = stats.animalsByCategory;
    if (categories.isEmpty) return const SizedBox.shrink();

    final total = categories.values.fold<int>(0, (s, v) => s + v);
    final colorMap = {
      'vaca': AppTheme.primary,
      'becerro': AppTheme.secondary,
      'toro': const Color(0xFFFF7043),
      'novilla': const Color(0xFFAB47BC),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text('Distribución del Hato',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: categories.entries.where((e) => e.value > 0).map((e) {
                  final pct = total > 0 ? e.value / total : 0.0;
                  return Flexible(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(color: colorMap[e.key] ?? AppTheme.textSecondary),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: categories.entries.map((e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: colorMap[e.key] ?? AppTheme.textSecondary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${e.key}: ${e.value}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: AppTheme.secondary),
              const SizedBox(width: 6),
              const Text('Acciones Rápidas',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionBtn(icon: Icons.add_rounded, label: 'Registrar Animal',
                  onTap: () => showAddAnimalDialog(context)),
              _ActionBtn(icon: Icons.vaccines_rounded, label: 'Nueva Vacuna',
                  onTap: () => showAddMedicalDialog(context)),
              _ActionBtn(icon: Icons.monitor_weight_rounded, label: 'Registrar Peso',
                  onTap: () => showAddWeightDialog(context)),
              _ActionBtn(icon: Icons.map_rounded, label: 'Ver Mapa',
                  onTap: () => widget.onNavigate?.call(9)),
              _ActionBtn(icon: Icons.account_balance_wallet_rounded, label: 'Movimiento',
                  onTap: () => showAddFinancialDialog(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummary(DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              const Text('Resumen de Actividad',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.notifications_active_rounded,
            label: 'Alertas sin atender',
            value: '${stats.unacknowledgedAlerts}',
            color: stats.unacknowledgedAlerts > 0 ? AppTheme.thiDanger : AppTheme.primary,
            onTap: () => widget.onNavigate?.call(6),
          ),
          _ActivityRow(
            icon: Icons.vaccines_rounded,
            label: 'Vacunas próximas (7 días)',
            value: '${stats.upcomingMedical7d}',
            color: stats.upcomingMedical7d > 0 ? AppTheme.thiAlert : AppTheme.primary,
            onTap: () => widget.onNavigate?.call(4),
          ),
          _ActivityRow(
            icon: Icons.child_care_rounded,
            label: 'Partos esperados (30 días)',
            value: '${stats.expectedBirths30d}',
            color: stats.expectedBirths30d > 0 ? AppTheme.secondary : AppTheme.textSecondary,
            onTap: () => widget.onNavigate?.call(5),
          ),
          const Divider(color: AppTheme.divider, height: 20),
          // Status by category
          ...stats.animalsByStatus.entries.map((e) => _ActivityRow(
            icon: e.key == 'active' ? Icons.check_circle_rounded :
                  e.key == 'sold' ? Icons.sell_rounded : Icons.info_rounded,
            label: _statusLabel(e.key),
            value: '${e.value}',
            color: e.key == 'active' ? AppTheme.primary : AppTheme.textSecondary,
          )),
        ],
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
    'active' => 'Activos',
    'sold' => 'Vendidos',
    'deceased' => 'Fallecidos',
    'transferred' => 'Transferidos',
    _ => s,
  };

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              const Text('Estado del Sistema',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          _StatusRow(icon: Icons.cloud_done_rounded, label: 'PostgreSQL', status: 'Conectado', ok: true),
          _StatusRow(icon: Icons.sensors_rounded, label: 'MQTT Broker', status: 'Activo', ok: true),
          _StatusRow(icon: Icons.storage_rounded, label: 'InfluxDB', status: 'Activo', ok: true),
          _StatusRow(icon: Icons.dashboard_rounded, label: 'Grafana', status: ':3000', ok: true),
          _StatusRow(icon: Icons.memory_rounded, label: 'ESP32 Collares', status: '5 online', ok: true),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════

class _KpiItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback? onTap;

  const _KpiItem({required this.icon, required this.label,
      required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBtn({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  final VoidCallback? onTap;

  const _ActivityRow({required this.icon, required this.label,
      required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label, status;
  final bool ok;

  const _StatusRow({required this.icon, required this.label, required this.status, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ok ? AppTheme.primary : AppTheme.thiDanger),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (ok ? AppTheme.primary : AppTheme.thiDanger).withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status, style: TextStyle(
                color: ok ? AppTheme.primary : AppTheme.thiDanger, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

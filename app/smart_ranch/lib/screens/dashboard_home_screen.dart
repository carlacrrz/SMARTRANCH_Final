import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/ranch_models.dart';
import '../services/ranch_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/crud_dialogs.dart';

/// Dashboard home screen — overview stats + quick actions, desktop 3-column layout.
class DashboardHomeScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardHomeScreen({super.key, this.onNavigate});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  static final _demoStats = DashboardStats(
    totalActive: 5,
    animalsByStatus: {'active': 5},
    animalsByCategory: {'vaca': 3, 'becerro': 1, 'toro': 1},
    upcomingMedical7d: 2,
    expectedBirths30d: 1,
    unacknowledgedAlerts: 3,
  );

  static final _cleanStats = DashboardStats(
    totalActive: 0,
    animalsByStatus: {'active': 0},
    animalsByCategory: {'vaca': 0, 'becerro': 0, 'toro': 0},
    upcomingMedical7d: 0,
    expectedBirths30d: 0,
    unacknowledgedAlerts: 0,
  );

  DashboardStats _stats = AuthService.isDemoMode ? _demoStats : _cleanStats;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final result = await RanchApiService.getDashboardStats().timeout(
        const Duration(seconds: 2),
      );
      if (mounted) {
        setState(() {
          _stats = result;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stats = AuthService.isDemoMode ? _demoStats : _cleanStats;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header (Always visible)
              _buildHeader(),
              const SizedBox(height: 12),

              // KPI strip — responsive (grid/row on desktop, scroll on mobile)
              _buildKpiStrip(stats),
              const SizedBox(height: 14),

              // Multi-column layout based on viewport width
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1200) {
                    // 3-Column Desktop / Web layout
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildHerdDistribution(stats),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: _buildQuickActions(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: _buildActivitySummary(stats),
                        ),
                      ],
                    );
                  } else if (constraints.maxWidth >= 800) {
                    // 2-Column Tablet / Medium Web layout
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildHerdDistribution(stats),
                              const SizedBox(height: 14),
                              _buildQuickActions(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: _buildActivitySummary(stats),
                        ),
                      ],
                    );
                  }

                  // 1-Column Mobile layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHerdDistribution(stats),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 12),
                      _buildActivitySummary(stats),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12 ? 'Buenos días' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';
    
    final user = AuthService.currentUser;
    String name = AuthService.registeredUserName;
    if (name.isEmpty || name.toLowerCase() == 'demo') {
      name = 'Carla';
    }
    final greeting = '$timeGreeting, $name!';
    final ranchName = user?['ranch_name']?.toString() ?? AuthService.ranchName;
    final now = DateTime.now();
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ranchName — $dateStr',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.primary, size: 24),
            onPressed: _loadStats,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiStrip(DashboardStats stats) {
    final kpis = [
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: isDesktop
              ? Row(
                  children: kpis.map((kpi) => Expanded(child: kpi)).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: kpis),
                ),
        );
      },
    );
  }

  Widget _buildHerdDistribution(DashboardStats stats) {
    final categories = stats.animalsByCategory;
    if (categories.isEmpty) return const SizedBox.shrink();

    final total = categories.values.fold<int>(0, (s, v) => s + v);
    // Updated colors: distinct for each category
    final colorMap = {
      'vaca': AppTheme.primary,
      'becerro': const Color(0xFF66BB6A), // Green for calves
      'toro': const Color(0xFF7E57C2),    // Purple for bulls
      'novilla': const Color(0xFFAB47BC), // Pink-purple for heifers
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text('Distribución del Hato',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: categories.entries.where((e) => e.value > 0).map((e) {
                  final pct = total > 0 ? e.value / total : 0.0;
                  return Flexible(
                    flex: (pct * 100).round().clamp(1, 100),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: colorMap[e.key] ?? AppTheme.textSecondary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: categories.entries.map((e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: colorMap[e.key] ?? AppTheme.textSecondary,
                      borderRadius: BorderRadius.circular(3),
                    )),
                const SizedBox(width: 6),
                Text('${_categoryLabel(e.key)}: ${e.value}',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String key) => switch (key) {
    'vaca' => 'Vacas',
    'becerro' => 'Becerros',
    'toro' => 'Toros',
    'novilla' => 'Novillas',
    _ => key,
  };

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: AppTheme.secondary),
              const SizedBox(width: 6),
              Text('Acciones Rápidas',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionBtn(icon: Icons.add_rounded, label: 'Registrar Animal',
                  onTap: () => widget.onNavigate?.call(12)), // Navigate to Add Animal tab
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text('Resumen de Actividad',
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
          Divider(color: AppTheme.divider, height: 20),
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
    return SizedBox(
      width: 100,
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
              Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
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
            Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
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
            Expanded(child: Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12))),
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

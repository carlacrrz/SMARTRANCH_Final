import 'dart:io';
import 'package:flutter/material.dart';
import 'config/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/water_dashboard_screen.dart';
import 'screens/herd_screen.dart';
import 'screens/dashboard_home_screen.dart';
import 'screens/sanidad_screen.dart';
import 'screens/reproductive_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/gps_map_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/financial_screen.dart';
import 'screens/peso_screen.dart';
import 'screens/login_screen.dart';
import 'screens/report_screen.dart';
import 'services/demo_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop window — minimum size handled by framework
  }
  runApp(const SmartRanchApp());
}

class SmartRanchApp extends StatelessWidget {
  const SmartRanchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Ranch - Ganadería Inteligente',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AuthGate(),
    );
  }
}

/// Auth gate — shows login screen or main shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _authenticated = false;

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return LoginScreen(
        onAuthenticated: () => setState(() => _authenticated = true),
      );
    }
    return const MainShell();
  }
}

/// Desktop shell with NavigationRail sidebar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _railExtended = false;
  final DemoService _demoService = DemoService();

  static const _sections = [
    _Section('Inicio', Icons.dashboard_rounded),
    _Section('Monitor THI', Icons.thermostat_rounded),
    _Section('Agua', Icons.water_drop_rounded),
    _Section('Inventario', Icons.inventory_2_rounded),
    _Section('Sanidad', Icons.medical_services_rounded),
    _Section('Reproducción', Icons.favorite_rounded),
    _Section('Alertas', Icons.notifications_active_rounded),
    _Section('Peso', Icons.monitor_weight_rounded),
    _Section('Alimentación', Icons.restaurant_rounded),
    _Section('GPS / Mapa', Icons.map_rounded),
    _Section('Finanzas', Icons.account_balance_rounded),
    _Section('Reportes', Icons.analytics_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _demoService.start();
  }

  @override
  void dispose() {
    _demoService.dispose();
    super.dispose();
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const DashboardHomeScreen();
      case 1:
        return DashboardScreen(demoService: _demoService);
      case 2:
        return WaterDashboardScreen(demoService: _demoService);
      case 3:
        return const HerdScreen();
      case 4:
        return SanidadScreen(demoService: _demoService);
      case 5:
        return ReproductiveScreen(demoService: _demoService);
      case 6:
        return const AlertsScreen();
      case 7:
        return const PesoScreen();
      case 8:
        return const FeedScreen();
      case 9:
        return const GpsMapScreen();
      case 10:
        return const FinancialScreen();
      case 11:
        return const ReportScreen();
      default:
        return const Center(child: Text('Pantalla no encontrada'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- Left Sidebar ---
          MouseRegion(
            onEnter: (_) => setState(() => _railExtended = true),
            onExit: (_) => setState(() => _railExtended = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _railExtended ? 200 : 72,
              color: AppTheme.surface,
              child: Column(
                children: [
                  // Brand Header
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.agriculture_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                        if (_railExtended) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Smart Ranch',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.divider),

                  // Scrollable Nav Items
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: _sections.asMap().entries.map((e) {
                          final idx = e.key;
                          final section = e.value;
                          final selected = idx == _selectedIndex;
                          return _NavItem(
                            icon: section.icon,
                            label: section.label,
                            selected: selected,
                            extended: _railExtended,
                            onTap: () => setState(() => _selectedIndex = idx),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Connection Status at bottom
                  const Divider(height: 1, color: AppTheme.divider),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _demoService.isRunning
                                ? AppTheme.primary
                                : AppTheme.thiEmergency,
                          ),
                        ),
                        if (_railExtended) ...[
                          const SizedBox(width: 8),
                          Text(
                            _demoService.isRunning ? 'Conectado' : 'Desconectado',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vertical Divider
          VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),

          // --- Main Content ---
          Expanded(
            child: Column(
              children: [
                // Title Bar
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.divider, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sections[_selectedIndex].icon,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sections[_selectedIndex].label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: List.generate(
                      _sections.length,
                      (i) => _buildScreen(i),
                    ),
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

class _Section {
  final String label;
  final IconData icon;
  const _Section(this.label, this.icon);
}

/// Custom sidebar navigation item with hover and selection states.
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.selected
        ? AppTheme.primary.withAlpha(20)
        : _hovered
            ? AppTheme.primary.withAlpha(10)
            : Colors.transparent;
    final iconColor = widget.selected
        ? AppTheme.primary
        : _hovered
            ? AppTheme.textPrimary
            : AppTheme.textSecondary;
    final textColor = widget.selected
        ? AppTheme.textPrimary
        : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: widget.selected
                  ? Border.all(color: AppTheme.primary.withAlpha(40))
                  : null,
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 19, color: iconColor),
                if (widget.extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

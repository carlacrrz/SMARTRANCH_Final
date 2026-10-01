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
import 'screens/add_animal_screen.dart';
import 'screens/system_status_screen.dart';
import 'services/demo_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Desktop window — minimum size handled by framework
  }
  runApp(const SmartRanchApp());
}

class SmartRanchApp extends StatefulWidget {
  const SmartRanchApp({super.key});

  @override
  State<SmartRanchApp> createState() => _SmartRanchAppState();
}

class _SmartRanchAppState extends State<SmartRanchApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateTheme();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _updateTheme();
    });
    super.didChangePlatformBrightness();
  }

  void _updateTheme() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppTheme.isDark = brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    // Re-check just in case
    _updateTheme();
    
    return MaterialApp(
      title: 'Smart Ranch - Ganadería Inteligente',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
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
    _Section('Agregar Animal', Icons.add_circle_outline_rounded),
    _Section('Estado Sistema', Icons.dns_rounded),
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

  void _navigateTo(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return DashboardHomeScreen(onNavigate: _navigateTo);
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
      case 12:
        return const AddAnimalScreen();
      case 13:
        return const SystemStatusScreen();
      default:
        return const Center(child: Text('Pantalla no encontrada'));
    }
  }

  Widget _buildSidebar({required bool isMobile}) {
    final width = isMobile ? 250.0 : (_railExtended ? 200.0 : 72.0);
    final isExtended = isMobile || _railExtended;
    
    Widget sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      color: AppTheme.surface,
      child: Column(
        children: [
          // Brand Header
          Container(
            height: isMobile ? 120 : 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            alignment: isMobile ? Alignment.bottomLeft : Alignment.centerLeft,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo_icon.png',
                    width: 32,
                    height: 32,
                  ),
                ),
                if (isExtended) ...[
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
          Divider(height: 1, color: AppTheme.divider),

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
                    extended: isExtended,
                    onTap: () {
                      setState(() => _selectedIndex = idx);
                      if (isMobile) {
                        Navigator.pop(context); // Close drawer
                      }
                    },
                  );
                }).toList(),
              ),
            ),
          ),

          // Connection Status at bottom
          Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, isMobile ? 24 : 12),
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
                if (isExtended) ...[
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
    );

    if (isMobile) return SafeArea(child: sidebar);

    return MouseRegion(
      onEnter: (_) => setState(() => _railExtended = true),
      onExit: (_) => setState(() => _railExtended = false),
      child: sidebar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        final content = Column(
          children: [
            // Title Bar (Desktop only, Mobile uses AppBar)
            if (!isMobile)
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
        );

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: AppTheme.background,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              title: Row(
                children: [
                  Icon(
                    _sections[_selectedIndex].icon,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sections[_selectedIndex].label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppTheme.divider, height: 1),
              ),
            ),
            drawer: Drawer(
              backgroundColor: AppTheme.surface,
              child: _buildSidebar(isMobile: true),
            ),
            body: content,
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _buildSidebar(isMobile: false),
              VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
              Expanded(child: content),
            ],
          ),
        );
      },
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  const SizedBox(width: 8),
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

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';

/// Screen for general ranch and application settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Ranch Information
  final _ranchNameCtrl = TextEditingController(text: 'Rancho Cananea');
  final _stateCtrl = TextEditingController(text: 'Sonora');
  final _municipalityCtrl = TextEditingController(text: 'Cananea');
  final _latCtrl = TextEditingController(text: '30.9845');
  final _lngCtrl = TextEditingController(text: '-110.2974');
  final _headsCountCtrl = TextEditingController(text: '120');

  // THI & IoT Sensor Thresholds
  double _thiAlertThreshold = 75.0;
  double _thiDangerThreshold = 79.0;
  double _thiEmergencyThreshold = 84.0;
  int _syncIntervalMinutes = 5;

  // Preferences
  String _tempUnit = '°C';
  String _weightUnit = 'kg';
  bool _pushNotifications = true;
  bool _soundAlerts = true;
  bool _offlineCache = true;

  @override
  void dispose() {
    _ranchNameCtrl.dispose();
    _stateCtrl.dispose();
    _municipalityCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _headsCountCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Configuración guardada y sincronizada'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuración del Rancho & Sistema',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Personaliza parámetros geográficos, alertas THI, unidades y sensores IoT.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // SECTION 1: Ranch Info & Location
                _buildCard(
                  title: 'Información del Rancho y Ubicación',
                  icon: Icons.place_rounded,
                  iconColor: AppTheme.primary,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _ranchNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Rancho',
                              prefixIcon: Icon(Icons.business_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _headsCountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total Cabezas Estimadas',
                              prefixIcon: Icon(Icons.pets_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _stateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                              prefixIcon: Icon(Icons.map_outlined, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _municipalityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Municipio / Región',
                              prefixIcon: Icon(Icons.location_city_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Latitud GPS Centro',
                              prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lngCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Longitud GPS Centro',
                              prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // SECTION 2: THI & IoT Thresholds
                _buildCard(
                  title: 'Umbrales de Estrés Calórico (Índice THI)',
                  icon: Icons.thermostat_rounded,
                  iconColor: AppTheme.thiDanger,
                  children: [
                    Text(
                      'Ajusta los niveles en los cuales se detonarán notificaciones automáticas y aspersores.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Alerta
                    _buildSliderTile(
                      label: 'Umbral Alerta Moderada',
                      value: _thiAlertThreshold,
                      min: 68.0,
                      max: 80.0,
                      color: AppTheme.thiAlert,
                      onChanged: (v) => setState(() => _thiAlertThreshold = v),
                    ),
                    const SizedBox(height: 8),

                    // Peligro
                    _buildSliderTile(
                      label: 'Umbral Peligro Crítico',
                      value: _thiDangerThreshold,
                      min: 75.0,
                      max: 85.0,
                      color: AppTheme.thiDanger,
                      onChanged: (v) => setState(() => _thiDangerThreshold = v),
                    ),
                    const SizedBox(height: 8),

                    // Emergencia
                    _buildSliderTile(
                      label: 'Umbral Emergencia Extrema',
                      value: _thiEmergencyThreshold,
                      min: 80.0,
                      max: 95.0,
                      color: AppTheme.thiEmergency,
                      onChanged: (v) => setState(() => _thiEmergencyThreshold = v),
                    ),
                    const SizedBox(height: 16),

                    // Intervalo de Sincronización
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Frecuencia de Muestreo de Collares',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                'Optimiza el consumo de batería de los dispositivos LoRa / BLE',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _syncIntervalMinutes,
                          dropdownColor: AppTheme.card,
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 min')),
                            DropdownMenuItem(value: 5, child: Text('5 min')),
                            DropdownMenuItem(value: 15, child: Text('15 min')),
                            DropdownMenuItem(value: 30, child: Text('30 min')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _syncIntervalMinutes = v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // SECTION 3: Units & Preferences
                _buildCard(
                  title: 'Unidades y Preferencias del Sistema',
                  icon: Icons.tune_rounded,
                  iconColor: AppTheme.primary,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unidad de Temperatura', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: '°C', label: Text('Celsius (°C)')),
                                  ButtonSegment(value: '°F', label: Text('Fahrenheit (°F)')),
                                ],
                                selected: {_tempUnit},
                                onSelectionChanged: (s) => setState(() => _tempUnit = s.first),
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppTheme.primary.withAlpha(40);
                                    }
                                    return AppTheme.surface;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unidad de Peso', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'kg', label: Text('Kilogramos (kg)')),
                                  ButtonSegment(value: 'lb', label: Text('Libras (lb)')),
                                ],
                                selected: {_weightUnit},
                                onSelectionChanged: (s) => setState(() => _weightUnit = s.first),
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return AppTheme.primary.withAlpha(40);
                                    }
                                    return AppTheme.surface;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: AppTheme.divider),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notificaciones Push de Alertas Críticas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Recibir avisos de celo, estrés THI y cercos virtuales', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      value: _pushNotifications,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _pushNotifications = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alarmas Sonoras en Emergencias', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Emitir sonido de alerta cuando un animal salga del potrero', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      value: _soundAlerts,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _soundAlerts = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Almacenamiento Local Offline', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Guardar datos de pesajes y salud sin conexión a internet', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      value: _offlineCache,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _offlineCache = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // SECTION 4: User & Session Info
                _buildCard(
                  title: 'Cuenta y Sesión Activa',
                  icon: Icons.person_rounded,
                  iconColor: AppTheme.primary,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withAlpha(30),
                        child: Text(
                          AuthService.userName.isNotEmpty ? AuthService.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(AuthService.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Usuario autenticado • Administrador del Rancho', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('ACTIVO', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withAlpha(40),
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

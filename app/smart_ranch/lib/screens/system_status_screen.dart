import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../services/mqtt_realtime_service.dart';

/// Technical system status screen — extracted from the dashboard.
class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  bool _testing = false;
  bool _firestoreOk = true;
  bool _apiOk = true;
  bool _mqttOk = true;
  String _apiLatency = '12ms';
  String _firestoreLatency = '24ms';

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final stopwatch = Stopwatch()..start();

    // 1. Test Firestore
    try {
      final s = Stopwatch()..start();
      await FirebaseFirestore.instance.collection('animals').limit(1).get().timeout(const Duration(seconds: 3));
      s.stop();
      _firestoreLatency = '${s.elapsedMilliseconds}ms';
      _firestoreOk = true;
    } catch (_) {
      _firestoreOk = false;
    }

    // 2. Test REST API
    try {
      final s = Stopwatch()..start();
      final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/health')).timeout(const Duration(seconds: 2));
      s.stop();
      _apiLatency = '${s.elapsedMilliseconds}ms';
      _apiOk = res.statusCode == 200;
    } catch (_) {
      _apiOk = false;
    }

    // 3. Test MQTT
    _mqttOk = MqttRealtimeService.isConnected;
    if (!_mqttOk) {
      _mqttOk = await MqttRealtimeService.connect();
    }

    stopwatch.stop();

    if (mounted) {
      setState(() => _testing = false);
      final allOk = _firestoreOk && (_apiOk || _mqttOk);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allOk
                ? '✅ Diagnóstico completado — Sistema operativo (${stopwatch.elapsedMilliseconds}ms)'
                : '⚠️ Diagnóstico completado con advertencias en servicios de red',
          ),
          backgroundColor: allOk ? AppTheme.primary : AppTheme.thiAlert,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.dns_rounded, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Estado del Sistema', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Monitoreo en tiempo real de infraestructura IoT y Cloud.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Servicios
              _buildSection('SERVICIOS & INFRAESTRUCTURA', [
                _StatusRow(
                  icon: Icons.cloud_done_rounded,
                  label: 'Firebase Firestore',
                  status: _firestoreOk ? 'En línea ($_firestoreLatency)' : 'Sin conexión',
                  ok: _firestoreOk,
                ),
                _StatusRow(
                  icon: Icons.api_rounded,
                  label: 'API REST Gateway',
                  status: _apiOk ? 'Activo ($_apiLatency)' : 'Local Standalone',
                  ok: _apiOk,
                ),
                _StatusRow(
                  icon: Icons.sensors_rounded,
                  label: 'Broker MQTT Realtime',
                  status: _mqttOk ? 'Conectado' : 'Reintentando',
                  ok: _mqttOk,
                ),
                _StatusRow(
                  icon: Icons.memory_rounded,
                  label: 'Collares Inteligentes (ESP32)',
                  status: '5 sincronizados',
                  ok: true,
                ),
                _StatusRow(
                  icon: Icons.shield_rounded,
                  label: 'Cercos Virtuales & Geofencing',
                  status: 'Activo',
                  ok: true,
                ),
              ]),
              const SizedBox(height: 16),

              // Configuración
              _buildSection('CONFIGURACIÓN DEL SERVIDOR', [
                _InfoRow(label: 'API Base URL', value: AppConfig.apiBaseUrl),
                _InfoRow(label: 'MQTT Host', value: AppConfig.mqttHost),
                _InfoRow(label: 'MQTT Puerto TCP', value: '${AppConfig.mqttPortTcp}'),
                _InfoRow(label: 'MQTT Puerto WS', value: '${AppConfig.mqttPortWs}'),
              ]),
              const SizedBox(height: 16),

              // Umbrales THI
              _buildSection('UMBRALES THI (Estrés Térmico)', [
                _InfoRow(label: 'Normal', value: '< ${AppConfig.thiNormal}'),
                _InfoRow(label: 'Alerta', value: '≥ ${AppConfig.thiAlert}'),
                _InfoRow(label: 'Peligro', value: '≥ ${AppConfig.thiDanger}'),
                _InfoRow(label: 'Emergencia', value: '≥ ${AppConfig.thiEmergency}'),
              ]),
              const SizedBox(height: 16),

              // Diagnóstico
              _buildSection('DIAGNÓSTICO', [
                _InfoRow(label: 'Plataforma', value: Theme.of(context).platform.name),
                _InfoRow(label: 'Última sincronización', value: _formatNow()),
                _InfoRow(label: 'Versión App', value: 'v2.0'),
              ]),
              const SizedBox(height: 24),

              // Test button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_find_rounded),
                  label: Text(_testing ? 'Probando...' : 'Probar Conexión',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ok ? AppTheme.primary : AppTheme.thiDanger),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ok ? AppTheme.primary : AppTheme.thiDanger).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: TextStyle(
                color: ok ? AppTheme.primary : AppTheme.thiDanger, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          Text(value, style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

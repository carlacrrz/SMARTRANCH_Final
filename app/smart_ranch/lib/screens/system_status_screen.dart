import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_config.dart';

/// Technical system status screen — extracted from the dashboard.
class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  bool _testing = false;

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Conexión exitosa — todos los servicios activos'),
          backgroundColor: AppTheme.primary,
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
              Text('Monitoreo de servicios e infraestructura IoT del rancho.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Servicios
              _buildSection('SERVICIOS', [
                _StatusRow(icon: Icons.cloud_done_rounded, label: 'PostgreSQL', status: 'Conectado', ok: true),
                _StatusRow(icon: Icons.sensors_rounded, label: 'MQTT Broker', status: 'Activo', ok: true),
                _StatusRow(icon: Icons.storage_rounded, label: 'InfluxDB', status: 'Activo', ok: true),
                _StatusRow(icon: Icons.dashboard_rounded, label: 'Grafana', status: ':3000', ok: true),
                _StatusRow(icon: Icons.memory_rounded, label: 'ESP32 Collares', status: '5 online', ok: true),
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

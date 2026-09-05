import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';

/// Report viewer — opens ranch status report from API.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportUrl = '${AppConfig.apiBaseUrl}/api/reports/ranch-status';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text('📊 Reportes', style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 22)),
            const SizedBox(height: 4),
            const Text('Genera y descarga reportes del rancho.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),

            // Report cards
            _ReportCard(
              icon: Icons.assessment_rounded,
              title: 'Reporte de Estatus del Rancho',
              description: 'Inventario, categorías, pesos promedio, eventos médicos próximos, '
                  'partos esperados, alertas sin atender, resumen financiero.',
              formats: const ['HTML', 'JSON'],
              url: reportUrl,
            ),
            const SizedBox(height: 16),

            _ReportCard(
              icon: Icons.medical_services_rounded,
              title: 'Reporte Sanitario',
              description: 'Historial de vacunas, tratamientos y desparasitaciones. '
                  'Próximos eventos médicos y costos acumulados.',
              formats: const ['Próximamente'],
              url: null,
            ),
            const SizedBox(height: 16),

            _ReportCard(
              icon: Icons.monetization_on_rounded,
              title: 'Reporte Financiero Mensual',
              description: 'Ingresos por ventas, gastos por categoría, utilidad neta. '
                  'Incluye costo por cabeza y tendencia mensual.',
              formats: const ['Próximamente'],
              url: null,
            ),

            const Spacer(),

            // Footer tip
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppTheme.secondary, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tip: Los reportes HTML pueden imprimirse como PDF con Ctrl+P → Guardar como PDF.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final List<String> formats;
  final String? url;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.formats,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: formats.map((f) {
                    final available = url != null && f != 'Próximamente';
                    return GestureDetector(
                      onTap: available ? () => _openReport(context, f) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: available
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: available ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          available ? '📄 $f' : f,
                          style: TextStyle(
                            color: available ? AppTheme.primary : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openReport(BuildContext context, String format) {
    final formatParam = format == 'JSON' ? '?format=json' : '';
    final fullUrl = '$url$formatParam';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Abriendo reporte: $fullUrl'),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );

    // In a real app, this would use url_launcher to open in browser
    // For now, show the URL in a snackbar
  }
}

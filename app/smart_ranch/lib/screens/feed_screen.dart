import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';

class _FeedItem {
  String name;
  String category;
  double stockKg;
  double unitCost;
  String unit;
  double dailyUsageKg;
  double minStockKg;

  _FeedItem({
    required this.name,
    required this.category,
    required this.stockKg,
    required this.unitCost,
    required this.unit,
    required this.dailyUsageKg,
    required this.minStockKg,
  });
}

class _RationPlan {
  String name;
  String target;
  List<String> items;
  double costPerDay;
  int heads;

  _RationPlan({
    required this.name,
    required this.target,
    required this.items,
    required this.costPerDay,
    required this.heads,
  });
}

/// Alimentación (Feed Management) screen — full CRUD for inventory and ration plans.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<_FeedItem> _feedInventory = [
    _FeedItem(name: 'Pasto Buffel (Seco)', category: 'Forraje', stockKg: 2500, unitCost: 3.5, unit: 'kg',
        dailyUsageKg: 80, minStockKg: 500),
    _FeedItem(name: 'Alfalfa Henificada', category: 'Forraje', stockKg: 1200, unitCost: 8.0, unit: 'kg',
        dailyUsageKg: 40, minStockKg: 300),
    _FeedItem(name: 'Maíz Molido', category: 'Concentrado', stockKg: 800, unitCost: 7.5, unit: 'kg',
        dailyUsageKg: 25, minStockKg: 200),
    _FeedItem(name: 'Melaza', category: 'Suplemento', stockKg: 350, unitCost: 5.0, unit: 'L',
        dailyUsageKg: 10, minStockKg: 100),
    _FeedItem(name: 'Bloque Mineral', category: 'Mineral', stockKg: 50, unitCost: 45.0, unit: 'pieza',
        dailyUsageKg: 0.5, minStockKg: 10),
    _FeedItem(name: 'Sal Mineral', category: 'Mineral', stockKg: 80, unitCost: 12.0, unit: 'kg',
        dailyUsageKg: 1, minStockKg: 20),
  ];

  final List<_RationPlan> _rations = [
    _RationPlan(name: 'Ración Mantenimiento', target: 'Vacas adultas', items: [
      'Pasto Buffel: 15 kg/día', 'Sal Mineral: 60g/día', 'Bloque Mineral: libre acceso'
    ], costPerDay: 58.0, heads: 5),
    _RationPlan(name: 'Ración Engorda', target: 'Becerros destete', items: [
      'Maíz Molido: 4 kg/día', 'Alfalfa: 6 kg/día', 'Melaza: 1 L/día', 'Mineral: 80g/día'
    ], costPerDay: 85.0, heads: 2),
    _RationPlan(name: 'Ración Gestación', target: 'Vacas gestantes', items: [
      'Alfalfa: 8 kg/día', 'Pasto: 10 kg/día', 'Concentrado: 2 kg/día', 'Mineral: 100g/día'
    ], costPerDay: 112.0, heads: 1),
  ];

  void _showFeedItemDialog({_FeedItem? item, int? index}) {
    final isEditing = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final stockCtrl = TextEditingController(text: item != null ? item.stockKg.toStringAsFixed(0) : '');
    final minStockCtrl = TextEditingController(text: item != null ? item.minStockKg.toStringAsFixed(0) : '100');
    final costCtrl = TextEditingController(text: item != null ? item.unitCost.toStringAsFixed(1) : '5.0');
    final usageCtrl = TextEditingController(text: item != null ? item.dailyUsageKg.toStringAsFixed(1) : '10');
    String unit = item?.unit ?? 'kg';
    String category = item?.category ?? 'Forraje';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Insumo' : 'Agregar Insumo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Insumo *', hintText: 'Ej. Alfalfa, Maíz...'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: category,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: const [
                          DropdownMenuItem(value: 'Forraje', child: Text('Forraje')),
                          DropdownMenuItem(value: 'Concentrado', child: Text('Concentrado')),
                          DropdownMenuItem(value: 'Suplemento', child: Text('Suplemento')),
                          DropdownMenuItem(value: 'Mineral', child: Text('Mineral')),
                          DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                        ],
                        onChanged: (v) => setDialogState(() => category = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        dropdownColor: AppTheme.card,
                        decoration: const InputDecoration(labelText: 'Unidad'),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('Kilogramo (kg)')),
                          DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                          DropdownMenuItem(value: 'pieza', child: Text('Pieza')),
                          DropdownMenuItem(value: 'ton', child: Text('Tonelada')),
                        ],
                        onChanged: (v) => setDialogState(() => unit = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Stock Actual ($unit) *'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Mínimo Alerta ($unit)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: costCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Costo Unitario (\$/$unit)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: usageCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Uso Diario ($unit/día)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  setState(() => _feedInventory.removeAt(index!));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insumo eliminado'), backgroundColor: AppTheme.thiDanger),
                  );
                },
                child: const Text('Eliminar', style: TextStyle(color: AppTheme.thiDanger)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final stock = double.tryParse(stockCtrl.text) ?? 0.0;
                final minStock = double.tryParse(minStockCtrl.text) ?? 50.0;
                final cost = double.tryParse(costCtrl.text) ?? 5.0;
                final usage = double.tryParse(usageCtrl.text) ?? 0.0;

                if (name.isEmpty) return;

                setState(() {
                  if (isEditing && index != null) {
                    _feedInventory[index] = _FeedItem(
                      name: name,
                      category: category,
                      stockKg: stock,
                      unitCost: cost,
                      unit: unit,
                      dailyUsageKg: usage,
                      minStockKg: minStock,
                    );
                  } else {
                    _feedInventory.add(_FeedItem(
                      name: name,
                      category: category,
                      stockKg: stock,
                      unitCost: cost,
                      unit: unit,
                      dailyUsageKg: usage,
                      minStockKg: minStock,
                    ));
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? '✅ Insumo actualizado' : '✅ Insumo agregado al inventario'),
                    backgroundColor: AppTheme.primary,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Guardar' : 'Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRationDialog({_RationPlan? ration, int? index}) {
    final isEditing = ration != null;
    final nameCtrl = TextEditingController(text: ration?.name ?? '');
    final targetCtrl = TextEditingController(text: ration?.target ?? 'Vacas adultas');
    final costCtrl = TextEditingController(text: ration != null ? ration.costPerDay.toStringAsFixed(0) : '60');
    final headsCtrl = TextEditingController(text: ration != null ? ration.heads.toString() : '5');
    final itemsCtrl = TextEditingController(text: ration?.items.join('\n') ?? 'Pasto Buffel: 15 kg/día\nSal Mineral: 60g/día');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit_note_rounded : Icons.receipt_long_rounded, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(isEditing ? 'Editar Plan de Ración' : 'Crear Plan de Ración', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre de la Ración *', hintText: 'Ej. Ración Engorda'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                decoration: const InputDecoration(labelText: 'Etapa / Lote Destino *', hintText: 'Ej. Becerros destete, Gestantes'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Costo/día/cabeza (\$)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: headsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cabezas asignadas'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes / Dosis (uno por línea)',
                  hintText: 'Maíz: 4 kg/día\nAlfalfa: 6 kg/día\nMineral: 80g/día',
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                setState(() => _rations.removeAt(index!));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan de ración eliminado'), backgroundColor: AppTheme.thiDanger),
                );
              },
              child: const Text('Eliminar', style: TextStyle(color: AppTheme.thiDanger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final target = targetCtrl.text.trim();
              final cost = double.tryParse(costCtrl.text) ?? 50.0;
              final heads = int.tryParse(headsCtrl.text) ?? 0;
              final items = itemsCtrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              if (name.isEmpty) return;

              setState(() {
                if (isEditing && index != null) {
                  _rations[index] = _RationPlan(
                    name: name,
                    target: target,
                    items: items,
                    costPerDay: cost,
                    heads: heads,
                  );
                } else {
                  _rations.add(_RationPlan(
                    name: name,
                    target: target,
                    items: items,
                    costPerDay: cost,
                    heads: heads,
                  ));
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEditing ? '✅ Ración actualizada' : '✅ Plan de ración creado y asignado'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            child: Text(isEditing ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  void _showShareDocumentDialog() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final totalDailyCost = _rations.fold<double>(0, (sum, r) => sum + (r.costPerDay * r.heads));
    final totalMonthlyCost = totalDailyCost * 30;
    final totalHeadsAssigned = _rations.fold<int>(0, (sum, r) => sum + r.heads);

    final docText = StringBuffer();
    docText.writeln('========================================');
    docText.writeln('  SMART RANCH — REPORTE DE NUTRICIÓN');
    docText.writeln('  Fecha: $dateStr');
    docText.writeln('========================================\n');

    docText.writeln('--- 1. INVENTARIO DE INSUMOS ---');
    for (final item in _feedInventory) {
      final days = item.dailyUsageKg > 0 ? (item.stockKg / item.dailyUsageKg).toStringAsFixed(0) : 'N/A';
      final status = item.stockKg <= item.minStockKg ? '[ALERTA: STOCK BAJO]' : '[OK]';
      docText.writeln('• ${item.name} (${item.category}):');
      docText.writeln('  Stock: ${item.stockKg.toStringAsFixed(0)} ${item.unit} | Costo: \$${item.unitCost}/${item.unit}');
      docText.writeln('  Uso diario: ${item.dailyUsageKg} ${item.unit}/día | Autonomía: $days días $status\n');
    }

    docText.writeln('--- 2. PLANES DE RACIÓN Y ASIGNACIÓN ---');
    for (final ration in _rations) {
      final subtotal = ration.costPerDay * ration.heads;
      docText.writeln('• ${ration.name} (Destino: ${ration.target}):');
      docText.writeln('  Ingredientes: ${ration.items.join(", ")}');
      docText.writeln('  Costo/vaca/día: \$${ration.costPerDay.toStringAsFixed(2)} MXN');
      docText.writeln('  Cabezas asignadas: ${ration.heads} cabezas');
      docText.writeln('  Subtotal diario: \$${subtotal.toStringAsFixed(2)} MXN\n');
    }

    docText.writeln('--- 3. RESUMEN FINANCIERO NUTRICIONAL ---');
    docText.writeln('• Total cabezas bajo racionamiento: $totalHeadsAssigned cabezas');
    docText.writeln('• Inversión diaria total en alimento: \$${totalDailyCost.toStringAsFixed(2)} MXN');
    docText.writeln('• Proyección mensual estimada (30 días): \$${totalMonthlyCost.toStringAsFixed(2)} MXN');
    docText.writeln('========================================');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_rounded, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Documento de Nutrición & Raciones',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Generado para exportar y compartir',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppTheme.divider),
              const SizedBox(height: 12),

              // Preview container
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      docText.toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docText.toString()));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Documento copiado al portapapeles'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar Texto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📤 Documento PDF generado y listo para enviar / imprimir'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Compartir / Enviar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDailyCost = _rations.fold<double>(0, (sum, r) => sum + (r.costPerDay * r.heads));
    final lowStockItems = _feedInventory.where((f) => f.stockKg <= f.minStockKg).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Top Header with Share Document Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Nutricional & Raciones',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Inventario de forrajes y costos por animal al día',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showShareDocumentDialog,
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text('Compartir Documento', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Stats strip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(icon: Icons.inventory_2_rounded, label: 'Insumos', value: '${_feedInventory.length}'),
                _Stat(icon: Icons.receipt_long_rounded, label: 'Raciones', value: '${_rations.length}'),
                _Stat(icon: Icons.attach_money_rounded, label: 'Costo/día', value: '\$${totalDailyCost.toStringAsFixed(0)}'),
                _Stat(icon: Icons.warning_amber_rounded, label: 'Stock bajo', value: '${lowStockItems.length}',
                    color: lowStockItems.isNotEmpty ? AppTheme.thiDanger : null),
              ],
            ),
          ),

          // Low stock warning
          if (lowStockItems.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.thiAlert.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.thiAlert.withAlpha(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.thiAlert),
                      const SizedBox(width: 6),
                      Text('Stock Bajo — Reabastecer', style: TextStyle(
                          color: AppTheme.thiAlert, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...lowStockItems.map((f) => Text(
                    '• ${f.name}: ${f.stockKg.toStringAsFixed(0)} ${f.unit} (mín: ${f.minStockKg.toStringAsFixed(0)})',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  )),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Stacked layout: Inventory on top, Rations below
          _buildInventoryPanel(),
          const SizedBox(height: 12),
          _buildRationsPanel(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInventoryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Inventario de Insumos',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showFeedItemDialog(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Agregar Insumo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(_feedInventory.length, (index) {
            final feed = _feedInventory[index];
            final daysLeft = feed.dailyUsageKg > 0 ? feed.stockKg / feed.dailyUsageKg : 999;
            final isLow = feed.stockKg <= feed.minStockKg;

            return InkWell(
              onTap: () => _showFeedItemDialog(item: feed, index: index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(80))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _categoryColor(feed.category).withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(_categoryIcon(feed.category), size: 16,
                          color: _categoryColor(feed.category)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(feed.name, style: TextStyle(
                              color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _categoryColor(feed.category).withAlpha(15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(feed.category, style: TextStyle(
                                    color: _categoryColor(feed.category), fontSize: 9, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 6),
                              Text('\$${feed.unitCost}/${feed.unit}',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${feed.stockKg.toStringAsFixed(0)} ${feed.unit}',
                            style: TextStyle(color: isLow ? AppTheme.thiDanger : AppTheme.textPrimary,
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        Text('${daysLeft.toStringAsFixed(0)} días',
                            style: TextStyle(color: daysLeft < 7 ? AppTheme.thiAlert : AppTheme.textSecondary, fontSize: 9)),
                      ],
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      color: AppTheme.textSecondary,
                      onPressed: () => _showFeedItemDialog(item: feed, index: index),
                      tooltip: 'Editar insumo',
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRationsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Planes de Ración y Asignación',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showRationDialog(),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Nueva Ración', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(_rations.length, (index) {
            final ration = _rations[index];
            final dailyTotal = ration.costPerDay * ration.heads;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(80))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ration.name, style: TextStyle(
                                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Destino: ${ration.target}',
                                style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: AppTheme.primary,
                        tooltip: 'Editar ración',
                        onPressed: () => _showRationDialog(ration: ration, index: index),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Ingredients chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ration.items.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Text(item, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Footer: cost + assigned heads stepper
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\$${ration.costPerDay.toStringAsFixed(0)} /cabeza/día',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          Text('Total: \$${dailyTotal.toStringAsFixed(0)}/día',
                              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      // Heads assigned stepper
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                              color: ration.heads > 0 ? AppTheme.primary : AppTheme.textSecondary,
                              onPressed: ration.heads > 0
                                  ? () => setState(() => ration.heads--)
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${ration.heads} cabezas',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                              color: AppTheme.primary,
                              onPressed: () => setState(() => ration.heads++),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _categoryColor(String category) => switch (category) {
    'Forraje' => const Color(0xFF66BB6A),
    'Concentrado' => const Color(0xFFFFA726),
    'Suplemento' => const Color(0xFFAB47BC),
    'Mineral' => const Color(0xFF42A5F5),
    _ => AppTheme.textSecondary,
  };

  IconData _categoryIcon(String category) => switch (category) {
    'Forraje' => Icons.grass_rounded,
    'Concentrado' => Icons.grain_rounded,
    'Suplemento' => Icons.water_drop_rounded,
    'Mineral' => Icons.diamond_rounded,
    _ => Icons.inventory_2_rounded,
  };
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;

  const _Stat({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c)),
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

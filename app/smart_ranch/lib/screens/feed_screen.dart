import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Alimentación (Feed Management) screen — 2-column desktop layout.
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
    ], costPerDay: 85.0, heads: 0),
    _RationPlan(name: 'Ración Gestación', target: 'Vacas gestantes', items: [
      'Alfalfa: 8 kg/día', 'Pasto: 10 kg/día', 'Concentrado: 2 kg/día', 'Mineral: 100g/día'
    ], costPerDay: 112.0, heads: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final totalDailyCost = _rations.fold<double>(0, (sum, r) => sum + (r.costPerDay * r.heads));
    final lowStockItems = _feedInventory.where((f) => f.stockKg <= f.minStockKg).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Stats strip
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(10),
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
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(10),
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
                      SizedBox(width: 6),
                      Text('Stock Bajo — Reabastecer', style: TextStyle(
                          color: AppTheme.thiAlert, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  SizedBox(height: 4),
                  ...lowStockItems.map((f) => Text(
                    '• ${f.name}: ${f.stockKg.toStringAsFixed(0)} ${f.unit} (mín: ${f.minStockKg.toStringAsFixed(0)})',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  )),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // 2-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — Inventory
              Expanded(
                flex: 6,
                child: _buildInventoryPanel(),
              ),
              const SizedBox(width: 8),
              // Right — Ration plans
              Expanded(
                flex: 4,
                child: _buildRationsPanel(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text('Inventario de Insumos',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ...List.generate(_feedInventory.length, (index) {
            final feed = _feedInventory[index];
            final daysLeft = feed.dailyUsageKg > 0 ? feed.stockKg / feed.dailyUsageKg : 999;
            final isLow = feed.stockKg <= feed.minStockKg;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            SizedBox(width: 6),
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
                ],
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
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.secondary),
                SizedBox(width: 6),
                Text('Planes de Ración',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.divider),
          ..._rations.map((ration) => Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(80))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded, size: 14, color: AppTheme.primary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(ration.name, style: TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('\$${ration.costPerDay.toStringAsFixed(0)}/cab/día',
                          style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text('${ration.target} (${ration.heads} cabezas)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                const SizedBox(height: 4),
                ...ration.items.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 1),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 4, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text(item, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                )),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) => switch (cat) {
    'Forraje' => const Color(0xFF66BB6A),
    'Concentrado' => Color(0xFFFFA726),
    'Suplemento' => Color(0xFF42A5F5),
    'Mineral' => Color(0xFFAB47BC),
    _ => AppTheme.textSecondary,
  };

  IconData _categoryIcon(String cat) => switch (cat) {
    'Forraje' => Icons.grass_rounded,
    'Concentrado' => Icons.grain_rounded,
    'Suplemento' => Icons.science_rounded,
    'Mineral' => Icons.diamond_rounded,
    _ => Icons.inventory_2_rounded,
  };
}

class _FeedItem {
  final String name, category, unit;
  final double stockKg, unitCost, dailyUsageKg, minStockKg;
  _FeedItem({required this.name, required this.category, required this.stockKg,
      required this.unitCost, required this.unit, required this.dailyUsageKg,
      required this.minStockKg});
}

class _RationPlan {
  final String name, target;
  final List<String> items;
  final double costPerDay;
  final int heads;
  _RationPlan({required this.name, required this.target, required this.items,
      required this.costPerDay, required this.heads});
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? color;
  const _Stat({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? AppTheme.textSecondary),
        SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
            color: color ?? AppTheme.textPrimary)),
        Text(label, style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

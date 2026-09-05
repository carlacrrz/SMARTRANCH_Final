import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Financial events screen — 3-panel desktop layout: P&L | Expense breakdown | Transactions.
class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  final List<_Transaction> _transactions = [
    _Transaction(type: 'income', category: 'Venta ganado', description: 'Venta 2 novillos 450kg c/u',
        amount: 54000, date: DateTime.now().subtract(const Duration(days: 5))),
    _Transaction(type: 'income', category: 'Venta leche', description: 'Producción semanal 280L',
        amount: 4200, date: DateTime.now().subtract(const Duration(days: 3))),
    _Transaction(type: 'expense', category: 'Alimentación', description: 'Compra alfalfa henificada 500kg',
        amount: 4000, date: DateTime.now().subtract(const Duration(days: 7))),
    _Transaction(type: 'expense', category: 'Veterinario', description: 'Vacunación hato completo + consulta',
        amount: 3500, date: DateTime.now().subtract(const Duration(days: 10))),
    _Transaction(type: 'expense', category: 'Alimentación', description: 'Maíz molido 200kg + melaza',
        amount: 2000, date: DateTime.now().subtract(const Duration(days: 12))),
    _Transaction(type: 'expense', category: 'Combustible', description: 'Diesel camioneta rancho',
        amount: 1800, date: DateTime.now().subtract(const Duration(days: 14))),
    _Transaction(type: 'income', category: 'Venta ganado', description: 'Venta becerro destete 220kg',
        amount: 15400, date: DateTime.now().subtract(const Duration(days: 20))),
    _Transaction(type: 'expense', category: 'Mano de obra', description: 'Jornal vaquero (quincenal)',
        amount: 6000, date: DateTime.now().subtract(const Duration(days: 15))),
    _Transaction(type: 'expense', category: 'Suplementos', description: 'Bloques minerales + sal',
        amount: 1200, date: DateTime.now().subtract(const Duration(days: 18))),
    _Transaction(type: 'expense', category: 'Mantenimiento', description: 'Reparación cerca eléctrica',
        amount: 2500, date: DateTime.now().subtract(const Duration(days: 25))),
  ];

  @override
  Widget build(BuildContext context) {
    final totalIncome = _transactions.where((t) => t.type == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpenses = _transactions.where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final profit = totalIncome - totalExpenses;

    final expensesByCategory = <String, double>{};
    for (final t in _transactions.where((t) => t.type == 'expense')) {
      expensesByCategory[t.category] = (expensesByCategory[t.category] ?? 0) + t.amount;
    }
    final sortedExpenses = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // P&L summary strip
          _buildPLSummary(totalIncome, totalExpenses, profit),
          const SizedBox(height: 8),

          // 3-panel layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — Income summary
              Expanded(
                flex: 3,
                child: _buildIncomeSummary(totalIncome),
              ),
              const SizedBox(width: 8),
              // Center — Expense breakdown
              Expanded(
                flex: 3,
                child: _buildExpenseBreakdown(sortedExpenses, totalExpenses),
              ),
              const SizedBox(width: 8),
              // Right — Recent transactions
              Expanded(
                flex: 4,
                child: _buildTransactionLog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPLSummary(double income, double expenses, double profit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FinStat(icon: Icons.trending_up_rounded, label: 'Ingresos',
                  value: '\$${_formatMoney(income)}', color: AppTheme.primary),
              _FinStat(icon: Icons.trending_down_rounded, label: 'Gastos',
                  value: '\$${_formatMoney(expenses)}', color: AppTheme.thiDanger),
              _FinStat(
                  icon: profit >= 0 ? Icons.check_circle_rounded : Icons.warning_rounded,
                  label: profit >= 0 ? 'Utilidad' : 'Pérdida',
                  value: '${profit >= 0 ? '+' : ''}\$${_formatMoney(profit.abs())}',
                  color: profit >= 0 ? AppTheme.primary : AppTheme.thiDanger),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: income > 0 ? (expenses / income).clamp(0, 1) : 0,
              backgroundColor: AppTheme.primary.withAlpha(20),
              valueColor: AlwaysStoppedAnimation(
                  expenses / (income > 0 ? income : 1) > 0.8 ? AppTheme.thiDanger : AppTheme.thiAlert),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Gastos: ${(income > 0 ? (expenses / income * 100) : 0).toStringAsFixed(0)}% de ingresos',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeSummary(double totalIncome) {
    final incomeByCategory = <String, double>{};
    for (final t in _transactions.where((t) => t.type == 'income')) {
      incomeByCategory[t.category] = (incomeByCategory[t.category] ?? 0) + t.amount;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text('Ingresos', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ...incomeByCategory.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(_categoryIcon(e.key), size: 14, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(e.key, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))),
                Text('\$${_formatMoney(e.value)}',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildExpenseBreakdown(List<MapEntry<String, double>> sorted, double total) {
    final colors = [
      AppTheme.thiDanger, AppTheme.thiAlert, AppTheme.primary,
      AppTheme.secondary, const Color(0xFFAB47BC), const Color(0xFF42A5F5),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 16, color: AppTheme.thiDanger),
                const SizedBox(width: 6),
                const Text('Desglose de Gastos', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ...List.generate(sorted.length, (index) {
            final entry = sorted[index];
            final pct = total > 0 ? entry.value / total : 0;
            final color = colors[index % colors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(_categoryIcon(entry.key), size: 12, color: color),
                      const SizedBox(width: 6),
                      Expanded(child: Text(entry.key,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))),
                      Text('\$${_formatMoney(entry.value)}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
                      const SizedBox(width: 6),
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      backgroundColor: AppTheme.surface,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTransactionLog() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text('Movimientos Recientes', style: TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ..._transactions.map((tx) {
            final isIncome = tx.type == 'income';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.divider.withAlpha(80))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: (isIncome ? AppTheme.primary : AppTheme.thiDanger).withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14, color: isIncome ? AppTheme.primary : AppTheme.thiDanger),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.description,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${tx.category} · ${tx.date.day}/${tx.date.month}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
                      ],
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}\$${_formatMoney(tx.amount)}',
                    style: TextStyle(
                      color: isIncome ? AppTheme.primary : AppTheme.thiDanger,
                      fontWeight: FontWeight.w600, fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toStringAsFixed(0);
  }

  IconData _categoryIcon(String cat) => switch (cat) {
    'Alimentación' => Icons.grass_rounded,
    'Veterinario' => Icons.vaccines_rounded,
    'Combustible' => Icons.local_gas_station_rounded,
    'Mano de obra' => Icons.engineering_rounded,
    'Suplementos' => Icons.diamond_rounded,
    'Mantenimiento' => Icons.build_rounded,
    'Venta ganado' => Icons.pets_rounded,
    'Venta leche' => Icons.water_drop_rounded,
    _ => Icons.attach_money_rounded,
  };
}

class _Transaction {
  final String type, category, description;
  final double amount;
  final DateTime date;
  _Transaction({required this.type, required this.category, required this.description,
      required this.amount, required this.date});
}

class _FinStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _FinStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

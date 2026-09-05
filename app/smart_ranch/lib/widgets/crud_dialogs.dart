import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/ranch_api_service.dart';

/// Reusable CRUD dialog forms for ranch operations.
/// Each form submits to the PostgreSQL API and returns the result.

// ============================================================
//  STYLED INPUT HELPERS
// ============================================================

InputDecoration _inputDecoration(String label, {IconData? icon}) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
  prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 18) : null,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppTheme.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
  ),
  filled: true,
  fillColor: AppTheme.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  isDense: true,
);

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6, top: 4),
  child: Text(text, style: const TextStyle(
      color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
);


// ============================================================
//  ADD ANIMAL DIALOG
// ============================================================

Future<bool> showAddAnimalDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final earTagCtrl = TextEditingController();
  final breedCtrl = TextEditingController(text: 'Brangus');
  final weightCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String sex = 'female';
  String category = 'vaca';
  String status = 'active';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text('Registrar Animal', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _sectionTitle('IDENTIFICACIÓN'),
                TextField(controller: nameCtrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Nombre', icon: Icons.pets)),
                const SizedBox(height: 10),
                TextField(controller: earTagCtrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Arete SINIIGA', icon: Icons.tag)),
                const SizedBox(height: 10),
                TextField(controller: breedCtrl, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Raza', icon: Icons.category)),

                const SizedBox(height: 14),
                _sectionTitle('CLASIFICACIÓN'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sex,
                        dropdownColor: AppTheme.card,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Sexo'),
                        items: const [
                          DropdownMenuItem(value: 'female', child: Text('Hembra')),
                          DropdownMenuItem(value: 'male', child: Text('Macho')),
                        ],
                        onChanged: (v) => setState(() => sex = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: AppTheme.card,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Categoría'),
                        items: const [
                          DropdownMenuItem(value: 'vaca', child: Text('Vaca')),
                          DropdownMenuItem(value: 'toro', child: Text('Toro')),
                          DropdownMenuItem(value: 'becerro', child: Text('Becerro')),
                          DropdownMenuItem(value: 'novilla', child: Text('Novilla')),
                        ],
                        onChanged: (v) => setState(() => category = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                _sectionTitle('DATOS'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          decoration: _inputDecoration('Peso (kg)', icon: Icons.monitor_weight)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        dropdownColor: AppTheme.card,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Estado'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Activo')),
                          DropdownMenuItem(value: 'sick', child: Text('Enfermo')),
                          DropdownMenuItem(value: 'pregnant', child: Text('Gestante')),
                        ],
                        onChanged: (v) => setState(() => status = v!),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                TextField(controller: notesCtrl, maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createAnimal({
                          'name': nameCtrl.text.trim(),
                          'ear_tag': earTagCtrl.text.trim(),
                          'breed': breedCtrl.text.trim(),
                          'sex': sex,
                          'category': category,
                          'status': status,
                          'weight_kg': double.tryParse(weightCtrl.text) ?? 0,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Registrar Animal', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD MEDICAL RECORD DIALOG
// ============================================================

Future<bool> showAddMedicalDialog(BuildContext context, {int? animalId}) async {
  final productCtrl = TextEditingController();
  final doseCtrl = TextEditingController();
  final adminCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController(text: animalId?.toString() ?? '');
  String recordType = 'vaccine';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text('Registro Médico', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 16),

                if (animalId == null) ...[
                  TextField(controller: animalIdCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: _inputDecoration('ID Animal', icon: Icons.pets)),
                  const SizedBox(height: 10),
                ],

                DropdownButtonFormField<String>(
                  initialValue: recordType,
                  dropdownColor: AppTheme.card,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'vaccine', child: Text('Vacuna')),
                    DropdownMenuItem(value: 'treatment', child: Text('Tratamiento')),
                    DropdownMenuItem(value: 'deworming', child: Text('Desparasitación')),
                    DropdownMenuItem(value: 'surgery', child: Text('Cirugía')),
                  ],
                  onChanged: (v) => setState(() => recordType = v!),
                ),
                const SizedBox(height: 10),

                TextField(controller: productCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Producto / Medicamento', icon: Icons.medication)),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: TextField(controller: doseCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Dosis'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: costCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: _inputDecoration('Costo \$'))),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(controller: adminCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Administrado por', icon: Icons.person)),
                const SizedBox(height: 10),

                TextField(controller: notesCtrl, maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 42,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final aid = animalId ?? int.tryParse(animalIdCtrl.text);
                      if (aid == null || productCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createMedicalRecord({
                          'animal_id': aid,
                          'record_type': recordType,
                          'product_name': productCtrl.text.trim(),
                          'dose': doseCtrl.text.trim(),
                          'administered_by': adminCtrl.text.trim(),
                          'cost': double.tryParse(costCtrl.text) ?? 0,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar Registro', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD WEIGHT RECORD DIALOG
// ============================================================

Future<bool> showAddWeightDialog(BuildContext context, {int? animalId}) async {
  final weightCtrl = TextEditingController();
  final bcsCtrl = TextEditingController(text: '3.0');
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController(text: animalId?.toString() ?? '');
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.monitor_weight, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text('Registrar Peso', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                      onPressed: () => Navigator.pop(ctx, false)),
                ],
              ),
              const SizedBox(height: 16),

              if (animalId == null) ...[
                TextField(controller: animalIdCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('ID Animal', icon: Icons.pets)),
                const SizedBox(height: 10),
              ],

              TextField(controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Peso (kg)', icon: Icons.monitor_weight)),
              const SizedBox(height: 10),

              TextField(controller: bcsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Condición Corporal (1-5)', icon: Icons.star_half)),
              const SizedBox(height: 10),

              TextField(controller: notesCtrl, maxLines: 2,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Notas')),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 42,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    final aid = animalId ?? int.tryParse(animalIdCtrl.text);
                    final w = double.tryParse(weightCtrl.text);
                    if (aid == null || w == null) return;
                    setState(() => loading = true);
                    try {
                      await RanchApiService.createWeightRecord({
                        'animal_id': aid,
                        'weight_kg': w,
                        'body_condition_score': double.tryParse(bcsCtrl.text) ?? 3.0,
                        'notes': notesCtrl.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setState(() => loading = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar Peso', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}


// ============================================================
//  ADD FINANCIAL EVENT DIALOG
// ============================================================

Future<bool> showAddFinancialDialog(BuildContext context) async {
  final amountCtrl = TextEditingController();
  final buyerSellerCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final animalIdCtrl = TextEditingController();
  String eventType = 'expense';
  bool loading = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 22),
                    const SizedBox(width: 8),
                    const Text('Movimiento Financiero', style: TextStyle(
                        color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                        onPressed: () => Navigator.pop(ctx, false)),
                  ],
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: eventType,
                  dropdownColor: AppTheme.card,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: _inputDecoration('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'sale', child: Text('Venta')),
                    DropdownMenuItem(value: 'purchase', child: Text('Compra')),
                    DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                    DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  ],
                  onChanged: (v) => setState(() => eventType = v!),
                ),
                const SizedBox(height: 10),

                TextField(controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Monto \$', icon: Icons.attach_money)),
                const SizedBox(height: 10),

                TextField(controller: animalIdCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('ID Animal (opcional)', icon: Icons.pets)),
                const SizedBox(height: 10),

                TextField(controller: buyerSellerCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Comprador / Vendedor', icon: Icons.person)),
                const SizedBox(height: 10),

                TextField(controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Peso al evento (kg)', icon: Icons.monitor_weight)),
                const SizedBox(height: 10),

                TextField(controller: notesCtrl, maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: _inputDecoration('Notas')),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 42,
                  child: ElevatedButton(
                    onPressed: loading ? null : () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null) return;
                      setState(() => loading = true);
                      try {
                        await RanchApiService.createFinancialEvent({
                          'event_type': eventType,
                          'amount': amount,
                          'animal_id': int.tryParse(animalIdCtrl.text),
                          'buyer_seller': buyerSellerCtrl.text.trim(),
                          'weight_at_event': double.tryParse(weightCtrl.text),
                          'notes': notesCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: loading
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar Movimiento', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

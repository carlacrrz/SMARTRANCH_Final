import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/ranch_api_service.dart';
import '../widgets/nfc_scanner_dialog.dart';

/// Dedicated full-page form for registering new animals.
class AddAnimalScreen extends StatefulWidget {
  const AddAnimalScreen({super.key});

  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final _nameCtrl = TextEditingController();
  final _earTagCtrl = TextEditingController();
  final _breedCtrl = TextEditingController(text: 'Brangus');
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _deviceIdCtrl = TextEditingController();

  String _sex = 'female';
  String _category = 'vaca';
  String _status = 'active';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _earTagCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _deviceIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('El nombre es obligatorio'), backgroundColor: AppTheme.thiDanger),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await RanchApiService.createAnimal({
        'name': _nameCtrl.text.trim(),
        'ear_tag': _earTagCtrl.text.trim(),
        'breed': _breedCtrl.text.trim(),
        'sex': _sex,
        'category': _category,
        'status': _status,
        'weight_kg': double.tryParse(_weightCtrl.text) ?? 0,
        'notes': _notesCtrl.text.trim(),
        'device_id': _deviceIdCtrl.text.trim().isEmpty ? null : _deviceIdCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Animal registrado exitosamente'), backgroundColor: AppTheme.primary),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.thiDanger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _nameCtrl.clear();
    _earTagCtrl.clear();
    _breedCtrl.text = 'Brangus';
    _weightCtrl.clear();
    _notesCtrl.clear();
    _deviceIdCtrl.clear();
    setState(() { _sex = 'female'; _category = 'vaca'; _status = 'active'; });
  }

  Future<void> _scanNfc() async {
    final scannedId = await showDialog<String>(
      context: context,
      builder: (_) => const NfcScannerDialog(),
    );
    if (scannedId != null && mounted) {
      setState(() => _deviceIdCtrl.text = scannedId);
    }
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 18) : null,
    filled: true,
    fillColor: AppTheme.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(text, style: TextStyle(
        color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Registrar Nuevo Animal', style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Llena los datos para dar de alta un animal en el sistema.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),

              // IDENTIFICACIÓN
              _sectionTitle('IDENTIFICACIÓN'),
              TextField(controller: _nameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Nombre *', icon: Icons.pets)),
              const SizedBox(height: 12),
              TextField(controller: _earTagCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Arete SINIIGA', icon: Icons.tag)),
              const SizedBox(height: 12),
              TextField(controller: _breedCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Raza', icon: Icons.category)),

              // CLASIFICACIÓN
              _sectionTitle('CLASIFICACIÓN'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sex,
                      dropdownColor: AppTheme.card,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Sexo'),
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('Hembra')),
                        DropdownMenuItem(value: 'male', child: Text('Macho')),
                      ],
                      onChanged: (v) => setState(() => _sex = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      dropdownColor: AppTheme.card,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Categoría'),
                      items: const [
                        DropdownMenuItem(value: 'vaca', child: Text('Vaca')),
                        DropdownMenuItem(value: 'toro', child: Text('Toro')),
                        DropdownMenuItem(value: 'becerro', child: Text('Becerro')),
                        DropdownMenuItem(value: 'novilla', child: Text('Novilla')),
                      ],
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                ],
              ),

              // DATOS
              _sectionTitle('DATOS'),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: _inputDeco('Peso (kg)', icon: Icons.monitor_weight)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      dropdownColor: AppTheme.card,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco('Estado'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Activo')),
                        DropdownMenuItem(value: 'sick', child: Text('Enfermo')),
                        DropdownMenuItem(value: 'pregnant', child: Text('Gestante')),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, maxLines: 3,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Notas')),

              // COLLAR INTELIGENTE
              _sectionTitle('COLLAR INTELIGENTE (IoT)'),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _deviceIdCtrl,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: _inputDeco('ID del Collar', icon: Icons.nfc)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _scanNfc,
                    icon: const Icon(Icons.wifi_tethering, size: 16),
                    label: const Text('Escanear NFC'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary.withAlpha(20),
                      foregroundColor: AppTheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(_loading ? 'Registrando...' : 'Registrar Animal',
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
}

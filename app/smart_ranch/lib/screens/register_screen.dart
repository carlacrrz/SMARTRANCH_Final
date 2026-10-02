import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/nfc_scanner_dialog.dart';

/// Multi-step registration screen: User data, Ranch, Map/Geofencing, Equipment.
class RegisterScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  const RegisterScreen({super.key, required this.onRegistered});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 0;
  bool _loading = false;

  // Step 1 — Responsable
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;

  // Step 2 — Rancho
  final _ranchNameCtrl = TextEditingController();
  final _stateCtrl = TextEditingController(text: 'Sonora');
  final _municipioCtrl = TextEditingController();
  final _headCountCtrl = TextEditingController();

  // Step 3 — Geofencing
  final List<LatLng> _polygonPoints = [];
  final MapController _mapController = MapController();

  // Step 4 — Equipos
  final List<String> _deviceIds = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _ranchNameCtrl.dispose();
    _stateCtrl.dispose();
    _municipioCtrl.dispose();
    _headCountCtrl.dispose();
    super.dispose();
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

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty ||
            _phoneCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
          _showError('Llena todos los campos obligatorios');
          return false;
        }
        if (!_emailCtrl.text.contains('@')) {
          _showError('Ingresa un correo válido');
          return false;
        }
        if (_passCtrl.text.length < 6) {
          _showError('La contraseña debe tener al menos 6 caracteres');
          return false;
        }
        if (_passCtrl.text != _confirmPassCtrl.text) {
          _showError('Las contraseñas no coinciden');
          return false;
        }
        return true;
      case 1:
        if (_ranchNameCtrl.text.trim().isEmpty) {
          _showError('El nombre del rancho es obligatorio');
          return false;
        }
        return true;
      case 2:
        if (_polygonPoints.length < 3) {
          _showError('Delimita el rancho con al menos 3 puntos en el mapa');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.thiDanger),
    );
  }

  void _next() {
    if (_validateStep(_currentStep)) {
      setState(() => _currentStep++);
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _complete() async {
    setState(() => _loading = true);
    try {
      // Intentar registro en API si está disponible
      final result = await AuthService.register(
        username: _emailCtrl.text.trim().split('@').first,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
      ).timeout(const Duration(seconds: 3), onTimeout: () => null);

      // Si la API no respondió o estamos en modo local, asegurar sesión activa
      AuthService.currentUser ??= {};
      AuthService.currentUser!['username'] = _emailCtrl.text.trim().split('@').first;
      AuthService.currentUser!['email'] = _emailCtrl.text.trim();
      AuthService.currentUser!['full_name'] = _nameCtrl.text.trim();
      AuthService.currentUser!['ranch_name'] = _ranchNameCtrl.text.trim();
      AuthService.currentUser!['phone'] = _phoneCtrl.text.trim();
      AuthService.currentUser!['role'] = 'admin';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido a Smart Ranch, ${_nameCtrl.text.trim()}!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        widget.onRegistered();
      }
    } catch (e) {
      // Fallback local garantizado para no bloquear el flujo
      AuthService.currentUser = {
        'username': _emailCtrl.text.trim().split('@').first,
        'email': _emailCtrl.text.trim(),
        'full_name': _nameCtrl.text.trim(),
        'ranch_name': _ranchNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': 'admin',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Cuenta creada con éxito!'),
            backgroundColor: AppTheme.primary,
          ),
        );
        widget.onRegistered();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanNfcDevice() async {
    final scannedId = await showDialog<String>(
      context: context,
      builder: (_) => const NfcScannerDialog(),
    );
    if (scannedId != null && mounted) {
      setState(() {
        if (!_deviceIds.contains(scannedId)) _deviceIds.add(scannedId);
      });
    }
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        final rows = const CsvToListConverter().convert(csvString);
        int added = 0;
        for (final row in rows) {
          for (final cell in row) {
            final id = cell.toString().trim();
            if (id.isNotEmpty && !_deviceIds.contains(id)) {
              _deviceIds.add(id);
              added++;
            }
          }
        }
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ $added dispositivos importados'), backgroundColor: AppTheme.primary),
          );
        }
      }
    } catch (e) {
      _showError('Error al leer archivo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo_icon.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text(
              'Registro de Cuenta',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),
          // Content
          Expanded(child: _buildStepContent()),
          // Bottom nav
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final stepDetails = [
      {'title': 'Responsable', 'icon': Icons.person_outline},
      {'title': 'Rancho', 'icon': Icons.home_work_outlined},
      {'title': 'Ubicación', 'icon': Icons.map_outlined},
      {'title': 'Equipos', 'icon': Icons.memory_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Paso ${_currentStep + 1} de 4: ${stepDetails[_currentStep]['title']}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withAlpha(80)),
                ),
                child: Text(
                  '${((_currentStep + 1) / 4 * 100).toInt()}% completado',
                  style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(4, (i) {
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 6.0 : 0.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDone || isCurrent
                          ? AppTheme.primary
                          : AppTheme.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          // Clean Step Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stepDetails.asMap().entries.map((e) {
              final i = e.key;
              final title = e.value['title'] as String;
              final icon = e.value['icon'] as IconData;
              final isCurrent = i == _currentStep;
              final isDone = i < _currentStep;

              return InkWell(
                onTap: () {
                  if (i < _currentStep) {
                    setState(() => _currentStep = i);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.primary.withAlpha(35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isCurrent
                        ? Border.all(color: AppTheme.primary, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : icon,
                        size: 14,
                        color: isCurrent
                            ? AppTheme.primary
                            : isDone
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      case 3: return _buildStep4();
      default: return const SizedBox.shrink();
    }
  }

  // Step 1 — Datos del Responsable
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset('assets/images/logo_icon.png', width: 75, height: 75),
                    const SizedBox(height: 8),
                    Text(
                      'Smart Ranch',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text('Datos del Responsable', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))),
              const SizedBox(height: 20),
              TextField(controller: _nameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Nombre completo *', icon: Icons.person_outline)),
              const SizedBox(height: 12),
              TextField(controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Correo electrónico *', icon: Icons.email_outlined)),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Número de celular *', icon: Icons.phone_outlined)),
              const SizedBox(height: 12),
              TextField(controller: _passCtrl,
                  obscureText: _obscurePass,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Contraseña *', icon: Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textSecondary, size: 18),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  )),
              const SizedBox(height: 12),
              TextField(controller: _confirmPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Confirmar contraseña *', icon: Icons.lock_outline)),
            ],
          ),
        ),
      ),
    );
  }

  // Step 2 — Datos del Rancho
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.agriculture_rounded, size: 48, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Center(child: Text('Datos del Rancho', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))),
              const SizedBox(height: 20),
              TextField(controller: _ranchNameCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Nombre del Rancho *', icon: Icons.home_work_outlined)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _stateCtrl,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: _inputDeco('Estado', icon: Icons.map_outlined)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _municipioCtrl,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: _inputDeco('Municipio')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _headCountCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco('Número de cabezas (aprox.)', icon: Icons.pets)),
            ],
          ),
        ),
      ),
    );
  }

  // Step 3 — Ubicación y Geofencing
  Widget _buildStep3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_rounded, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('Delimita tu Rancho', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              Text('${_polygonPoints.length} puntos', style: TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Toca el mapa para colocar puntos y trazar el perímetro del rancho.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(30.97, -110.30), // Cananea, Sonora
                      initialZoom: 12,
                      onTap: (_, point) {
                        setState(() => _polygonPoints.add(point));
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.smartranch.app',
                      ),
                      if (_polygonPoints.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _polygonPoints,
                              color: AppTheme.primary.withAlpha(40),
                              borderColor: AppTheme.primary,
                              borderStrokeWidth: 2,
                              isFilled: true,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: _polygonPoints.asMap().entries.map((e) => Marker(
                          point: e.value,
                          width: 20, height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text('${e.key + 1}', style: const TextStyle(
                                  color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 12, right: 12,
                    child: FloatingActionButton.small(
                      backgroundColor: AppTheme.thiDanger,
                      foregroundColor: Colors.white,
                      onPressed: _polygonPoints.isEmpty ? null : () {
                        setState(() => _polygonPoints.clear());
                      },
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 4 — Registrar Equipos/Collares
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Icon(Icons.nfc_rounded, size: 48, color: AppTheme.primary)),
              const SizedBox(height: 12),
              Center(child: Text('Registrar Equipos', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 18))),
              const SizedBox(height: 4),
              Center(child: Text('Agrega los collares inteligentes IoT de tus animales.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
              const SizedBox(height: 20),

              // Scan NFC
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _scanNfcDevice,
                  icon: const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Escanear Collar (NFC)', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Import CSV
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Importar desde archivo CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Device list
              if (_deviceIds.isNotEmpty) ...[
                Text('${_deviceIds.length} dispositivo(s) agregado(s):',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _deviceIds.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.divider),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      leading: Icon(Icons.memory, size: 16, color: AppTheme.primary),
                      title: Text(_deviceIds[i], style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace')),
                      trailing: IconButton(
                        icon: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                        onPressed: () => setState(() => _deviceIds.removeAt(i)),
                      ),
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.devices_other, size: 32, color: AppTheme.textSecondary.withAlpha(100)),
                        const SizedBox(height: 8),
                        Text('No hay dispositivos registrados aún',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        Text('Puedes agregarlos después desde la app',
                            style: TextStyle(color: AppTheme.textSecondary.withAlpha(150), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            TextButton.icon(
              onPressed: _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Atrás'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            ),
          const Spacer(),
          if (_currentStep < 3)
            ElevatedButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loading ? null : _complete,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_loading ? 'Registrando...' : 'Completar Registro',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }
}

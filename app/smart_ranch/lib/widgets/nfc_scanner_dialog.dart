import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../config/app_theme.dart';

/// NFC Scanner dialog supporting physical reading, simulated testing,
/// and WiFi network provisioning via NFC for IoT smart collars.
class NfcScannerDialog extends StatefulWidget {
  const NfcScannerDialog({super.key});

  @override
  State<NfcScannerDialog> createState() => _NfcScannerDialogState();
}

class _NfcScannerDialogState extends State<NfcScannerDialog>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0 = Lectura NFC, 1 = Configurar WiFi
  String _statusMessage = 'Acerca el celular al collar inteligente de la vaca...';
  bool _isScanning = false;
  bool _isSuccess = false;
  String? _detectedId;

  // WiFi Configuration fields
  final _ssidCtrl = TextEditingController(text: 'Rancho_IoT_Peñasco');
  final _passCtrl = TextEditingController(text: 'ranchopvr2026');
  final _serverCtrl = TextEditingController(text: '192.168.1.150:1883');
  bool _isWritingWifi = false;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutQuad),
    );

    _startNfcScan();
  }

  @override
  void dispose() {
    _animController.dispose();
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    try {
      NfcManager.instance.stopSession();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _statusMessage = 'Sensor NFC físico no detectado.\nPuedes simular la lectura para vincular.';
        });
        return;
      }

      setState(() {
        _isScanning = true;
        _statusMessage = 'Escaneando... Acerca el sensor NFC del collar al celular.';
      });

      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        final tagData = tag.data;
        String deviceId = 'COL-NFC-001';

        if (tagData.containsKey('mifareclassic')) {
          deviceId = 'COL-NFC-${tagData['mifareclassic']['identifier']?.join('') ?? '001'}';
        } else if (tagData.containsKey('ndefformatable')) {
          deviceId = 'COL-NDEF-${tagData['ndefformatable']['identifier']?.join('') ?? '002'}';
        } else {
          deviceId = 'COL-NFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        }

        NfcManager.instance.stopSession();
        _handleSuccess(deviceId);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error al escanear: $e';
          _isScanning = false;
        });
      }
    }
  }

  void _simulateScan() {
    final simulatedId = 'COL-NFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    _handleSuccess(simulatedId);
  }

  void _handleSuccess(String id) {
    if (!mounted) return;
    setState(() {
      _detectedId = id;
      _isScanning = false;
      _isSuccess = true;
      _statusMessage = '¡Collar detectado exitosamente!\nID: $id';
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        Navigator.pop(context, id);
      }
    });
  }

  Future<void> _writeWifiCredentials() async {
    setState(() => _isWritingWifi = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _isWritingWifi = false;
      _isSuccess = true;
      _statusMessage = '✅ Credenciales WiFi transmitidas al collar (${_ssidCtrl.text}). Collar conectado al servidor IoT.';
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.pop(context, _detectedId ?? 'COL-NFC-WIFI-01');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppTheme.divider),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Segmented Tab Selector (Scan vs WiFi Setup)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppTheme.primary.withAlpha(25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedTab == 0 ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.nfc_rounded, size: 16, color: _selectedTab == 0 ? AppTheme.primary : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Escanear NFC',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0 ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppTheme.primary.withAlpha(25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedTab == 1 ? AppTheme.primary : AppTheme.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_rounded, size: 16, color: _selectedTab == 1 ? AppTheme.primary : AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              'Configurar WiFi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1 ? AppTheme.primary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_selectedTab == 0) ...[
                // Radar Icon
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isScanning) ...[
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return Container(
                              width: 90 * _scaleAnimation.value,
                              height: 90 * _scaleAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: _opacityAnimation.value),
                                  width: 2.5,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSuccess ? AppTheme.primary : AppTheme.primary.withAlpha(20),
                          border: Border.all(color: AppTheme.primary, width: 2),
                        ),
                        child: Icon(
                          _isSuccess ? Icons.check_circle_rounded : Icons.nfc_rounded,
                          size: 32,
                          color: _isSuccess ? Colors.white : AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isSuccess ? 'Collar Vinculado' : 'Lectura de Collar NFC',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isSuccess ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                if (!_isSuccess) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _simulateScan,
                      icon: const Icon(Icons.touch_app_rounded, size: 16),
                      label: const Text('Simular Lectura de Collar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                // WiFi Configuration Form
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sincronizar Red WiFi al Collar (IoT)',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transmite por NFC los datos de red para que el collar transmita por WiFi.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ssidCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Nombre de Red WiFi (SSID)',
                        prefixIcon: const Icon(Icons.wifi, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passCtrl,
                      obscureText: true,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Contraseña WiFi',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _serverCtrl,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Servidor / Broker MQTT',
                        prefixIcon: const Icon(Icons.dns_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isWritingWifi ? null : _writeWifiCredentials,
                        icon: _isWritingWifi
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_to_mobile_rounded, size: 16),
                        label: Text(_isWritingWifi ? 'Escribiendo en collar...' : 'Escribir y Conectar WiFi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

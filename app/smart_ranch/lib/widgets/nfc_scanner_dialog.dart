import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../config/app_theme.dart';

class NfcScannerDialog extends StatefulWidget {
  const NfcScannerDialog({super.key});

  @override
  State<NfcScannerDialog> createState() => _NfcScannerDialogState();
}

class _NfcScannerDialogState extends State<NfcScannerDialog>
    with SingleTickerProviderStateMixin {
  String _statusMessage = 'Acerca la parte superior del celular al collar inteligente de la vaca...';
  bool _isScanning = false;
  bool _isSuccess = false;

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
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = 'Sensor NFC físico no disponible en este entorno.\nPuedes simular la lectura para continuar.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Escaneando... Acerca el sensor NFC del collar al celular.';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        final tagData = tag.data;
        String deviceId = 'NFC_UNKNOWN';

        if (tagData.containsKey('mifareclassic')) {
          deviceId = 'NFC-MIFARE-${tagData['mifareclassic']['identifier']?.join('') ?? '001'}';
        } else if (tagData.containsKey('ndefformatable')) {
          deviceId = 'NFC-NDEF-${tagData['ndefformatable']['identifier']?.join('') ?? '002'}';
        } else {
          deviceId = 'NFC-TAG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Radar / Wave Icon
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isScanning) ...[
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          width: 100 * _scaleAnimation.value,
                          height: 100 * _scaleAnimation.value,
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
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Container(
                          width: 70 * _scaleAnimation.value,
                          height: 70 * _scaleAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primary.withValues(
                              alpha: (_opacityAnimation.value * 0.25).clamp(0.0, 1.0),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  // Center Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSuccess
                          ? AppTheme.primary
                          : const Color(0xFFF0FDF4),
                      border: Border.all(
                        color: AppTheme.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(40),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isSuccess ? Icons.check_circle_rounded : Icons.nfc_rounded,
                      size: 38,
                      color: _isSuccess ? Colors.white : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Text(
              _isSuccess ? 'Collar Vinculado' : 'Escaneando Collar NFC',
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? AppTheme.primary : const Color(0xFF4B5563),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Simulation button (for simulator & quick field testing)
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
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
              ),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

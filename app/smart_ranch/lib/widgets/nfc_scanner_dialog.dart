import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../config/app_theme.dart';

class NfcScannerDialog extends StatefulWidget {
  const NfcScannerDialog({Key? key}) : super(key: key);

  @override
  State<NfcScannerDialog> createState() => _NfcScannerDialogState();
}

class _NfcScannerDialogState extends State<NfcScannerDialog> {
  String _statusMessage = 'Acerca el celular al collar inteligente de la vaca...';
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startNfcScan();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _startNfcScan() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'NFC no está disponible en este dispositivo.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Escaneando... Acerca el celular al collar.';
    });

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        // En un caso real, leeríamos NDEF o el UID de la etiqueta.
        // Aquí tomamos un identificador base de la etiqueta leída.
        final tagData = tag.data;
        String deviceId = 'NFC_UNKNOWN';
        
        if (tagData.containsKey('mifareclassic')) {
          deviceId = 'NFC_MIFARE_${tagData['mifareclassic']['identifier'].join('')}';
        } else if (tagData.containsKey('ndefformatable')) {
          deviceId = 'NFC_NDEF_${tagData['ndefformatable']['identifier'].join('')}';
        } else {
          // Fallback reading identifier if exists
          deviceId = 'NFC_TAG_${tag.hashCode}';
        }

        NfcManager.instance.stopSession();
        if (mounted) {
          Navigator.pop(context, deviceId);
        }
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 64, color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Enlazar Collar NFC',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (_isScanning)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surface,
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text('Cancelar'),
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Configuration de synchro échangée par QR code entre deux téléphones.
class ConfigSync {
  final String url;
  final String token;
  const ConfigSync(this.url, this.token);

  String encoder() => jsonEncode({'app': 'frigo-malin', 'url': url, 'token': token});

  /// Null si le texte n'est pas une configuration Frigo Malin valide (HTTPS obligatoire).
  static ConfigSync? decoder(String? texte) {
    if (texte == null) return null;
    try {
      final j = jsonDecode(texte);
      if (j is! Map || j['app'] != 'frigo-malin') return null;
      final url = j['url'];
      final token = j['token'];
      if (url is! String || token is! String || token.isEmpty) return null;
      final u = Uri.tryParse(url);
      if (u == null || u.scheme != 'https' || u.host.isEmpty) return null;
      return ConfigSync(url, token);
    } catch (_) {
      return null;
    }
  }
}

/// Affiche le QR code à faire scanner par l'autre téléphone.
class EcranPartageConfig extends StatelessWidget {
  final String url;
  final String token;
  const EcranPartageConfig({super.key, required this.url, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partager la synchro')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sur l\'autre téléphone : Réglages → Scanner un QR.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: ConfigSync(url, token).encoder(),
                  size: 280,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ce code contient ton jeton secret : ne le montre qu\'à la personne avec qui tu partages le frigo, et n\'en fais pas de capture d\'écran.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scanne le QR code de configuration affiché par un autre téléphone.
class EcranScanConfig extends StatefulWidget {
  const EcranScanConfig({super.key});

  @override
  State<EcranScanConfig> createState() => _EcranScanConfigState();
}

class _EcranScanConfigState extends State<EcranScanConfig> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _fini = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _surDetection(BarcodeCapture capture) {
    if (_fini) return;
    for (final b in capture.barcodes) {
      final config = ConfigSync.decoder(b.rawValue);
      if (config != null) {
        _fini = true;
        Navigator.pop(context, config);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner la configuration')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _surDetection,
            errorBuilder: (_, _) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'La caméra n\'est pas disponible. Autorise-la dans les réglages de l\'appli, ou saisis l\'URL et le jeton à la main.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Vise le QR code affiché sur l\'autre téléphone',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

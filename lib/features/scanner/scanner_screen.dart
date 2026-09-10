/// ─── Escáner de códigos de barras (§9.4/§12.2 · mobile_scanner) ────────────
/// Escaneo continuo con linterna y fallback manual (el web escanea en
/// Productos y Lista). Devuelve el código por Navigator.pop(context, código).
/// Debounce de 800 ms anti-doble-lectura del mismo fotograma.
library;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  /// Abre el escáner y devuelve el código leído (null si se cerró sin leer).
  /// El valor especial `__manual__` = el usuario eligió escribirlo a mano.
  static Future<String?> scan(BuildContext context) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
  }

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.code128],
  );
  bool _torch = false;
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      // Debounce: mismo código → ignora 800 ms; código nuevo → pasa al 1º.
      final now = DateTime.now();
      if (code == _lastCode && now.difference(_lastHit).inMilliseconds < 800) {
        return;
      }
      _lastCode = code;
      _lastHit = now;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código'),
        actions: [
          IconButton(
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Linterna',
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        // Ventana de apuntado (marco redondeado, no bloquea gestos).
        const IgnorePointer(
          child: Center(
            child: SizedBox(
              width: 260,
              height: 150,
              child: _AimFrame(),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                  'Apunta al código de barras del producto',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('__manual__'),
                  child: const Text('Escribir el código a mano',
                      style: TextStyle(color: Colors.white)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Marco de apuntado pintado a mano (esquinas redondeadas con esquinas
/// marcadas, estilo visor de escáner).
class _AimFrame extends StatelessWidget {
  const _AimFrame();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return CustomPaint(painter: _AimPainter(primary));
  }
}

class _AimPainter extends CustomPainter {
  const _AimPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const r = 18.0;
    const corner = 26.0;
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width - r, 0)
      ..quadraticBezierTo(size.width, 0, size.width, r)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, size.height - corner);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AimPainter old) => old.color != color;
}

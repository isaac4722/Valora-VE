/// ─── Escáner ROI (solo procesa el recuadro central) ─────────────────────────
/// Variante de la pantalla de escáner con `scanWindow`: MobileScanner 5.x
/// procesa ÚNICAMENTE el rectángulo apuntado (no todo el fotograma), así el
/// código vecino del estante no entra por accidente.
///
/// · Recuadro: 72 % del ancho × 32 % del alto, centrado — mismo Rect que se
///   pasa a scanWindow y que se dibuja (una sola verdad geométrica).
/// · Máscara oscura α .55 alrededor (Stack con 4 fondos) + marco redondeado
///   pintado con CustomPaint (mismo visor que ScannerScreen).
/// · Sin pinch-zoom: el ROI es fijo en pantalla; con zoom el rect dejaria de
///   coincidir con lo que el usuario ve (decisión documentada).
/// · Misma devolución de contrato que ScannerScreen.scan: código leído, null
///   al cerrar, y `__manual__` si el usuario prefiere escribirlo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class RoiScannerScreen extends StatefulWidget {
  const RoiScannerScreen({super.key});

  /// Abre el escáner ROI y devuelve el código leído (null si se cerró).
  /// El valor especial `__manual__` = el usuario eligió escribirlo a mano.
  static Future<String?> scan(BuildContext context) async {
    return Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RoiScannerScreen()));
  }

  @override
  State<RoiScannerScreen> createState() => _RoiScannerScreenState();
}

class _RoiScannerScreenState extends State<RoiScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
    ],
  );
  bool _torch = false;
  bool _done = false; // evita doble pop por fotogramas consecutivos
  DateTime _lastHit = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
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
      _done = true;
      // Feedback de lectura: vibración + sonido del sistema (como ScannerScreen).
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.alert);
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
      body: LayoutBuilder(
        builder: (context, box) {
          // Una sola verdad geométrica: el Rect del scanWindow es el mismo que
          // se enmascara y dibuja (centrado, 72 % ancho × 32 % alto).
          final size = box.biggest;
          final window = Rect.fromCenter(
            center: size.center(Offset.zero),
            width: size.width * 0.72,
            height: size.height * 0.32,
          );
          return Stack(
            children: [
              // Cámara con scanWindow: SOLO el recuadro se procesa (5.x).
              Positioned.fill(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  scanWindow: window,
                ),
              ),
              // Máscara oscura alrededor del recuadro (4 fondos α .55).
              _Mask(top: 0, left: 0, right: 0, height: window.top),
              _Mask(
                top: window.bottom,
                left: 0,
                right: 0,
                height: size.height - window.bottom,
              ),
              _Mask(
                top: window.top,
                left: 0,
                width: window.left,
                height: window.height,
              ),
              _Mask(
                top: window.top,
                left: window.right,
                width: size.width - window.right,
                height: window.height,
              ),
              // Marco redondeado del visor (no bloquea gestos).
              Positioned.fromRect(
                rect: window,
                child: const IgnorePointer(child: _AimFrame()),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Apunta al código de barras — solo se lee el recuadro',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop('__manual__'),
                          child: const Text(
                            'Escribir el código a mano',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Fondo oscuro α .55 para una de las 4 bandas de la máscara.
class _Mask extends StatelessWidget {
  const _Mask({this.top, this.left, this.width, this.height, this.right});

  final double? top, left, width, height, right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      width: width,
      height: height,
      child: const ColoredBox(color: Color(0x8C000000)), // negro 55 %
    );
  }
}

/// Marco de apuntado pintado a mano (mismo estilo del visor firma).
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
    const r = 14.0;
    const corner = 24.0;
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

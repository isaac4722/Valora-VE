/// ─── Escáner de códigos de barras (§9.4/§12.2 · mobile_scanner) ────────────
/// v17.6 (RECHECK R2-4): paridad total con RoiScannerScreen —
/// · `scanWindow`: SOLO el recuadro central (72 % × 32 %) se procesa, no
///   todo el fotograma; el Rect es la MISMA verdad geométrica que se
///   enmascara y dibuja (sin pinch-zoom: con zoom el rect dejaría de
///   coincidir con lo que el usuario ve — decisión documentada en roi_scanner).
/// · `errorBuilder`: permiso denegado / cámara ocupada muestra ESTADO con
///   salidas (abrir ajustes · escribir a mano) — nunca la pantalla negra
///   muda que el dueño capturó.
/// Linterna + fallback manual + HapticFeedback + debounce 800 ms
/// anti-doble-lectura del mismo fotograma.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _done = false; // evita doble pop por fotogramas consecutivos (como ROI)
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
      // Feedback de lectura: vibración + sonido del sistema.
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
      body: LayoutBuilder(builder: (context, box) {
        // Una sola verdad geométrica (misma que RoiScanner): el Rect que se
        // pasa a scanWindow es el que se enmascara y dibuja. Sin pinch-zoom:
        // con zoom el rect dejaría de coincidir con lo que el usuario ve.
        final size = box.biggest;
        final window = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * 0.72,
          height: size.height * 0.32,
        );
        return Stack(children: [
          // Cámara con scanWindow: SOLO el recuadro se procesa (5.x).
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              scanWindow: window,
              // FIX pantalla negra (v17.6): permiso denegado / cámara
              // ocupada muestra estado con SALIDAS — nunca negro mudo.
              errorBuilder: (ctx, error) {
                final permiso =
                    error.errorCode == MobileScannerErrorCode.permissionDenied;
                return _DarkState(
                  title: permiso
                      ? 'Falta el permiso de cámara'
                      : 'La cámara no está disponible',
                  hint: permiso
                      ? 'ValoraVE usa la cámara SOLO para leer códigos. '
                          'Actívalo en Ajustes del sistema y vuelve a '
                          'intentar — o escribe el código a mano.'
                      : 'Otra app puede estar usando la cámara, o el '
                          'hardware no respondió. Reintenta, abre los '
                          'ajustes o escribe el código a mano.',
                );
              },
            ),
          ),
          // Máscara oscura alrededor del recuadro (4 bandas α .55).
          _Mask(top: 0, left: 0, right: 0, height: window.top),
          _Mask(
              top: window.bottom,
              left: 0,
              right: 0,
              height: size.height - window.bottom),
          _Mask(
              top: window.top,
              left: 0,
              width: window.left,
              height: window.height),
          _Mask(
              top: window.top,
              left: window.right,
              width: size.width - window.right,
              height: window.height),
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                    'Apunta al código de barras — solo se lee el recuadro',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(
                      onPressed: openAppSettings,
                      icon: const Icon(Icons.settings_outlined,
                          size: 16, color: Colors.white70),
                      label: const Text('Abrir ajustes',
                          style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop('__manual__'),
                      child: const Text('Escribir el código a mano',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Estado de error del escáner sobre fondo negro (v17.6): tile + título +
/// pista + SALIDAS (ajustes · escribir a mano). Gramática de ErrorState de
/// ui.dart adaptada al visor oscuro — sin depender del Card del tema claro.
class _DarkState extends StatelessWidget {
  const _DarkState({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.photo_camera_outlined,
              size: 24, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 6),
        Text(hint,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.white.withValues(alpha: 0.66))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings_outlined,
                size: 16, color: Colors.white70),
            label: const Text('Abrir ajustes',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop('__manual__'),
            child: const Text('Escribir a mano',
                style: TextStyle(color: Colors.white)),
          ),
        ]),
      ]),
    );
  }
}

/// Fondo oscuro α .55 para una de las 4 bandas de la máscara (paridad ROI).
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
      child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
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

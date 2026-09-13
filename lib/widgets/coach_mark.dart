/// ─── Coach-marks por feature (Ola 1 · protocolo v2 · cierra D3) ────────────
/// Puntas de contexto ancladas a un widget REAL (GlobalKey), una sola vez
/// por instalación: la clave `valorave.tips-dismissed` guarda los ids
/// descartados (StringList en SharedPreferences). Distinto del walkthrough
/// por módulo (v17.2): estos son consejos cortos «a la mano de la obra».
///
/// Semántica: se marca como visto ANTES de mostrarse (una oportunidad, no
/// un bucle); sin prefs (tests/previews) es no-op; si el ancla no está
/// montada, la punta se salta en silencio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

const String kTipsDismissedKey = 'valorave.tips-dismissed';

/// Dispara la punta tras el primer frame SOLO si el walkthrough del módulo
/// ([moduleId]) ya se vio (los recorridos v17.2 van primero — la punta nunca
/// interrumpe un recorrido). Tolerante: sin `Provider<SharedPreferences>`
/// (tests/previews) se salta en silencio.
void scheduleFeatureTip(
  BuildContext context,
  String moduleId,
  String tipId, {
  required GlobalKey anchor,
  required String title,
  required String body,
}) {
  SchedulerBinding.instance.addPostFrameCallback((_) async {
    if (!context.mounted) return;
    SharedPreferences prefs;
    try {
      prefs = context.read<SharedPreferences>();
    } on ProviderNotFoundException {
      return;
    }
    if (prefs.getBool('valorave.wt.$moduleId') != true) return;
    // Respiro: si el recorrido acaba de cerrar, la punta no se apila.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return;
    await maybeShowTip(context, prefs, tipId,
        anchor: anchor, title: title, body: body);
  });
}

/// Muestra la punta [tipId] si nunca se descartó. [anchor] es la GlobalKey
/// del widget que la punta explica (debe estar montado en el árbol).
Future<void> maybeShowTip(
  BuildContext context,
  SharedPreferences? prefs,
  String tipId, {
  required GlobalKey anchor,
  required String title,
  required String body,
}) async {
  if (prefs == null) return;
  final dismissed = prefs.getStringList(kTipsDismissedKey) ?? const <String>[];
  if (dismissed.contains(tipId)) return;
  // Marca antes de mostrar: si algo interrumpe, no vuelve a molestar.
  await prefs.setStringList(kTipsDismissedKey, [...dismissed, tipId]);
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    barrierLabel: 'Cerrar consejo',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, anim2) =>
        _CoachMarkOverlay(anchor: anchor, title: title, body: body),
    transitionBuilder: (ctx, anim, anim2, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: anim, curve: kEaseVe), child: child),
  );
}

/// Lee la lista de puntas descartadas (para «ver de nuevo» desde Ajustes si
/// algún día se pide — hoy solo lectura honesta).
List<String> dismissedTips(SharedPreferences prefs) =>
    prefs.getStringList(kTipsDismissedKey) ?? const <String>[];

class _CoachMarkOverlay extends StatefulWidget {
  const _CoachMarkOverlay({required this.anchor, required this.title, required this.body});

  final GlobalKey anchor;
  final String title;
  final String body;

  @override
  State<_CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<_CoachMarkOverlay> {
  Rect? _spot;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _locate());
  }

  void _locate() {
    final ctx = widget.anchor.currentContext;
    Rect? spot;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        spot = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    if (mounted) setState(() => _spot = spot);
    // Sin ancla montada: la punta se retira sola (no molesta a ciegas).
    if (spot == null && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final spot = _spot;

    // Burbuja: debajo del ancla si cabe; si no, encima.
    final bubbleWidth = (size.width - 48).clamp(260.0, 340.0);
    final bubbleHeight = 150.0; // estimado; la burbuja es min-size
    double top;
    if (spot == null) {
      top = (size.height - bubbleHeight) / 2;
    } else if (spot.bottom + bubbleHeight + 24 < size.height) {
      top = spot.bottom + 12;
    } else {
      top = spot.top - bubbleHeight - 12;
    }
    final left = spot == null
        ? (size.width - bubbleWidth) / 2
        : (spot.center.dx - bubbleWidth / 2)
            .clamp(16.0, size.width - bubbleWidth - 16);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Foco: aro alrededor del widget explicado (patrón del walkthrough).
        if (spot != null)
          Positioned.fromRect(
            rect: spot.deflate(-8),
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primary, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 16),
                  ],
                ),
              ),
            ),
          ),
        // Tarjeta de la punta.
        Positioned(
          top: top < 16 ? 16 : top,
          left: left,
          child: Container(
            width: bubbleWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TIP', style: VeText.labelCaps(9.5, color: scheme.primary)),
              const SizedBox(height: 5),
              Text(widget.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(widget.body,
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Row(children: [
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

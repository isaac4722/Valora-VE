/// ─── Motor de coach marks de ValoraVE (v19.0, casa) ──────────────────────────
/// Overlay propio, SIN dependencias externas (tutorial_coach_mark se retiró:
/// dibujaba tarjetas cortadas, enfocaba rects muertos y sus overlays podían
/// quedar sin botones alcanzables → tutorial congelado).
///
/// Decisiones de diseño (lecciones de las capturas del dueño):
/// · El agujero del foco se calcula del rect REAL del ancla (RenderBox
///   vivo) EN el instante en que se muestra el overlay — nunca un rect
///   estimado ni medido antes de un scroll.
/// · La tarjeta se posiciona con CLAMPING: abajo del ancla si cabe, arriba
///   si no, y SIEMPRE dentro de la pantalla + safe area. Si el espacio es
///   menor que la tarjeta, la tarjeta SE SCROLLA (SingleChildScrollView):
///   sus botones («Saltar» / «Siguiente») son alcanzables SIEMPRE — el
///   tutorial no se puede congelar por diseño.
/// · Cero animaciones infinitas (sin pulso): batería, tests deterministas
///   y nada que "se dibuje mal" mientras anima.
/// · El overlay vive en el rootOverlay: sobrevive cambios de pestaña/rama
///   del shell; los botones completan SIEMPRE el Future (única salida).
///
/// API: [showCoachMark] devuelve un `Future<bool>` (true = continuar,
/// false = saltar).
/// El TIPS system (app_tips.dart) usa este MISMO motor — misma forma visual
/// que el tutorial, disparada por reglas y no por el onboarding.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/currencies.dart';
import 'ui.dart';

/// Datos de la tarjeta del coach mark.
class CoachCardData {
  const CoachCardData({
    required this.title,
    required this.body,
    this.segment,
    this.flags = const <Currency>[],
    this.stepLabel,
    this.cta,
  });

  /// Título corto (1 línea idealmente).
  final String title;

  /// Cuerpo del consejo: 2-4 líneas, contexto EXACTO de lo que se enfoca.
  final String body;

  /// Rótulo de sección (p. ej. «INICIO») — opcional.
  final String? segment;

  /// Banderas reales (assets/flags) que encabezan la tarjeta.
  final List<Currency> flags;

  /// «3/13» — etiqueta de posición, opcional.
  final String? stepLabel;

  /// Texto del botón principal; null → «Siguiente».
  final String? cta;
}

/// Muestra UN coach mark sobre [context]. Devuelve true si se pulsó
/// continuar y false si se saltó. El Future SIEMPRE se completa: solo los
/// botones de la tarjeta cierran el overlay.
Future<bool> showCoachMark(
  BuildContext context, {
  GlobalKey? anchor,
  required CoachCardData card,
}) async {
  // 1) Rect real del ancla AHORA (el caller ya hizo ensureVisible y esperó
  //    el frame): si el ancla no está montada, la tarjeta sale centrada.
  Rect? rect;
  final anchorCtx = anchor?.currentContext;
  if (anchorCtx != null && anchorCtx.mounted) {
    final ro = anchorCtx.findRenderObject();
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      final global = ro.localToGlobal(Offset.zero);
      rect = global & ro.size;
    }
  }

  // 2) Overlay en la RAÍZ del árbol: los cambios de ruta del shell no lo
  //    tocan y los botones siguen vivos.
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return false;

  final done = Completer<bool>();
  final entry = OverlayEntry(
    builder: (_) => _CoachOverlay(
      anchorRect: rect,
      card: card,
      onDone: (next) {
        if (!done.isCompleted) done.complete(next);
      },
    ),
  );
  overlay.insert(entry);
  final result = await done.future;
  entry.remove();
  return result;
}

/// ─── Overlay de UN paso ──────────────────────────────────────────────────────
class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({
    required this.anchorRect,
    required this.card,
    required this.onDone,
  });

  final Rect? anchorRect;
  final CoachCardData card;
  final ValueChanged<bool> onDone;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  /// Guard anti-doble-tap: el cierre es inmediato, pero un segundo tap no
  /// debe completar dos veces.
  bool _busy = false;

  void _finish(bool next) {
    if (_busy) return;
    _busy = true;
    HapticFeedback.selectionClick();
    widget.onDone(next);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final safe = media.padding;
    final scheme = Theme.of(context).colorScheme;

    // ── Geometría del foco ──
    final hole = widget.anchorRect?.inflate(10);
    final rrect = hole == null
        ? null
        : RRect.fromRectAndRadius(hole, const Radius.circular(14));

    // ── Posicionamiento de la tarjeta (con clamping, SIEMPRE visible) ──
    final maxW = (size.width - 28).clamp(0.0, 380.0);
    final topSafe = safe.top + 12;
    final bottomSafe = size.height - safe.bottom - 12;

    // ¿Cabe la tarjeta ABAJO del foco? Regla: foco en el tercio alto de la
    // pantalla → abajo; si no → arriba. Sin foco → arriba centrada.
    bool below = false;
    double top;
    if (hole == null) {
      top = topSafe + 18;
    } else {
      below = hole.center.dy < size.height * 0.55;
      top = below ? hole.bottom + 14 : topSafe;
      if (!below) {
        // La tarjeta se ancla por SU borde inferior al hueco libre superior:
        // se pinta en un Column invertido (ver abajo).
        top = topSafe;
      }
      // Si el lado elegido no tiene espacio mínimo (140 px), se cambia al
      // otro lado; si tampoco, se centra abajo (scroll interno salva).
      if (below && (bottomSafe - top) < 140) {
        below = false;
        top = topSafe;
      } else if (!below && (hole.top - 14 - topSafe) < 140) {
        below = true;
        top = hole.bottom + 14;
      }
    }
    final maxH = (below ? bottomSafe - top : (hole == null ? bottomSafe - top : hole.top - 14 - topSafe))
        .clamp(120.0, size.height);

    final card = Material(
      color: scheme.surfaceContainerHighest,
      elevation: 6,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          // Si el contenido no cabe en el espacio disponible, SE SCROLLA:
          // los botones quedan alcanzables SIEMPRE (fin de los congelados).
          padding: const EdgeInsets.all(18),
          child: _CoachCardBody(card: widget.card, onDone: _finish),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            // Barrera con agujero (pintada del rect real; sin animación).
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(rrect: rrect),
                child: const SizedBox.expand(),
              ),
            ),
            // Tarjeta: posicionada y clamped.
            Positioned(
              left: (size.width - maxW) / 2,
              top: top,
              width: maxW,
              child: below
                  ? Align(alignment: Alignment.topCenter, child: card)
                  // Caso «arriba»: el alto disponible termina en el foco.
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: hole == null
                            ? maxH
                            : (hole.top - 14 - topSafe).clamp(120.0, size.height),
                      ),
                      child: card,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo de la tarjeta (segmento · pasos · banderas · título · cuerpo ·
/// botones Saltar/Siguiente).
class _CoachCardBody extends StatelessWidget {
  const _CoachCardBody({
    required this.card,
    required this.onDone,
  });

  final CoachCardData card;
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasCta = card.cta != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(children: <Widget>[
          if (card.segment != null) ...<Widget>[
            Expanded(
              child: Text(
                card.segment!,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
          if (card.stepLabel != null)
            Text(
              card.stepLabel!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant,
              ),
            ),
        ]),
        if (card.flags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Row(children: <Widget>[
            for (final c in card.flags)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Flag(c, size: 16),
              ),
          ]),
        ],
        const SizedBox(height: 8),
        Text(card.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(card.body,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(children: <Widget>[
          TextButton(
            onPressed: () => onDone(false),
            child: const Text('Saltar'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => onDone(true),
            child: Text(hasCta ? card.cta! : 'Siguiente'),
          ),
        ]),
      ],
    );
  }
}

/// Pinta la barrera negra con el agujero RRect del foco (+ borde sutil
/// blanco para que la zona enmarcada se lea clara).
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({this.rrect});

  final RRect? rrect;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final Paint fill = Paint()..color = Colors.black.withValues(alpha: 0.80);
    if (rrect == null) {
      canvas.drawPath(full, fill);
      return;
    }
    final cut = Path()..addRRect(rrect!);
    final combined = Path.combine(PathOperation.difference, full, cut);
    canvas.drawPath(combined, fill);
    // Borde de lectura alrededor del foco (estático, 2 px).
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.65);
    canvas.drawRRect(rrect!, stroke);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.rrect != rrect;
}

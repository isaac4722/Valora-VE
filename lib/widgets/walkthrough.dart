/// ─── Walkthroughs por módulo (v17.2 «app walkthroughs») ────────────────────
/// Motor de recorridos: overlay con foco sobre el widget (GlobalKey opcional)
/// + tarjeta con título/cuerpo + Siguiente/Saltar + puntos de progreso. Cada
/// módulo tiene SU recorrido (contenido en walkthroughs_content.dart), se
/// muestra una vez por instalación (flag por módulo en SharedPreferences) y
/// es rejugable desde Ajustes → Tutorial.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

class WalkthroughStep {
  const WalkthroughStep({
    required this.title,
    required this.body,
    this.key,
  });

  final String title;
  final String body;

  /// GlobalKey del widget a destacar (opcional: sin él la tarjeta va centrada).
  final GlobalKey? key;
}

class Walkthrough {
  const Walkthrough(this.moduleId, this.title, this.steps);
  final String moduleId;
  final String title;
  final List<WalkthroughStep> steps;
}

/// Muestra el recorrido si no se vio nunca. [prefs] nulo = no-op (tests).
Future<void> maybeRunWalkthrough(
  BuildContext context,
  SharedPreferences? prefs,
  String moduleId,
  String title,
  List<WalkthroughStep> steps,
) async {
  if (prefs == null || steps.isEmpty) return;
  if (prefs.getBool('valorave.wt.$moduleId') == true) return;
  await prefs.setBool('valorave.wt.$moduleId', true);
  if (!context.mounted) return;
  await runWalkthrough(context, title, steps);
}

/// Ejecuta el recorrido (usado por el auto-run y por «Ver recorrido»).
Future<void> runWalkthrough(
  BuildContext context,
  String title,
  List<WalkthroughStep> steps,
) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, anim2) => _WalkthroughOverlay(title: title, steps: steps),
    transitionBuilder: (ctx, anim, anim2, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: anim, curve: kEaseVe), child: child),
  );
}

class _WalkthroughOverlay extends StatefulWidget {
  const _WalkthroughOverlay({required this.title, required this.steps});
  final String title;
  final List<WalkthroughStep> steps;

  @override
  State<_WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<_WalkthroughOverlay> {
  int _i = 0;
  Rect? _spot;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _locate());
  }

  void _locate() {
    final key = widget.steps[_i].key;
    Rect? spot;
    final ctx = key?.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.attached && box.hasSize) {
        spot = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    if (mounted) setState(() => _spot = spot);
  }

  void _next() {
    if (_i < widget.steps.length - 1) {
      setState(() => _i++);
      SchedulerBinding.instance.addPostFrameCallback((_) => _locate());
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = widget.steps[_i];
    final size = MediaQuery.of(context).size;
    final last = _i == widget.steps.length - 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Foco: recorte visual alrededor del widget destacado.
        if (_spot != null)
          Positioned.fromRect(
            rect: _spot!.deflate(-8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary, width: 2.5),
                boxShadow: [
                  BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 18),
                ],
              ),
            ),
          ),
        // Tarjeta del paso.
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              constraints: BoxConstraints(maxWidth: size.width - 32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(widget.title.toUpperCase(),
                        style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: scheme.primary)),
                  ),
                  for (int i = 0; i < widget.steps.length; i++)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _i
                            ? scheme.primary
                            : scheme.outlineVariant,
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(step.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(step.body,
                    style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                Row(children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Saltar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(last ? 'Entendido' : 'Siguiente'),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

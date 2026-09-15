/// ─── Tour guiado completo (v19.0 · motor PROPIO, sin paquetes) ─────────────
/// Reescritura total del walkthrough (orden del dueño: «todavía están mal,
/// reescribe los WALKTHROUGH»). Fuera `tutorial_coach_mark` — el motor es de
/// la casa y no tiene sorpresas de terceros:
///
/// · UN overlay POR PASO, insertado en el Overlay raíz: cortina negra con el
///   RECORTE REAL del ancla (CustomPainter + Path.difference — el agujero es
///   el rect medido del widget, nunca una estimación).
/// · Antes de cada tarjeta el motor arrastra el ancla a la zona visible
///   (`Scrollable.ensureVisible` 400 ms) y espera 450 ms: el recorte nunca
///   mide un rect que el usuario no está viendo.
/// · La tarjeta se posiciona con el rect real: debajo del ancla si hay más
///   sitio, arriba si el ancla está baja — y respeta la safe-area. En rotación
///   el overlay se re-mide (depende de MediaQuery).
/// · «Siguiente»/«Saltar» completan UN Completer por paso: el doble toque no
///   puede avanzar dos veces por construcción (sin guards frágiles).
/// · Ancla no montada (pe. rama del shell sin visitar) → el paso se salta.
///
/// El tour cruza pestañas solo (go_router) y «Saltar» devuelve al usuario a
/// donde estaba. Semántica: UNA oportunidad automática por instalación (flag
/// `valorave.tour-done`, se marca ANTES de mostrar) y replay libre desde
/// Ajustes → Tutorial.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/currencies.dart';
import 'app_router.dart' show kNavBarKey, kHeaderActionsKey;
import 'ui.dart';

/// Clave de la preferencia «ya vi el tour completo».
const String kTourDoneKey = 'valorave.tour-done';

/// ─── Registro central de anclas ─────────────────────────────────────────────
/// Las pantallas attachean estas claves; el tour las enfoca. Una clave = un
/// widget en toda la app (los branches del shell viven tras primer visit).
abstract final class TourKeys {
  // Inicio
  static final GlobalKey cotizacion = GlobalKey(debugLabel: 'tour-cotizacion');
  static final GlobalKey divisasFoco = GlobalKey(debugLabel: 'tour-divisas-foco');
  // Divisas
  static final GlobalKey convFecha = GlobalKey(debugLabel: 'tour-conv-fecha');
  static final GlobalKey convFuente = GlobalKey(debugLabel: 'tour-conv-fuente');
  // Lista
  static final GlobalKey listaAgregar = GlobalKey(debugLabel: 'tour-lista-agregar');
  static final GlobalKey listaSala = GlobalKey(debugLabel: 'tour-lista-sala');
  // Productos
  static final GlobalKey prodBusqueda = GlobalKey(debugLabel: 'tour-prod-busqueda');
  // Análisis
  static final GlobalKey anclas = GlobalKey(debugLabel: 'tour-analisis-anclas');
  static final GlobalKey rango = GlobalKey(debugLabel: 'tour-analisis-rango');
  // Ajustes
  static final GlobalKey conexion = GlobalKey(debugLabel: 'tour-ajustes-conexion');
  static final GlobalKey tutorial = GlobalKey(debugLabel: 'tour-ajustes-tutorial');
}

/// ─── Modelo del tour ────────────────────────────────────────────────────────
class TourStep {
  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.anchor,
    this.flags = const <Currency>[],
  });

  /// Identificador único (tests de integridad).
  final String id;
  final String title;
  final String body;

  /// Ancla del paso (rect real que la cortina recorta).
  final GlobalKey? anchor;

  /// Banderas REALES (assets/flags) que encabezan la tarjeta.
  final List<Currency> flags;
}

class TourSegment {
  const TourSegment({
    required this.location,
    required this.title,
    required this.steps,
  });

  /// Ruta go_router del segmento (goBranch implícito al navegar).
  final String location;
  final String title;
  final List<TourStep> steps;
}

/// El tour completo: 6 segmentos, 13 pasos, de Inicio a Ajustes. El
/// contenido de los slides de la bienvenida (extintos, v17.8) vive aquí.
/// NO const: las anclas son GlobalKeys vivas (static finals del registro).
final List<TourSegment> kTourSegments = <TourSegment>[
  TourSegment(
    location: '/',
    title: 'INICIO',
    steps: [
      TourStep(
        id: 'inicio.bienvenida',
        title: 'Tu tablero, sin cuentas ni nube',
        // Ancla: acciones de la cabecera — SIEMPRE montadas en el shell.
        anchor: kHeaderActionsKey,
        body: 'Las cotizaciones llegan de APIs públicas (BCV, paralelo, TRM, '
            'Banxico, Banco Central de Brasil) y TODO lo tuyo vive solo en '
            'este teléfono. Funciona sin conexión desde el primer arranque.',
        flags: [Currency.ves, Currency.usd, Currency.eur, Currency.cop, Currency.brl, Currency.mxn],
      ),
      TourStep(
        id: 'inicio.cotizacion',
        title: 'Elige tu tasa activa',
        anchor: TourKeys.cotizacion,
        body: 'Cada fila de «Cotización principal» cambia la fuente con un '
            'toque: BCV, paralelo, promedio o tu manual. La tarjeta del dólar '
            'de arriba usa la que actives aquí, con la brecha vs BCV y la '
            'comparación con ayer.',
      ),
      TourStep(
        id: 'inicio.foco',
        title: 'Todas tus divisas',
        anchor: TourKeys.divisasFoco,
        body: '«Divisas del foco» abre el conversor con cada moneda; más abajo '
            '«Resumen del mes» y «Tus tiendas» se alimentan solos de tus '
            'compras reales.',
      ),
      TourStep(
        id: 'inicio.navbar',
        title: 'Cinco pestañas, todo a un toque',
        anchor: kNavBarKey,
        body: 'Inicio · Divisas · Lista · Productos · Análisis. La campana de '
            'arriba guarda tus avisos y la lupa busca en toda la app.',
      ),
    ],
  ),
  TourSegment(
    location: '/conversor',
    title: 'DIVISAS',
    steps: [
      TourStep(
        id: 'divisas.fecha',
        title: 'Conversor con fecha',
        anchor: TourKeys.convFecha,
        body: '¿Cuánto valía tu plata ayer o hace una semana? «Elegir fecha» '
            'abre el calendario con los días guardados: la tasa de ESE día '
            'entra al cálculo, con su ruta y su fuente a la vista.',
      ),
      TourStep(
        id: 'divisas.fuente',
        title: 'La fuente de la tasa, a la mano',
        anchor: TourKeys.convFuente,
        body: 'La fila «Fuente de tasa» te deja elegir entre las tasas que da '
            'la API para esa moneda. Tu elección vive solo en el conversor; '
            'comparte el resultado con tu marca desde «Compartir».',
      ),
    ],
  ),
  TourSegment(
    location: '/lista',
    title: 'LISTA',
    steps: [
      TourStep(
        id: 'lista.agregar',
        title: 'Escanea solo lo que importa',
        anchor: TourKeys.listaAgregar,
        body: 'Agrega por nombre o escaneando el código de barras: el escáner '
            'procesa únicamente el recuadro de apuntado y, si el código no '
            'existe, te ofrece crearlo. Al editar un ítem puedes capturar el '
            'peso (600 g, 1,5 l) y su tienda: la app calcula cuánto vale el '
            'kilo o el litro por ti.',
      ),
      TourStep(
        id: 'lista.sala',
        title: 'Comparte la lista y cierra la compra',
        anchor: TourKeys.listaSala,
        body: '«Sala en vivo» crea un código de 6 letras: quien lo tenga ve tu '
            'lista y sus cambios al instante, con o sin internet. Al final, '
            '«Finalizar compra» abre el modal con tienda única o varias, cuenta '
            'ajustada, nota y foto del ticket — y entra al historial sola.',
      ),
    ],
  ),
  TourSegment(
    location: '/productos',
    title: 'PRODUCTOS',
    steps: [
      TourStep(
        id: 'productos.busqueda',
        title: 'Tu libro de precios',
        anchor: TourKeys.prodBusqueda,
        body: 'El buscador filtra por nombre o código de barras. En la ficha de '
            'cada producto registras el precio de hoy, escaneas el código o '
            'fijas una META: cuando el último registro quede por debajo, te '
            'avisamos. Importa tu catálogo en CSV.',
      ),
    ],
  ),
  TourSegment(
    location: '/analisis',
    title: 'ANÁLISIS',
    steps: [
      TourStep(
        id: 'analisis.anclas',
        title: 'Brecha, inflación y gastos',
        anchor: TourKeys.anclas,
        body: 'Seis anclas: Divisas (brecha BCV↔paralelo), Inflación personal, '
            'Productos, Canasta, GASTOS y Tasa histórica. Toca cualquier punto '
            'de las gráficas para ver la cifra exacta de ese día.',
      ),
      TourStep(
        id: 'analisis.rango',
        title: 'Gastos automáticos y rango honesto',
        anchor: TourKeys.rango,
        body: '«Gastos» se alimenta SOLO de tus compras de Lista: total, '
            'donut por tienda y barras por mes, sin registro manual. Los chips '
            'cambian la ventana de todas las gráficas y la cobertura real '
            'siempre se anuncia — nunca prometemos más de lo que hay.',
      ),
    ],
  ),
  TourSegment(
    location: '/ajustes',
    title: 'AJUSTES',
    steps: [
      TourStep(
        id: 'ajustes.conexion',
        title: 'Tú decides cuándo consultar',
        anchor: TourKeys.conexion,
        body: 'En «Datos y conexión» decides si la app consulta APIs y cada '
            'cuánto. Todo lo descargado queda guardado en tu teléfono; con '
            'respaldo JSON con fusión y widgets de tasa en el escritorio.',
      ),
      TourStep(
        id: 'ajustes.tutorial',
        title: 'Este tour, cuando quieras',
        anchor: TourKeys.tutorial,
        body: 'Repite el tutorial completo desde aquí — también la bienvenida. '
            'Avisos con umbrales propios, biometría opcional y diagnóstico de '
            'fuentes completan la configuración.',
      ),
    ],
  ),
];

/// ─── Seam puro para tests ───────────────────────────────────────────────────
bool isTourDone(SharedPreferences prefs) => prefs.getBool(kTourDoneKey) ?? false;
Future<void> markTourDone(SharedPreferences prefs) =>
    prefs.setBool(kTourDoneKey, true);

/// Dispara el tour UNA vez por instalación (marca antes de mostrar: si algo
/// interrumpe, no vuelve a molestar). Tolerante: sin Provider de prefs
/// (tests/previews) es no-op.
Future<void> maybeRunTourOnce(BuildContext context) async {
  final SharedPreferences prefs;
  try {
    prefs = context.read<SharedPreferences>();
  } on ProviderNotFoundException {
    return;
  }
  if (isTourDone(prefs)) return;
  await markTourDone(prefs);
  if (!context.mounted) return;
  await runAppTour(context);
}

/// Guard anti-reentrada: jamás dos tours a la vez.
bool _tourRunning = false;
bool get tourRunning => _tourRunning;

/// Ejecuta el tour completo: navega segmento a segmento y, POR CADA PASO,
/// arrastra el ancla a la vista antes de abrir su overlay. Devuelve al
/// usuario a su pestaña de origen (o a Inicio si venía de la bienvenida).
/// «Saltar» corta el resto y restaura igual.
Future<void> runAppTour(BuildContext context) async {
  if (_tourRunning) return;
  _tourRunning = true;
  OverlayEntry? entry;
  try {
    final router = GoRouter.of(context);
    final overlayState = Overlay.of(context, rootOverlay: true);
    final origin =
        router.routerDelegate.currentConfiguration.uri.toString();
    final backTo = origin.isEmpty || origin == '/bienvenida' ? '/' : origin;

    final total = kTourSegments.fold<int>(0, (a, s) => a + s.steps.length);
    var index = 0;

    loop:
    for (final seg in kTourSegments) {
      if (!context.mounted) return;
      // Navega al segmento y deja respirar el layout antes de medir anclas.
      router.go(seg.location);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
      for (final step in seg.steps) {
        // Ancla no montada (pe. rama del shell aún sin visitar): el paso se
        // SALTA — jamás se recorta un rect que no existe.
        final anchorCtx = step.anchor?.currentContext;
        if (anchorCtx == null || !anchorCtx.mounted) {
          index++;
          continue;
        }
        // El ancla puede vivir DENTRO de un scroll y quedar bajo el pliegue:
        // se arrastra a la zona visible y se espera a que el arrastre TERMINE.
        await Scrollable.ensureVisible(
          anchorCtx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          alignment: 0.45,
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!context.mounted) return;

        // UN paso = UN OverlayEntry. Los botones completan el Completer una
        // sola vez: el doble toque no puede avanzar dos pasos por diseño.
        final next = Completer<bool>();
        entry = OverlayEntry(
          builder: (_) => _TourOverlay(
            segment: seg.title,
            step: step,
            stepIndex: index,
            totalSteps: total,
            onNext: () {
              if (!next.isCompleted) next.complete(true);
            },
            onSkip: () {
              if (!next.isCompleted) next.complete(false);
            },
          ),
        );
        overlayState.insert(entry);
        final goOn = await next.future;
        entry.remove();
        entry = null;
        if (!goOn) break loop; // «Saltar»: se corta el tour completo.
        index++;
      }
    }
    // Restaura la pestaña de origen (post-skip o post-completo).
    if (context.mounted) router.go(backTo);
  } finally {
    entry?.remove();
    _tourRunning = false;
  }
}

/// ─── Overlay de UN paso ─────────────────────────────────────────────────────
/// Cortina con el recorte REAL del ancla + tarjeta posicionada según el rect
/// medido. El GestureDetector de la cortina es opaco: nada de lo de abajo
/// recibe toques mientras el paso está abierto.
class _TourOverlay extends StatelessWidget {
  const _TourOverlay({
    required this.segment,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final String segment;
  final TourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  /// Rect REAL del ancla en coordenadas de pantalla (null si no medible).
  Rect? _anchorRect() {
    final ctx = step.anchor?.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery en el build: rotación/resize re-mide el recorte solo.
    final media = MediaQuery.of(context);
    final size = media.size;
    final rect = _anchorRect();

    // ¿Dónde hay más sitio? Debajo del ancla o encima de él.
    final spaceBelow =
        rect == null ? size.height : size.height - rect.bottom;
    final spaceAbove = rect == null ? 0.0 : rect.top;
    final below = spaceBelow >= spaceAbove;

    final double maxCardHeight = rect == null
        ? size.height * 0.6
        : (below
            ? spaceBelow - 14 - media.padding.bottom - 8
            : spaceAbove - 14 - media.padding.top - 8);

    final card = _TourCard(
      segment: segment,
      step: step,
      stepIndex: stepIndex,
      totalSteps: totalSteps,
      onNext: onNext,
      onSkip: onSkip,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Stack(children: [
        // Cortina con recorte: opaca al hit-test, bloquea TODO lo de abajo.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // traga el toque: el tour se avanza con la tarjeta
            child: CustomPaint(
              painter: _ScrimWithHole(hole: rect),
              size: size,
            ),
          ),
        ),
        // Tarjeta: debajo del ancla si hay más sitio, arriba si está baja.
        if (rect == null)
          Positioned(
            left: 16,
            right: 16,
            top: media.padding.top + 24,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              child: card,
            ),
          )
        else if (below)
          Positioned(
            left: 16,
            right: 16,
            top: rect.bottom + 14,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              child: card,
            ),
          )
        else
          Positioned(
            left: 16,
            right: 16,
            bottom: size.height - rect.top + 14,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxCardHeight),
              child: card,
            ),
          ),
      ]),
    );
  }
}

/// Cortina negra con el agujero del ancla (Path.difference — recorte real).
class _ScrimWithHole extends CustomPainter {
  const _ScrimWithHole({this.hole});

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.78);
    final full = Path()..addRect(Offset.zero & size);
    if (hole == null) {
      canvas.drawPath(full, paint);
      return;
    }
    final cut = RRect.fromRectAndRadius(
        hole!.inflate(6), const Radius.circular(14));
    final path = Path.combine(
        PathOperation.difference, full, Path()..addRRect(cut));
    canvas.drawPath(path, paint);
    // Filo suave alrededor del foco: señala el ancla sin hacer ruido.
    canvas.drawRRect(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimWithHole old) => old.hole != hole;
}

/// ─── Tarjeta del paso (estética VeInk) ──────────────────────────────────────
class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.segment,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final String segment;
  final TourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = stepIndex == totalSteps - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Color(0x42000000), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(segment,
                  style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: scheme.primary)),
            ),
            Text('${stepIndex + 1}/$totalSteps',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant)),
          ]),
          if (step.flags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              for (final c in step.flags)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Flag(c, size: 16),
                ),
            ]),
          ],
          const SizedBox(height: 8),
          Text(step.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(step.body,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(children: [
            TextButton(onPressed: onSkip, child: const Text('Saltar')),
            const Spacer(),
            FilledButton(
              onPressed: onNext,
              child: Text(isLast ? 'Entendido' : 'Siguiente'),
            ),
          ]),
        ],
      ),
    );
  }
}

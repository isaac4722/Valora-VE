/// ─── Tour guiado completo (v17.8 · UN solo tutorial, rejugable) ─────────────
/// Sustituye a los DOS sistemas anteriores (slides PageView de la bienvenida
/// + recorridos por módulo v17.2 + puntas Ola 1), cuyos defectos eran:
/// · Dos overlays a la vez (walkthrough del módulo + punta con 900 ms de
///   respiro que no alcanzaba) — capturas del dueño: «2 al mismo tiempo».
/// · Burbujas fuera de pantalla (altura estimada fija de 150 px).
/// · Una LISTA de recorridos en Ajustes en vez de un tutorial completo.
///
/// Motor: `tutorial_coach_mark` 1.3.4 (pub.dev) — un overlay por segmento,
/// tarjetas posicionadas según el ancla real (nunca estimadas) y respeto
/// de safe-area. El tour cruza pestañas solo: navega con go_router, espera
/// el layout y encadena segmentos; «Saltar» corta TODO y devuelve al
/// usuario a donde estaba.
///
/// Semántica: UNA oportunidad automática por instalación (flag
/// `valorave.tour-done`, se marca ANTES de mostrar — si algo interrumpe,
/// no vuelve a molestar) y replay libre desde Ajustes → Tutorial.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  /// Ancla del paso; null = tarjeta centrada arriba (sin foco).
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
        title: 'Modo offline total',
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

/// Guard anti-reentrada: jamás dos tours a la vez (la lección de las
/// capturas del dueño — nada se apila sobre nada).
bool _tourRunning = false;
bool get tourRunning => _tourRunning;

/// Ejecuta el tour completo: navega segmento a segmento, encadena overlays
/// y devuelve al usuario a su pestaña de origen (o a Inicio si venía de la
/// bienvenida). «Saltar» corta el resto y restaura igual.
Future<void> runAppTour(BuildContext context) async {
  if (_tourRunning) return;
  _tourRunning = true;
  try {
    final router = GoRouter.of(context);
    final origin =
        router.routerDelegate.currentConfiguration.uri.toString();
    final backTo = origin.isEmpty || origin == '/bienvenida' ? '/' : origin;

    // Índice global de pasos para «paso i de n» en las tarjetas.
    final total = kTourSegments.fold<int>(0, (a, s) => a + s.steps.length);
    var offset = 0;

    for (final seg in kTourSegments) {
      if (!context.mounted) return;
      // Navega al segmento y deja respirar el layout antes de medir anclas.
      router.go(seg.location);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) return;
      final finished = await _runSegment(context, seg, offset, total);
      if (!finished) break; // «Saltar»: se corta el tour completo.
      offset += seg.steps.length;
    }
    // Restaura la pestaña de origen (post-skip o post-completo).
    if (context.mounted) router.go(backTo);
  } finally {
    _tourRunning = false;
  }
}

/// Corre un segmento. Devuelve true si se completó, false si se saltó.
Future<bool> _runSegment(
    BuildContext context, TourSegment seg, int globalOffset, int total) {
  final done = Completer<bool>();
  TutorialCoachMark(
    targets: _targetsFor(context, seg, globalOffset, total),
    colorShadow: Colors.black,
    opacityShadow: 0.78,
    paddingFocus: 12,
    hideSkip: true, // Saltar vive DENTRO de la tarjeta propia
    useSafeArea: true,
    pulseEnable: true,
    focusAnimationDuration: const Duration(milliseconds: 420),
    unFocusAnimationDuration: const Duration(milliseconds: 260),
    onFinish: () {
      if (!done.isCompleted) done.complete(true);
    },
    onSkip: () {
      if (!done.isCompleted) done.complete(false);
      return true;
    },
  ).show(context: context);
  return done.future;
}

/// Construye los TargetFocus del segmento: ancla → alineación calculada con
/// el rect REAL (tarjeta abajo si hay sitio, arriba si el ancla está baja —
/// nunca estimada, nunca fuera de pantalla). [globalOffset] es el índice del
/// primer paso del segmento dentro del tour completo (para «paso i de n»).
List<TargetFocus> _targetsFor(
    BuildContext context, TourSegment seg, int globalOffset, int total) {
  final screen = MediaQuery.of(context).size;
  return [
    for (var i = 0; i < seg.steps.length; i++)
      TargetFocus(
        identify: seg.steps[i].id,
        keyTarget: seg.steps[i].anchor,
        shape: ShapeLightFocus.RRect,
        radius: 14,
        paddingFocus: 10,
        contents: [
          TargetContent(
            align: _alignFor(seg.steps[i].anchor, screen),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            builder: (ctx, controller) => _TourCard(
              segment: seg.title,
              step: seg.steps[i],
              stepIndex: globalOffset + i,
              totalSteps: total,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
            ),
          ),
        ],
      ),
  ];
}

/// Alineación según la posición real del ancla: centro por debajo del 55 %
/// de la pantalla → tarjeta ARRIBA; si no, abajo. Sin ancla → arriba.
ContentAlign _alignFor(GlobalKey? anchor, Size screen) {
  if (anchor == null) return ContentAlign.top;
  final ctx = anchor.currentContext;
  if (ctx == null) return ContentAlign.top;
  final box = ctx.findRenderObject() as RenderBox?;
  if (box == null || !box.attached || !box.hasSize) return ContentAlign.top;
  final rect = box.localToGlobal(Offset.zero) & box.size;
  return rect.center.dy > screen.height * 0.55
      ? ContentAlign.top
      : ContentAlign.bottom;
}

/// ─── Tarjeta del paso (estética VeInk, la del walkthrough v17.2) ────────────
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(step.body,
              style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(children: [
            TextButton(
              onPressed: onSkip,
              child: const Text('Saltar'),
            ),
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

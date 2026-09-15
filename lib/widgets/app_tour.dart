/// ─── Tour guiado completo (v19.0 · motor propio, un solo tutorial) ──────────
/// UN tutorial por instalación, rejugable desde Ajustes. Motor: coach_mark.dart
/// (overlay de la casa — sustituye a tutorial_coach_mark, retirado por:
/// tarjetas cortadas fuera de pantalla, focos sobre rects incorrectos y
/// overlays cuyos botones quedaban inalcanzables → tutorial congelado).
///
/// Reglas del recorrido:
/// · Cruza pestañas navegando con go_router; antes de cada paso arrastra el
///   ancla a la zona visible (ensureVisible) y espera el frame: el foco se
///   mide del rect REAL, después de que el scroll terminó.
/// · Ancla no montada → el paso se SALTA (jamás se enfoca un rect muerto).
/// · UN overlay a la vez (guard global); «Saltar» corta TODO y devuelve al
///   usuario a su pestaña de origen.
/// · UNA oportunidad automática por instalación (flag `valorave.tour-done`,
///   marcado ANTES de mostrar: si algo interrumpe, no vuelve a molestar).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/currencies.dart';
import 'app_router.dart' show kNavBarKey;
import 'coach_mark.dart';

/// Clave de la preferencia «ya vi el tour completo».
const String kTourDoneKey = 'valorave.tour-done';

/// ─── Registro central de anclas ─────────────────────────────────────────────
/// Las pantallas attachean estas claves; el tour enfoca su rect real. Una
/// clave = un widget en toda la app (los branches del shell viven tras el
/// primer visit, y si no están montados el paso se salta).
abstract final class TourKeys {
  // Inicio
  static final GlobalKey cotizacion = GlobalKey(debugLabel: 'tour-cotizacion');
  static final GlobalKey divisasFoco = GlobalKey(
    debugLabel: 'tour-divisas-foco',
  );
  // Divisas
  static final GlobalKey convFecha = GlobalKey(debugLabel: 'tour-conv-fecha');
  static final GlobalKey convFuente = GlobalKey(debugLabel: 'tour-conv-fuente');
  // Lista
  static final GlobalKey listaAgregar = GlobalKey(
    debugLabel: 'tour-lista-agregar',
  );
  static final GlobalKey listaSala = GlobalKey(debugLabel: 'tour-lista-sala');
  // Productos
  static final GlobalKey prodBusqueda = GlobalKey(
    debugLabel: 'tour-prod-busqueda',
  );
  // Análisis
  static final GlobalKey anclas = GlobalKey(debugLabel: 'tour-analisis-anclas');
  static final GlobalKey rango = GlobalKey(debugLabel: 'tour-analisis-rango');
  // Ajustes
  static final GlobalKey conexion = GlobalKey(
    debugLabel: 'tour-ajustes-conexion',
  );
  static final GlobalKey tutorial = GlobalKey(
    debugLabel: 'tour-ajustes-tutorial',
  );
}

/// ─── Modelo del tour ────────────────────────────────────────────────────────
class TourStep {
  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.anchor,
    this.flags = const <Currency>[],
    this.cta,
  });

  /// Identificador único (tests de integridad).
  final String id;
  final String title;

  /// Cuerpo con el contexto EXACTO de la zona enfocada (v19: reescritos
  /// paso a paso contra las pantallas reales — nada de consejos genéricos).
  final String body;

  /// Ancla del paso; null = tarjeta arriba centrada (sin foco).
  final GlobalKey? anchor;

  /// Banderas REALES (assets/flags) que encabezan la tarjeta.
  final List<Currency> flags;

  /// Texto del botón principal (por defecto «Siguiente»).
  final String? cta;
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

/// El tour completo: 6 segmentos, 13 pasos, de Inicio a Ajustes.
/// NO const: las anclas son GlobalKeys vivas (static finals del registro).
final List<TourSegment> kTourSegments = <TourSegment>[
  TourSegment(
    location: '/',
    title: 'INICIO',
    steps: [
      TourStep(
        id: 'inicio.bienvenida',
        title: 'Tus datos viven en tu teléfono',
        // Sin ancla: tarjeta centrada arriba — el mensaje es general y NO
        // debe enfocar los iconos de la cabecera (v18 lo hacía y el foco
        // no calzaba con el texto).
        body:
            'Las cotizaciones llegan de APIs públicas (BCV, paralelo, TRM, '
            'Banxico y Brasil) y se guardan aquí para consultarlas sin '
            'conexión. Tus listas, precios y compras nunca salen de este '
            'teléfono: sin cuentas, sin nube.',
        flags: [
          Currency.ves,
          Currency.usd,
          Currency.eur,
          Currency.cop,
          Currency.brl,
          Currency.mxn,
        ],
      ),
      TourStep(
        id: 'inicio.cotizacion',
        title: 'Elige tu tasa activa',
        anchor: TourKeys.cotizacion,
        body:
            'Cada fila de esta sección cambia la fuente con un toque: BCV, '
            'paralelo, promedio o tu manual. El dólar de arriba y todos los '
            'cálculos de la app usan la que actives aquí.',
      ),
      TourStep(
        id: 'inicio.foco',
        title: 'Todas tus divisas',
        anchor: TourKeys.divisasFoco,
        body:
            'Aquí ves cada moneda del foco con su tasa activa. «Ir al '
            'conversor» te lleva directo al cambio, con fecha y fuentes.',
      ),
      TourStep(
        id: 'inicio.navbar',
        title: 'Cinco pestañas, todo a un toque',
        anchor: kNavBarKey,
        body:
            'Inicio · Divisas · Lista · Productos · Análisis. La campana '
            'guarda tus avisos y la lupa busca en toda la app; los ajustes '
            'viven arriba a la derecha.',
      ),
    ],
  ),
  TourSegment(
    location: '/conversor',
    title: 'DIVISAS',
    steps: [
      TourStep(
        id: 'divisas.fecha',
        title: 'La tasa de otro día',
        anchor: TourKeys.convFecha,
        body:
            '«Ayer» o «Elegir fecha» cargan la tasa REAL de ese día, '
            'guardada en tu teléfono. «Volver a hoy» regresa al tablero '
            'vivo.',
      ),
      TourStep(
        id: 'divisas.fuente',
        title: 'La fuente, siempre a la vista',
        anchor: TourKeys.convFuente,
        body:
            'La línea de arriba muestra la fuente de la tasa y su '
            'frescura: tócala para ver todas las de la moneda y elegir '
            'cuál entra al cálculo.',
      ),
    ],
  ),
  TourSegment(
    location: '/lista',
    title: 'LISTA',
    steps: [
      TourStep(
        id: 'lista.agregar',
        title: 'Agrega por nombre o escaneo',
        anchor: TourKeys.listaAgregar,
        body:
            'Escribe el producto, su precio y la moneda — o escanea el '
            'código de barras. La tienda es opcional y cada compra cerrada '
            'queda en tu historial.',
      ),
      TourStep(
        id: 'lista.sala',
        title: 'Comparte la lista en vivo',
        anchor: TourKeys.listaSala,
        body:
            '«Sala en vivo» crea un código de 6 letras: quien lo tenga ve '
            'tu lista y sus cambios al instante, con o sin internet.',
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
        body:
            'Busca por nombre o código de barras. En la ficha de cada '
            'producto registras el precio de hoy, escaneas su código o '
            'fijas una META: te avisamos cuando baje de ella.',
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
        body:
            'Cada ancla abre su gráfica con datos reales: brecha '
            'BCV↔paralelo, inflación personal, productos, canasta y los '
            'gastos de tus compras de Lista.',
      ),
      TourStep(
        id: 'analisis.rango',
        title: 'La ventana de tiempo',
        anchor: TourKeys.rango,
        body:
            'Los chips cambian el rango de todas las gráficas. La '
            'cobertura disponible siempre se anuncia: nunca prometemos más '
            'de lo que hay.',
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
        body:
            'Con «No consultar API automáticamente» la app no toca la red: '
            'todo se lee de tu libro local y tus tasas manuales. El '
            'intervalo de consulta también se cambia aquí.',
      ),
      TourStep(
        id: 'ajustes.tutorial',
        title: 'Este tour, cuando quieras',
        anchor: TourKeys.tutorial,
        body:
            'Repite el tutorial o la bienvenida desde aquí. Avisos con '
            'umbrales, biometría opcional y respaldo JSON completan los '
            'ajustes.',
        cta: 'Entendido',
      ),
    ],
  ),
];

/// ─── Seam puro para tests ───────────────────────────────────────────────────
bool isTourDone(SharedPreferences prefs) =>
    prefs.getBool(kTourDoneKey) ?? false;
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

/// Guard anti-reentrada: jamás dos overlays a la vez (la lección de las
/// capturas del dueño — nada se apila sobre nada).
bool _tourRunning = false;
bool get tourRunning => _tourRunning;

/// Ejecuta el tour completo: navega segmento a segmento y POR CADA PASO
/// arrastra el ancla a la vista antes de medir su rect. Devuelve al usuario
/// a su pestaña de origen (o a Inicio si venía de la bienvenida). «Saltar»
/// corta el resto y restaura igual.
Future<void> runAppTour(BuildContext context) async {
  if (_tourRunning) return;
  _tourRunning = true;
  try {
    final router = GoRouter.of(context);
    final origin = router.routerDelegate.currentConfiguration.uri.toString();
    final backTo = origin.isEmpty || origin == '/bienvenida' ? '/' : origin;

    // Índice global de pasos para «paso i de n» en las tarjetas.
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
        // v19: paso SIN ancla → tarjeta centrada (se muestra igual); paso
        // CON ancla no montada (rama del shell sin visitar) → se SALTA:
        // jamás se enfoca un rect que no existe.
        final anchorCtx = step.anchor?.currentContext;
        if (step.anchor != null && (anchorCtx == null || !anchorCtx.mounted)) {
          index++;
          continue;
        }
        // El ancla puede vivir DENTRO de un scroll y quedar bajo el pliegue:
        // se arrastra a la zona visible y se espera a que el arrastre
        // TERMINA antes de medir el rect (el overlay mide DESPUÉS de esto).
        if (anchorCtx != null) {
          await Scrollable.ensureVisible(
            anchorCtx,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            alignment: 0.45,
          );
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        if (!context.mounted) return;
        final finished = await showCoachMark(
          context,
          anchor: step.anchor,
          card: CoachCardData(
            segment: seg.title,
            title: step.title,
            body: step.body,
            flags: step.flags,
            stepLabel: '${index + 1}/$total',
            cta: step.cta,
          ),
        );
        if (!finished) break loop; // «Saltar»: se corta el tour completo.
        index++;
      }
    }
    // Restaura la pestaña de origen (post-skip o post-completo).
    if (context.mounted) router.go(backTo);
  } finally {
    _tourRunning = false;
  }
}

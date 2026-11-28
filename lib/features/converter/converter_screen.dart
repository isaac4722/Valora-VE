/// ─── Conversor (§9.2 · MODULE=converter) ───────────────────────────────────
/// v34 (orden del dueño): el patrón CALCULADORA queda desnudo y simétrico
/// — título solo (H-21), fecha con protagonismo: «FECHA DE LA TASA» con
/// segmentos de 44 px **Ayer · Hoy · Mañana · Fecha** (H-22), campos
/// GEMELOS from/to con símbolo tras el número en ambos lados y tinta
/// plena en el activo (H-23), selector de tasa delineado a todo lo ancho
/// con el NOMBRE COLOREADO por tipo de tasa (verde oficial · rojo mercado
/// · naranja promedio · morado manual) y SOLO la fecha de actualización
/// debajo — sin la línea «1 USD = X» que saturaba (v34), teclado como
/// ÚNICA vía de entrada con ⌫ largo que limpia (H-25), precisión UNA
/// escala 2/3/4/«Completo» (H-26), swap como BOTÓN de verdad (v34: caja
/// delineada que no se deja cortar por el hairline), puerta de Pago
/// Móvil ante cualquier par con VES (H-29). Las NOTAS de conversión se
/// retiraron por orden del dueño (v34). Calendario histórico de
/// snapshots reales (sin dato → sin dato, nunca fabrica). Sin subtítulo,
/// sin atajos y sin fichas, el cuerpo cabe sin scroll en 390×844 (H-30;
/// el SingleChildScrollView queda como red de seguridad para textScale
/// alto).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/share_card.dart';
import '../../widgets/export_sheet.dart';
import '../../widgets/ui.dart' hide categoryInk;
import 'pago_movil_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

part 'converter_history.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  /// BIDIRECCIONAL (v19, orden del dueño): los DOS campos se editan.
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();
  double _fromTyped = 1;
  double _toTyped = 0;
  String _driver = 'from';
  String _lastSyncedPassive = '';

  /// v29 (H-22): today | yesterday | tomorrow | custom. «Mañana» usa la
  /// tasa VIVA de hoy y fecha el cobro para el día siguiente; «Hace 7
  /// días» se retiró (cualquier día se elige con «Fecha»).
  String _dateMode = 'today';
  DateTime? _customDate;
  Map<String, double>? _historicRates;
  bool _historicLoading = false;
  AppStore? _storeRef;

  /// Tecla del VeKeypad sobre el campo ACTIVO (driver v19: los dos lados
  /// se editan — el teclado escribe donde el usuario estaba escribiendo).
  /// v29 (V-3): el valor se parsea del texto YA RE-FORMATEADO por el
  /// MoneyField (modo borrado incluido) — el campo y el cálculo jamás
  /// divergen.
  void _padKey(String k) {
    final isFrom = _driver != 'to';
    final ctrl = isFrom ? _fromCtrl : _toCtrl;
    var t = ctrl.text;
    if (k == '⌫') {
      if (t.isNotEmpty) t = t.substring(0, t.length - 1);
    } else if (k == ',') {
      if (!t.contains(',')) t = t.isEmpty ? '0,' : '$t,';
    } else {
      t += k;
    }
    setState(() {
      _lastSyncedPassive = '';
      ctrl.text = t;
      final v = parseLocaleNum(ctrl.text) ?? 0;
      if (isFrom) {
        _fromTyped = v;
      } else {
        _toTyped = v;
      }
    });
  }

  /// v29 (H-25): ⌫ con pulsación LARGA — limpia el campo ACTIVO (el
  /// teclado es la única vía de entrada; convención de calculadora).
  void _clearActive() {
    setState(() {
      _lastSyncedPassive = '';
      if (_driver == 'to') {
        _toTyped = 0;
        _toCtrl.text = '';
      } else {
        _fromTyped = 0;
        _fromCtrl.text = '';
      }
    });
  }

  double _amountNowFor(RateContext ctx, Currency from, Currency to) {
    final rate = ctx.plan(from, to)?.rate ?? 0;
    if (_driver == 'to') return rate > 0 && _toTyped > 0 ? _toTyped / rate : 0;
    return _fromTyped;
  }

  @override
  void initState() {
    super.initState();
    _storeRef = ref.read(appStoreProvider);
    // v34: las notas de conversión se retiraron por orden del dueño — la
    // pantalla quedó solo cálculo, sin campo libre que saturara el espacio.
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _applyRateContext() {
    final DateTime? target = switch (_dateMode) {
      'yesterday' => DateTime.now().subtract(const Duration(days: 1)),
      'custom' => _customDate,
      // today y tomorrow: la tasa VIVA del tablero (H-22 — «Mañana»
      // planifica el cobro con la tasa de HOY, no consulta histórico).
      _ => null,
    };
    setState(() {
      _historicRates = null;
      if (target != null) {
        _historicLoading = true;
        _loadHistoric(target);
      }
    });
  }

  Future<void> _loadHistoric(DateTime date) async {
    final store = ref.read(appStoreProvider);
    final offlineNet = ref.read(ratesPollerProvider).offlineNet;
    final base = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final planIds = base.plan(from, to)?.sourceIds ?? const <String>[];
    final ids = <String>{
      'ves-bcv',
      'ves-parallel',
      'eur-ves-oficial',
      'cop-trm',
      'brl-br',
      'mxn-banxico',
      ...planIds,
      base.sel(from),
      base.sel(to),
    };
    final day = SnapshotPoint.dayKey(date);

    // MEJORA PERFORMANCE: Separa manuales y paraleliza el resto
    final manualRates = <String, double>{};
    final toFetch = <String>[];
    for (final id in ids) {
      if (id == 'ves-avg') continue;
      final def = RateSource.of(id);
      if (def?.category == SourceCategory.manual) {
        final v = base.rate(id);
        if (v > 0) manualRates[id] = v;
      } else {
        toFetch.add(id);
      }
    }

    final fetchedPoints = await Future.wait(
      toFetch.map((id) async {
        try {
          final point = await rateOn(
            id,
            day,
            preferLocal: offlineNet,
            localFallback: (sourceId, d) {
              final local =
                  store.snapshots
                      .where((p) => p.sourceId == sourceId && p.day == d)
                      .toList()
                    ..sort((a, b) => a.day.compareTo(b.day));
              return local.isEmpty
                  ? null
                  : HistPoint(date: local.last.day, rate: local.last.rate);
            },
          );
          if (point != null) {
            final pointDay = point.date.length == 10 ? point.date : day;
            return SnapshotPoint(sourceId: id, day: pointDay, rate: point.rate);
          }
        } catch (_) {}
        return null;
      }),
    );

    final fetched = fetchedPoints.whereType<SnapshotPoint>().toList();
    final rates = <String, double>{...manualRates};
    for (final p in fetched) {
      rates[p.sourceId] = p.rate;
    }

    if (fetched.isNotEmpty) {
      final merged = mergeSeries(fetched, store.snapshots);
      store.snapshots
        ..clear()
        ..addAll(merged);
      store.persistSnapshots();
    }
    final b = rates['ves-bcv'], p = rates['ves-parallel'];
    if (b != null && p != null) rates['ves-avg'] = (b + p) / 2;
    if (mounted) {
      setState(() {
        _historicRates = rates;
        _historicLoading = false;
      });
    }
  }

  RateContext _context(AppStore store) {
    final base = store.contextOf(module: RateModule.converter);
    if (_dateMode == 'today' ||
        _dateMode == 'tomorrow' ||
        _historicRates == null) {
      return base;
    }
    return RateContext(rates: _historicRates!, selected: base.selected);
  }

  /// v29 (H-27 · LA REGLA DEL 0 — orden del dueño): «vacío entra, vacío
  /// sale». Sin monto no se fabrica «0» ni «0,00» ni texto heredado — el
  /// campo pasivo se rellena SOLO con el cálculo nuevo (R-29b: el guard
  /// `_lastSyncedPassive` se reinicia y el pasivo se VACÍA físicamente,
  /// la sincronización no puede saltarse la limpieza).
  void _swapSides(
    AppStore store,
    Currency from,
    Currency to,
    ConversionPlan? plan,
    double result,
  ) {
    final rate = plan?.rate ?? 0;
    final nuevo = _driver == 'to'
        ? _toTyped
        : (rate > 0 && result > 0 ? result : _fromTyped);
    store.setConverterPair(to.code, from.code);
    setState(() {
      _fromTyped = nuevo > 0 ? nuevo : 0;
      _toTyped = 0;
      _driver = 'from';
      _lastSyncedPassive = '';
      _fromCtrl.text = nuevo > 0
          ? fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, to))
          : '';
      _toCtrl.text = '';
    });
  }

  void _pickSource(Currency c, String id) {
    final store = ref.read(appStoreProvider);
    final global = store.sourceFor(c);
    if (id == global) {
      store.setModuleRateSource(RateModule.converter, c, null);
    } else {
      store.setModuleRateSource(RateModule.converter, c, id);
    }
  }

  Future<Set<String>> _diasRemotos(List<String> ids) async {
    if (ref.read(ratesPollerProvider).offlineNet) return const <String>{};
    final probes = <String>{
      for (final id in ids)
        ...(id == 'ves-avg' ? const ['ves-bcv', 'ves-parallel'] : [id]),
    };
    final results = await Future.wait(
      probes
          .where((id) {
            final def = RateSource.of(id);
            return def != null && def.category != SourceCategory.manual;
          })
          .map((id) async {
            try {
              final res = await seriesForSource(id, 180);
              return res.points.map((p) => p.date).toSet();
            } catch (_) {
              return <String>{};
            }
          }),
    );
    return results.expand((e) => e).toSet();
  }

  Future<void> _openHistoricCalendar() async {
    final store = ref.read(appStoreProvider);
    final ctx = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final ids = <String>{
      if (plan != null) ...plan.sourceIds,
      ctx.sel(from),
      if (from != to) ctx.sel(to),
    };
    final days = <String>{
      for (final id in ids)
        for (final p in snapshotSeries(store.snapshots, id, 180)) p.day,
    };
    if (!mounted) return;
    final label = ids
        .map((id) => convSourceNames[id] ?? RateSource.of(id)?.label ?? id)
        .join(' + ');
    // v23.3 (pez 2-a P0-1): chrome del kit — el calendario histórico era
    // el último modal crudo de radio 20 de la app.
    final picked = await showVeHalfSheet<DateTime>(
      context: context,
      title: 'Elegir fecha histórica',
      builder: (_) => _CalendarioHistorico(
        days: days,
        futureDays: _diasRemotos(ids.toList()),
        initial: _dateMode == 'custom' ? _customDate : null,
        sourceLabel: label,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customDate = picked;
      _dateMode = 'custom';
    });
    _applyRateContext();
  }

  /// La fecha que viaja en tarjetas y cobros (v29: «Mañana» fechado).
  DateTime _fechaActiva() => switch (_dateMode) {
    'tomorrow' => DateTime.now().add(const Duration(days: 1)),
    'yesterday' => DateTime.now().subtract(const Duration(days: 1)),
    'custom' => _customDate ?? DateTime.now(),
    _ => DateTime.now(),
  };

  Future<Uint8List?> _renderCard() async {
    final store = ref.read(appStoreProvider);
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return null;
    final result = amount * plan.rate;
    final primaryId = plan.sourceIds.isNotEmpty
        ? plan.sourceIds.first
        : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    return renderConversionSharePng(
      context,
      from: from,
      to: to,
      inputAmount: amount,
      resultAmount: result,
      rateLine:
          '1 ${from.code} = ${fmtRatePrecise(plan.rate, store.settings.precision)} ${to.code}',
      sourceLabel: cat.isEmpty ? label : '$label · $cat',
      date: _fechaActiva(),
    );
  }

  Future<void> _shareCard() async {
    final store = ref.read(appStoreProvider);
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final text =
        '${fmtMoneyPrecise(amount, from, store.settings.precision)} ${from.code} = ${fmtMoneyPrecise(result, to, store.settings.precision)} ${to.code} · 1 ${from.code} = ${fmtRatePrecise(plan.rate, store.settings.precision)} ${to.code} · ValoraVE';
    await showExportSheet(
      context,
      ExportSpec(
        title: 'Resultado ${from.code} → ${to.code}',
        subtitle:
            '${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} ${to.code}',
        formats: [
          ExportFormat(
            icon: Icons.subject_rounded,
            label: 'Texto',
            hint: 'Cifra y tasa listas para pegar en un chat',
            // v28 · TEXTO: se copia (o se guarda); jamás share nativo.
            kind: ExportKind.texto,
            run: (mode) async {
              if (mode == ExportMode.guardar) {
                final path = await downloadText(
                  text,
                  fileName: 'conversion-valorave.txt',
                );
                return path == null
                    ? 'No se pudo guardar.'
                    : 'Guardado en: $path';
              }
              return copiarTexto(text, 'Texto copiado');
            },
          ),
          ExportFormat(
            icon: Icons.image_outlined,
            label: 'Imagen PNG',
            hint: 'Tarjeta de ValoraVE con la conversión',
            kind: ExportKind.archivo,
            run: (mode) async {
              final png = await _renderCard();
              if (png == null) return 'No pude generar la tarjeta';
              if (mode == ExportMode.compartir) {
                await sharePng(png, 'conversion-valorave.png');
                return null;
              }
              final path = await downloadBytes(
                png,
                fileName: 'conversion-valorave.png',
              );
              return path == null
                  ? 'No se pudo guardar la imagen.'
                  : 'Guardado en: $path';
            },
          ),
        ],
      ),
    );
  }

  void _copyResult() {
    final store = ref.read(appStoreProvider);
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final primaryId = plan.sourceIds.isNotEmpty
        ? plan.sourceIds.first
        : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    copiarAlPortapapeles(
      context,
      '${fmtMoneyPrecise(amount, from, store.settings.precision)} ${from.code} = ${fmtMoneyPrecise(result, to, store.settings.precision)} ${to.code} · 1 ${from.code} = ${fmtRatePrecise(plan.rate, store.settings.precision)} ${to.code} ($label${cat.isEmpty ? '' : ' · $cat'}) · ValoraVE',
      'Resultado copiado',
    );
  }

  /// El pasivo espeja el cálculo con la escala ÚNICA de precisión (H-26):
  /// 2/3/4 fijos · «Completo» (6) sin ceros de relleno · COP 0 (formato
  /// local §3.3).
  void _syncPassiveController(
    RateContext ctx,
    Currency from,
    Currency to,
    double result,
    double amount,
  ) {
    final passiveTo = _driver == 'from';
    final precision = _storeRef?.data.settings.precision ?? 2;
    String fmtMonto(double v, Currency c) {
      if (c == Currency.cop) return fmtNum(v, decimals: 0);
      if (precision >= 6) return fmtNumFull(v);
      return fmtNum(v, decimals: precision);
    }

    final passiveTxt = passiveTo
        ? (result > 0 ? fmtMonto(result, to) : '')
        : (amount > 0 ? fmtMonto(amount, from) : '');
    if (passiveTxt == _lastSyncedPassive) return;
    final ctrl = passiveTo ? _toCtrl : _fromCtrl;
    if (ctrl.text == passiveTxt) {
      _lastSyncedPassive = passiveTxt;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ctrl.text != passiveTxt) {
        ctrl.value = TextEditingValue(
          text: passiveTxt,
          selection: TextSelection.collapsed(offset: passiveTxt.length),
        );
        _lastSyncedPassive = passiveTxt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromCode = ref.watch(
      appStoreProvider.select((s) => s.data.converter.from),
    );
    final toCode = ref.watch(
      appStoreProvider.select((s) => s.data.converter.to),
    );
    final precision = ref.watch(
      appStoreProvider.select((s) => s.settings.precision),
    );
    final from = CurrencyX.from(fromCode);
    final to = CurrencyX.from(toCode);

    final store = ref.watch(appStoreProvider);
    final ctx = _context(store);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    double result = 0;
    if (plan != null && amount > 0) result = amount * plan.rate;

    _syncPassiveController(ctx, from, to, result, amount);

    final primaryId = (plan != null && plan.sourceIds.isNotEmpty)
        ? plan.sourceIds.first
        : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final entry = store.board.sources[primaryId];
    // v34 · fix del «hace 9 horas» (hallazgo del dueño): la fecha que ve el
    // usuario es la de la ÚLTIMA CONSULTA (fetchedAt) — la fecha de
    // publicación de la API (BCV 1 vez al día) jamás se movía al
    // actualizar a mano. La manual conserva su propio reloj.
    final when = src?.category == SourceCategory.manual
        ? (entry?.updatedAt ?? store.board.fetchedAt)
        : (store.board.fetchedAt ?? entry?.updatedAt);
    final frescura = src?.category == SourceCategory.manual
        ? 'tu tasa manual'
        : (when != null ? timeAgo(when) : 'sin fecha aún');
    final scheme = Theme.of(context).colorScheme;

    // v29 (H-29): la puerta de Pago Móvil aparece ante CUALQUIER par con
    // VES — destino VES cobra el RESULTADO; origen VES cobra el MONTO
    // escrito; jamás con par sin Bs.
    final bool parConBs = from == Currency.ves || to == Currency.ves;
    final double montoPago = to == Currency.ves
        ? result
        : (from == Currency.ves ? amount : 0);

    // v29 (H-24): la divisa cuyas fuentes alimentan el par (la de origen
    // si tiene fuentes; si no, la de destino — USD es el puente, no una
    // fuente elegible). El override del módulo y su limpieza viajan con
    // ELLA, no con la de origen a ciegas.
    final Currency fuenteCur = RateSource.sourcesFor(from).isNotEmpty
        ? from
        : to;

    // v26 (orden del dueño · dispositivos nuevos): en HORIZONTAL el
    // Conversor reparte la pantalla — cifras y secciones a la izquierda
    // (scroll), acciones + teclado como PANEL fijo a la derecha (móvil
    // girado, plegable abierto, escritorio). En VERTICAL nada cambia: el
    // patrón calculadora de siempre (piso fijo, v24.1a CERRADO — no se
    // re-arquitectura). La decisión se toma con LayoutBuilder: mide el
    // espacio REAL de la pantalla (el sidebar del shell ancho ya descontó
    // sus 224 px), no el de la ventana completa.

    // Cuerpo scrollable (red de seguridad, H-30): fecha + selector +
    // campos gemelos + notas.
    final Widget cuerpo = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TipsTrigger(scope: 'conversor'),
          // v29 (H-21): título SOLO — la tasa vive en su selector (H-24).
          const VeTitle(child: Text('Conversor')),
          KeyedSubtree(
            key: TourKeys.convFecha,
            child: _FechaTasas(
              mode: _dateMode,
              customDate: _customDate,
              loading: _historicLoading,
              sinDatos:
                  _historicRates != null &&
                  !_historicLoading &&
                  (plan == null || plan.rate <= 0),
              onMode: (m) {
                setState(() => _dateMode = m);
                _applyRateContext();
              },
              onOpenCalendar: _openHistoricCalendar,
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: TourKeys.convFuente,
            child: RepaintBoundary(
              child: _DualInput(
                precision: precision,
                fromCtrl: _fromCtrl,
                toCtrl: _toCtrl,
                from: from,
                to: to,
                result: result,
                plan: plan,
                ctx: ctx,
                driver: _driver,
                activeSourceId: primaryId,
                frescura: frescura,
                hasOverride: _hasOverride(store, fuenteCur),
                // v24.1 (patrón calculadora): tocar el lado INACTIVO abre
                // una entrada NUEVA (el valor pasivo se sustituye, no se
                // concatena); tocar el lado ya activo no borra lo tecleado.
                onDriverTap: (d) => setState(() {
                  if (_driver == d) return;
                  _driver = d;
                  _lastSyncedPassive = '';
                  if (d == 'to') {
                    _toTyped = 0;
                    _toCtrl.text = '';
                  } else {
                    _fromTyped = 0;
                    _fromCtrl.text = '';
                  }
                }),
                onSwap: () => _swapSides(store, from, to, plan, result),
                onFrom: (c) => c == to
                    ? _swapSides(store, from, to, plan, result)
                    : store.setConverterPair(c.code, to.code),
                onTo: (c) => c == from
                    ? _swapSides(store, from, to, plan, result)
                    : store.setConverterPair(from.code, c.code),
                onPickSource: _pickSource,
                onClearOverride: () => store.setModuleRateSource(
                  RateModule.converter,
                  fuenteCur,
                  null,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // v24.1 (patrón calculadora): el teclado es PISO FIJO — SIEMPRE visible
    // y SIEMPRE en el mismo lugar: lo único que sube o baja es el contenido,
    // jamás el pad. Sin plegado: un calculador no esconde su teclado (los
    // campos son de solo lectura y el pad es la única vía de entrada).
    // v26: este mismo bloque es el PANEL derecho en horizontal.
    final Widget pisoCard = RepaintBoundary(
      child: VeCard(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // v25.1: acciones en el PISO — siempre visibles y tocables
            // junto al pad, nunca tras el pliegue.
            Row(
              children: [
                Semantics(
                  label: 'Compartir resultado',
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    variant: VeBtnVariant.secondary,
                    enabled: plan != null && result > 0,
                    onPressed: _shareCard,
                    child: const Icon(LucideIcons.share2, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Copiar resultado',
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    variant: VeBtnVariant.secondary,
                    enabled: plan != null && result > 0,
                    onPressed: _copyResult,
                    child: const Icon(LucideIcons.copy, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // v29 (H-29): puerta de Pago Móvil ante CUALQUIER cambio del
                // par con VES; con «Mañana» el cobro viaja fechado.
                if (parConBs)
                  Expanded(
                    child: VeBtn(
                      size: VeBtnSize.lg,
                      variant: VeBtnVariant.secondary,
                      icon: LucideIcons.smartphone,
                      enabled: montoPago > 0,
                      onPressed: () => showPagoMovilSheet(
                        context,
                        ref: ref,
                        montoBs: montoPago,
                        para: _dateMode == 'tomorrow'
                            ? DateTime.now().add(const Duration(days: 1))
                            : null,
                      ),
                      child: const Text('Pago Móvil'),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            VeKeypad(onKey: _padKey, onClear: _clearActive),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: VeEntry(
        // v23.2 — patrón calculadora (vertical): piso fijo abajo y la cifra
        // siempre a la vista. v29 (H-30): sin subtítulo, sin atajos y sin
        // fichas, el cuerpo cabe SIN scroll en 390×844 — el scroll queda
        // como red de seguridad (textScale alto / landscape comprimido).
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool horizontal =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth >= 560;
            if (!horizontal) {
              return Column(
                children: [
                  Expanded(child: cuerpo),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: pisoCard,
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cuerpo),
                // Panel del pad: ancho cómodo para 3 columnas de teclas
                // grandes; scrollea SOLO si la ventana fuera más baja que
                // el pad (paisajes muy comprimidos).
                SizedBox(
                  width: 340,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 10),
                    child: SingleChildScrollView(child: pisoCard),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _hasOverride(AppStore store, Currency c) => store
      .data
      .settings
      .rateSourcesByModule
      .containsKey(moduleRateKey(RateModule.converter.code, c.code));
}

/// v29 (H-22): la FECHA con protagonismo — rótulo «FECHA DE LA TASA» +
/// segmentos de 44 px con píldora deslizante: **Ayer · Hoy · Mañana ·
/// Fecha**. «Mañana» planifica el cobro del día siguiente con la tasa viva
/// de hoy; «Fecha» abre el calendario histórico; «Hace 7 días» se retiró
/// (cualquier día se elige con «Fecha»).
class _FechaTasas extends StatelessWidget {
  const _FechaTasas({
    required this.mode,
    required this.customDate,
    required this.loading,
    required this.sinDatos,
    required this.onMode,
    required this.onOpenCalendar,
  });
  final String mode;
  final DateTime? customDate;
  final bool loading;
  final bool sinDatos;
  final ValueChanged<String> onMode;
  final VoidCallback onOpenCalendar;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VeInk? ink = Theme.of(context).extension<VeInk>();
    final String contexto = switch (mode) {
      'tomorrow' => 'Para mañana · cobro planificado con la tasa de hoy',
      'yesterday' => 'Tasa de ayer',
      _ =>
        customDate == null
            ? 'Tasa del día elegido'
            : 'Tasa del ${fmtDate(customDate!)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FECHA DE LA TASA',
          style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        // R-30g: los segmentos llevan FittedBox + Semantics (dentro de
        // VeSegmented) — a textScale alto la etiqueta se reduce, no desborda.
        VeSegmented<String>(
          value: mode,
          height: 44,
          onChanged: (m) {
            // «Fecha» abre el calendario (H-22): cualquier día, no solo
            // los preset; al elegir, el propio modo pasa a 'custom'.
            if (m == 'custom') {
              onOpenCalendar();
            } else {
              onMode(m);
            }
          },
          segments: const [
            VeSegment(value: 'yesterday', label: 'Ayer'),
            VeSegment(value: 'today', label: 'Hoy'),
            VeSegment(value: 'tomorrow', label: 'Mañana'),
            VeSegment(value: 'custom', label: 'Fecha'),
          ],
        ),
        if (mode != 'today') ...[
          const SizedBox(height: 8),
          if (loading)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Buscando tasa…', style: TextStyle(fontSize: 13.5)),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  mode == 'tomorrow'
                      ? LucideIcons.calendarClock
                      : Icons.history,
                  size: 15,
                  color: mode == 'tomorrow'
                      ? scheme.onSurfaceVariant
                      : (ink?.warn ?? scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      sinDatos
                          ? 'Sin datos ese día. Elige otro en el calendario.'
                          : contexto,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: mode == 'tomorrow'
                            ? scheme.onSurfaceVariant
                            : (ink?.warn ?? scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
                VeBtn(
                  variant: VeBtnVariant.ghost,
                  size: VeBtnSize.sm,
                  onPressed: () => onMode('today'),
                  child: const Text('Hoy'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// v34: el bloque de cálculo — selector de tasa delineado a todo lo ancho
/// con el NOMBRE COLOREADO por tipo (H-24 v34) y SOLO la fecha de
/// actualización debajo (sin la línea «1 USD = X», orden del dueño),
/// campos GEMELOS (mismo MoneyField + símbolo tras el número +
/// CurrencySelect, display 30, tinta plena en el lado activo) con el swap
/// entre ambos como BOTÓN delineado de verdad, y la línea «≈» SOLO cuando
/// la vista recorta decimales reales (V-2/H-26). Estética «HOJA»: sin caja
/// envolvente — el control delineado es la única pieza con borde (es un
/// CONTROL, no una tarjeta de contenido).
class _DualInput extends ConsumerWidget {
  const _DualInput({
    required this.fromCtrl,
    required this.toCtrl,
    required this.from,
    required this.to,
    required this.result,
    required this.plan,
    required this.ctx,
    required this.driver,
    required this.activeSourceId,
    required this.frescura,
    required this.hasOverride,
    required this.onDriverTap,
    required this.onSwap,
    required this.onFrom,
    required this.onTo,
    required this.onPickSource,
    required this.onClearOverride,
    required this.precision,
  });
  final TextEditingController fromCtrl, toCtrl;
  final int precision;
  final Currency from, to;
  final double result;
  final ConversionPlan? plan;
  final RateContext ctx;
  final String driver, activeSourceId, frescura;
  final bool hasOverride;

  /// v24.1 (patrón calculadora): los campos son de SOLO LECTURA — el toque
  /// cambia el lado ACTIVO (el pad escribe donde el usuario tocó) y el
  /// teclado del sistema jamás aparece.
  final ValueChanged<String> onDriverTap;
  final VoidCallback onSwap;
  final ValueChanged<Currency> onFrom, onTo;
  final void Function(Currency c, String id) onPickSource;
  final VoidCallback onClearOverride;

  /// v34 · nombre SOLO (sin etiqueta secundaria «· Oficial»): el TIPO lo
  /// dice el color del texto — verde oficial · rojo mercado · naranja
  /// promedio · morado manual (orden del dueño).
  String _nombreFuente() {
    final src = RateSource.of(activeSourceId);
    return src?.label ?? activeSourceId;
  }

  /// La divisa cuyas fuentes alimentan el par (H-24): la de origen si
  /// tiene fuentes (VES→USD), si no la de destino (USD→VES — el dólar es
  /// el puente de la app, no una fuente elegible).
  Currency get _fuenteCurrency =>
      RateSource.sourcesFor(from).isNotEmpty ? from : to;

  Future<void> _openSourcesSheet(BuildContext context, WidgetRef ref) async {
    final c = _fuenteCurrency;
    await showRateSheet(
      context,
      ref: ref,
      currency: c,
      ctx: ctx,
      currentId: activeSourceId,
      onPick: (id) => onPickSource(c, id),
    );
  }

  /// v29 (H-23): fila GEMELA — campo · símbolo tras el número · selector
  /// de divisa; mismo estilo display 30 y tinta plena en el lado activo.
  Widget _filaCampo(
    BuildContext context, {
    required TextEditingController ctrl,
    required Currency cur,
    required bool activo,
    required bool conValor,
    required String hint,
    required VoidCallback onTap,
    required ValueChanged<Currency> onPick,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: MoneyField(
            controller: ctrl,
            readOnly: true,
            onTap: onTap,
            maxDecimals: 6,
            style: VeText.displayNum(
              30,
              color: (activo || conValor)
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              weight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              hintStyle: VeText.displayNum(30, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          cur.symbol,
          style: VeText.displayNum(
            30,
            color: activo ? scheme.onSurface : scheme.onSurfaceVariant,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        CurrencySelect(value: cur, onChanged: onPick),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ok = plan != null && result > 0;
    final activeSrc = RateSource.of(activeSourceId);
    // v34 · tinta de la categoría de la tasa activa — pinta el nombre y el
    // difuminado del selector (orden del dueño).
    final Color tipoInk = activeSrc == null
        ? scheme.onSurface
        : categoryInk(context, activeSrc.category);

    // H-26/V-2: la línea «≈» muestra la cifra exacta SOLO cuando la vista
    // recorta decimales reales (COP recorta a 0 por formato local).
    final viewDec = to == Currency.cop ? 0 : precision.clamp(2, 6);
    final exacta = fmtNumFull(result);
    final recorta = ok && realDecimals(result) > viewDec;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── v34 (H-24): selector de tasa — nombre COLOREADO + fecha, con
        // difuminado del color de su tipo que indica la selección ──
        InkWell(
          onTap: () => _openSourcesSheet(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ve.colorScheme.border),
              // v34 · difuminado del color del tipo de tasa (orden del
              // dueño): la selección se intuye del color antes de leer.
              gradient: ok
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        tipoInk.withValues(alpha: 0.12),
                        tipoInk.withValues(alpha: 0.01),
                      ],
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _nombreFuente(),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: ok ? tipoInk : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // v34: SOLO la fecha de actualización — sin la línea
                      // «1 USD = X» que saturaba (orden del dueño).
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          ok ? frescura : 'Sin tasa disponible para este par',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronDown,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (hasOverride) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              onPressed: onClearOverride,
              child: const Text('Seguir global'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _filaCampo(
          context,
          ctrl: fromCtrl,
          cur: from,
          activo: driver != 'to',
          conValor: fromCtrl.text.isNotEmpty,
          hint: 'Monto',
          onTap: () => onDriverTap('from'),
          onPick: onFrom,
        ),
        Padding(
          // v23.3 (pez 2-a P1-1): fila del swap a 44 — el botón insignia de
          // la pantalla tenía 32×32 de pista.
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: Center(child: Divider(height: 1))),
                _SwapBtn(onTap: onSwap),
              ],
            ),
          ),
        ),
        _filaCampo(
          context,
          ctrl: toCtrl,
          cur: to,
          activo: driver == 'to',
          conValor: ok,
          hint: 'Resultado',
          onTap: () => onDriverTap('to'),
          onPick: onTo,
        ),
        if (recorta || !ok)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                recorta ? '≈ $exacta' : 'sin tasa para este par',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SwapBtn extends ConsumerStatefulWidget {
  const _SwapBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  ConsumerState<_SwapBtn> createState() => _SwapBtnState();
}

class _SwapBtnState extends ConsumerState<_SwapBtn> {
  double _turns = 0;
  @override
  Widget build(BuildContext context) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Invertir par',
      child: TapScale(
        onTap: () {
          setState(() => _turns += 0.5);
          widget.onTap();
        },
        child: AnimatedRotation(
          turns: _turns,
          duration: const Duration(milliseconds: 220),
          curve: kEaseVe,
          child: Container(
            // v34 · swap como BOTÓN de verdad (hallazgo del dueño): el
            // glifo plano sobre el hairline parecía un gráfico cortado y
            // no un control. Caja delineada de 40×40 con superficie OPACA
            // — el hairline muere detrás, el botón se lee tocable — y la
            // pista de golpe sigue siendo 44×44 (pez 2-a P1-1).
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.card,
              border: Border.all(
                color: dark
                    ? VeColors.lineStrongDark
                    : VeColors.lineStrongLight,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.swap_vert, size: 20, color: scheme.foreground),
          ),
        ),
      ),
    );
  }
}

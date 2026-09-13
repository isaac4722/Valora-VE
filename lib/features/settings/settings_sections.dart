/// ─── Ajustes · secciones de datos (parte de settings_screen.dart) ──────────
/// País · personalización · monedas y tasas (por módulo + manuales) ·
/// apariencia (tema, Material You, biometría) · diagnóstico de fuentes.
/// Parte del archivo principal: comparte privacidad e imports.
part of 'settings_screen.dart';

/// Ancla país: protagonista + foco 6 + orden subir/bajar/reset.
class _Pais extends StatelessWidget {
  const _Pais({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);
    final order = CurrencyX.focusOrder(store.settings.currencyOrder);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('País'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tablero configurado para ${country.label}',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final c in Country.values)
                ChipTag(c.label, selected: country == c, onTap: () => store.setCountry(c)),
            ]),
            const SizedBox(height: 12),
            Text('Orden del foco', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (int i = 0; i < order.length; i++)
              Row(children: [
                Flag(order[i], size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(order[i].label, style: const TextStyle(fontSize: 12.5))),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 15),
                  onPressed: i == 0 ? null : () => _move(context, order, i, i - 1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 15),
                  onPressed: i == order.length - 1 ? null : () => _move(context, order, i, i + 1),
                ),
              ]),
            TextButton(
              onPressed: () => store.setSetting('currencyOrder', <String>[]),
              child: const Text('Restablecer orden'),
            ),
            // Espejo del Home: quitar el sueldo guardado (con confirmación).
            if (store.settings.effectiveSalary() != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _confirmQuitSalary(context),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Quitar sueldo'),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  /// Confirmación + setSetting('salary', null) — espejo del «Quitar sueldo»
  /// del Home (§9.1), aquí donde vive el país/foco.
  void _confirmQuitSalary(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar el sueldo?'),
        content: const Text('Se borra el sueldo guardado (monto, base/variable o rango). '
            'Podrás escribirlo de nuevo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              store.setSetting('salary', null);
              Navigator.pop(ctx);
            },
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  void _move(BuildContext context, List<Currency> order, int from, int to) {
    final codes = order.map((c) => c.code).toList();
    final item = codes.removeAt(from);
    codes.insert(to, item);
    store.setSetting('currencyOrder', codes);
  }
}

/// Ancla personalización: ticker modo/tamaño/velocidad con preview.
class _Personalizacion extends StatelessWidget {
  const _Personalizacion({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Personalización'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cinta de cotizaciones (solo Inicio)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text('Modo', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<String>(
              options: const ['featured', 'focus', 'off'],
              value: store.settings.tickerMode,
              onChanged: (v) => store.setSetting('tickerMode', v),
              labelOf: (v) => switch (v) { 'focus' => 'Divisas clave', 'off' => 'Apagada', _ => 'Mi país' },
            ),
            const SizedBox(height: 8),
            Text('Tamaño', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<String>(
              options: const ['compact', 'normal', 'large'],
              value: store.settings.tickerSize,
              onChanged: (v) => store.setSetting('tickerSize', v),
              labelOf: (v) => switch (v) { 'compact' => 'Compacta', 'large' => 'Grande', _ => 'Normal' },
            ),
            const SizedBox(height: 8),
            Text('Velocidad', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<int>(
              options: const [90, 120, 180],
              value: store.settings.tickerSpeed,
              onChanged: (v) => store.setSetting('tickerSpeed', v),
              labelOf: (v) => v == 90 ? 'Lenta' : (v == 180 ? 'Rápida' : 'Normal'),
            ),
            const SizedBox(height: 10),
            // Preview estático del modo elegido.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                switch (store.settings.tickerMode) {
                  'off' => 'Cinta apagada.',
                  'focus' => 'Vista: tus divisas del foco en el orden elegido (1 USD = X).',
                  _ => 'Vista: fuentes protagonistas de ${CountryX.from(store.settings.country).label} + euro.',
                },
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Ancla monedas: fuente global + por módulo + manuales + salud.
class _Monedas extends StatelessWidget {
  const _Monedas({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = store.contextOf();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Monedas y tasas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in CurrencyX.focusMain) ...[
              Text(c.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SourcePills(
                sources: RateSource.sourcesFor(c).map((s) => s.id).toList(),
                value: store.sourceFor(c),
                onChanged: (id) => store.setRateSource(c, id),
              ),
              const SizedBox(height: 4),
              if (ctx.rate(store.sourceFor(c)) > 0)
                Text('Activa: ${fmtRate(ctx.rate(store.sourceFor(c)))}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
            ],
            Text('Fuente por módulo', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final module in RateModule.values)
              _ModuleSource(store: store, module: module),
            const Divider(height: 18),
            // Leyenda de categorías (dp6): color = tipo de fuente.
            const CategoryLegend(),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Refresco automático de tasas', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Consulta el tablero en segundo plano al abrir la app',
                  style: TextStyle(fontSize: 11)),
              value: store.settings.autoRefresh,
              onChanged: (v) => store.setSetting('autoRefresh', v),
            ),
            const SizedBox(height: 8),
            Text('Tasas manuales (offline)', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            const _ManualRates(),
          ]),
        ),
      ),
    ]);
  }
}

class _ModuleSource extends StatelessWidget {
  const _ModuleSource({required this.store, required this.module});
  final AppStore store;
  final RateModule module;

  @override
  Widget build(BuildContext context) {
    final label = switch (module) {
      RateModule.converter => 'Conversor',
      RateModule.calculator => 'Lista',
      RateModule.finance => 'Finanzas',
    };
    final current = store.settings.rateSourcesByModule[moduleRateKey(module.code, 'VES')];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Text(current == null ? 'Global' : (RateSource.of(current)?.label ?? current),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 16),
          onSelected: (v) => store.setModuleRateSource(
              module, Currency.ves, v == 'global' ? null : v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'global', child: Text('Global')),
            for (final s in RateSource.sourcesFor(Currency.ves))
              PopupMenuItem(value: s.id, child: Text(s.label)),
          ],
        ),
      ]),
    );
  }
}

/// Editor de tasa manual por fuente + banner de salud.
class _ManualRates extends StatelessWidget {
  const _ManualRates();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(children: [
      for (final id in ['ves-manual', 'cop-manual', 'brl-manual', 'mxn-manual'])
        _ManualField(store: store, sourceId: id),
    ]);
  }
}

class _ManualField extends StatefulWidget {
  const _ManualField({required this.store, required this.sourceId});
  final AppStore store;
  final String sourceId;

  @override
  State<_ManualField> createState() => _ManualFieldState();
}

class _ManualFieldState extends State<_ManualField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.store.data.manualRates[widget.sourceId] == null
          ? ''
          : '${widget.store.data.manualRates[widget.sourceId]}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = RateSource.of(widget.sourceId)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SourceDot(SourceCategory.manual),
        const SizedBox(width: 8),
        Expanded(child: Text('Tasa manual ${s.currency.code}', style: const TextStyle(fontSize: 12.5))),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: '${s.base.code}→${s.quote.code}'),
          ),
        ),
        TextButton(
          onPressed: () {
            final v = parseLocaleNum(_ctrl.text) ?? 0;
            widget.store.setManualRate(widget.sourceId, v);
          },
          child: const Text('Guardar'),
        ),
      ]),
    );
  }
}

/// Ancla apariencia.
class _Apariencia extends StatelessWidget {
  const _Apariencia();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Apariencia'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedChips<ThemeMode>(
              options: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
              value: theme.mode,
              onChanged: (v) => theme.setMode(v, context.read<SharedPreferences>()),
              labelOf: (v) => switch (v) { ThemeMode.light => 'Claro', ThemeMode.dark => 'Grafito', _ => 'Sistema' },
            ),
            // Material You (dp6 · mejora 2): opt-in. Solo tiñe acciones y
            // selección; superficies y semántica de dinero siguen de marca.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: theme.dynamicColor,
              onChanged: (v) =>
                  theme.setDynamicColor(v, context.read<SharedPreferences>()),
              title: const Text('Color dinámico del sistema (Material You)',
                  style: TextStyle(fontSize: 13)),
              subtitle: Text(
                  'Android 12 o superior · botones y selección toman la paleta del wallpaper; fondos y cifras siguen de marca',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
            // Bloqueo biométrico (17.7): local_auth ya vivía como servicio;
            // ahora con toggle. Al activar verifica soporte real primero.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: store.settings.biometricLock,
              onChanged: (v) async {
                if (v) {
                  final ok = await BiometricService().canCheck;
                  if (!ok) {
                    if (context.mounted) {
                      showToast(context,
                          'Este equipo no tiene biometría ni PIN de bloqueo configurados',
                          kind: ToastKind.warn);
                    }
                    return; // no se activa sin soporte real
                  }
                }
                store.setBiometricLock(v);
              },
              title: const Text('Bloqueo biométrico al abrir',
                  style: TextStyle(fontSize: 13)),
              subtitle: Text(
                  'Huella, rostro o PIN del dispositivo. Se pregunta una vez al abrir la app; sin soporte nunca se activa',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Diagnóstico de fuentes (dp6 · mejora 8): consulta cada región en vivo y
/// mide latencia y fuentes obtenidas. El data layer (diagnoseRegions) ya
/// vivía en board.dart — aquí solo la vista honesta.
class _Diagnostico extends StatefulWidget {
  const _Diagnostico();

  @override
  State<_Diagnostico> createState() => _DiagnosticoState();
}

class _DiagnosticoState extends State<_Diagnostico> {
  bool _running = false;
  List<RegionHealth>? _result;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final r = await diagnoseRegions();
      if (mounted) setState(() => _result = r);
    } catch (_) {
      if (mounted) setState(() => _result = null);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Diagnóstico de fuentes'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Consulta cada región y mide su latencia. Si una falla, la app sigue con las demás.',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (_running)
              const Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                SizedBox(width: 12),
                Text('Consultando regiones…'),
              ])
            else
              GhostButton('Ejecutar diagnóstico',
                  icon: Icons.network_check_rounded, onPressed: _run),
            if (_result != null) ...[
              const SizedBox(height: 12),
              for (final r in _result!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Stamp(r.ok ? 'OK' : 'Sin respuesta',
                        color: r.ok ? ink.pos : ink.neg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('${r.sources} fuentes · ${r.latencyMs} ms',
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        if (r.error != null)
                          Text(r.error!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: ink.neg.withValues(alpha: 0.8))),
                      ]),
                    ),
                  ]),
                ),
            ],
          ]),
        ),
      ),
    ]);
  }
}


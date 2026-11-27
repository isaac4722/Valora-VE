/// ─── Ajustes · secciones de datos (parte de settings_screen.dart) ──────────
/// País · monedas y tasas (por módulo + manuales) · apariencia (tema,
/// Material You, biometría) · diagnóstico de fuentes · registros. Parte
/// del archivo principal (v30 · H-42: UNA pantalla por secciones).
/// v32: GUI plana — sin cajas, encabezado ÚNICO por sección (lo pone la
/// pantalla principal), filas del kit y switches del kit.
part of 'settings_screen.dart';

/// Ancla país: protagonista + foco 6 + orden subir/bajar/reset.
class _Pais extends ConsumerWidget {
  const _Pais({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);
    final order = CurrencyX.focusOrder(store.settings.currencyOrder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(
          'Tu tablero está en ${country.label}.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (final c in Country.values)
              ChipTag(
                c.label,
                selected: country == c,
                onTap: () => store.setCountry(c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Orden de tus divisas',
          style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < order.length; i++)
          Row(
            children: [
              Flag(order[i], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order[i].label,
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              // v21.2: las flechas hablan — tooltip + semántica. v32:
              // botones de icono del kit, grandes y centrados.
              VeIconBtn(
                icon: Icons.arrow_upward,
                size: 36,
                iconSize: 15,
                label: 'Subir ${order[i].label}',
                onTap: i == 0 ? null : () => _move(context, order, i, i - 1),
              ),
              VeIconBtn(
                icon: Icons.arrow_downward,
                size: 36,
                iconSize: 15,
                label: 'Bajar ${order[i].label}',
                onTap: i == order.length - 1
                    ? null
                    : () => _move(context, order, i, i + 1),
              ),
            ],
          ),
        // Espejo del Home: restaurar el orden (con confirmación) y quitar
        // el sueldo guardado.
        Row(
          children: [
            GhostButton(
              'Restaurar orden',
              onPressed: () => store.setSetting('currencyOrder', <String>[]),
            ),
            const SizedBox(width: 10),
            if (store.settings.effectiveSalary() != null)
              GhostButton(
                'Quitar sueldo',
                icon: Icons.payments_outlined,
                onPressed: () => _confirmQuitSalary(context),
              ),
          ],
        ),
      ],
    );
  }

  /// Confirmación + setSetting('salary', null) — espejo del «Quitar sueldo»
  /// del Home (§9.1), aquí donde vive el país/foco.
  void _confirmQuitSalary(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar el sueldo?'),
        content: const Text(
          'Se borra el sueldo guardado. Puedes escribirlo de nuevo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
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

// v26 (orden del dueño): el ancla «Personalización» (cinta de cotizaciones:
// modo/tamaño/velocidad) SE RETIRA por completo — la cinta del Inicio salió
// del shell y su configuración muere con ella. Los campos tickerMode/
// tickerSize/tickerSpeed del modelo también fueron retirados.

/// Ancla monedas: fuente global + por módulo + manuales + salud.
class _Monedas extends ConsumerWidget {
  const _Monedas({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = store.contextOf();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        for (final c in CurrencyX.focusMain) ...[
          Text(
            c.label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SourcePills(
            sources: RateSource.sourcesFor(c).map((s) => s.id).toList(),
            value: store.sourceFor(c),
            onChanged: (id) => store.setRateSource(c, id),
          ),
          const SizedBox(height: 4),
          if (ctx.rate(store.sourceFor(c)) > 0)
            Text(
              'Activa: ${fmtRate(ctx.rate(store.sourceFor(c)))}',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
        ],
        Text(
          'Fuente por módulo',
          style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        for (final module in RateModule.values)
          _ModuleSource(store: store, module: module),
        const SizedBox(height: 8),
        // Leyenda de categorías (dp6): color = tipo de fuente.
        const CategoryLegend(),
        _FilaSwitch(
          titulo: 'Refresco automático de tasas',
          sub: 'Consulta las tasas al abrir la app',
          value: store.settings.autoRefresh,
          onChanged: (v) => store.setSetting('autoRefresh', v),
        ),
        const SizedBox(height: 6),
        Text(
          'Tasas manuales',
          style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        const _ManualRates(),
        const SizedBox(height: 12),
        // v23: tasas propias con nombre (comparativa CalculaYa) —
        // el atajo cotidiano; las manuales por fuente son el modo
        // avanzado de siempre, intacto.
        Text(
          'Tus tasas',
          style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        const _CustomRates(),
      ],
    );
  }
}

class _ModuleSource extends ConsumerWidget {
  const _ModuleSource({required this.store, required this.module});
  final AppStore store;
  final RateModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (module) {
      RateModule.converter => 'Conversor',
      RateModule.calculator => 'Lista',
      // v17.8: Finanzas ya no es pantalla — esta fuente tasa las compras
      // y los registros de precio de las fichas de producto.
      RateModule.finance => 'Compras y fichas',
    };
    final current =
        store.settings.rateSourcesByModule[moduleRateKey(module.code, 'VES')];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5))),
          Text(
            current == null
                ? 'Global'
                : (RateSource.of(current)?.label ?? current),
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          // v28 · sin menú flotante: el selector abre la HOJA inferior
          // unificada (showVeHalfSheet) con las fuentes disponibles.
          VeIconBtn(
            icon: Icons.tune_rounded,
            size: 36,
            iconSize: 15,
            label: 'Elegir tasa de $label',
            onTap: () async {
              final options = <(String, String)>[
                ('global', 'Global (tasa activa del país)'),
                for (final s in RateSource.sourcesFor(Currency.ves))
                  (s.id, s.label),
              ];
              final picked = await showVeHalfSheet<String>(
                context: context,
                title: 'Tasa de $label',
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (id, name) in options)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          id == 'global'
                              ? Icons.public_rounded
                              : Icons.swap_horiz_rounded,
                          size: 20,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        trailing: id == (current ?? 'global')
                            ? const Icon(Icons.check_rounded, size: 17)
                            : null,
                        onTap: () => Navigator.pop(ctx, id),
                      ),
                  ],
                ),
              );
              if (picked == null) return;
              store.setModuleRateSource(
                module,
                Currency.ves,
                picked == 'global' ? null : picked,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Editor de tasa manual por fuente (v19 reconstruido): fila flexible
/// [categoría] [nombre + valor] [lápiz] que abre el editor compartido
/// (MoneyField con miles en vivo) — el ancho fijo de 120 px desbordaba en
/// pantallas angostas y el texto se salía.
class _ManualRates extends ConsumerWidget {
  const _ManualRates();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return Column(
      children: [
        for (final id in [
          'ves-manual',
          'cop-manual',
          'brl-manual',
          'mxn-manual',
        ])
          _ManualField(store: store, sourceId: id),
      ],
    );
  }
}

class _ManualField extends ConsumerWidget {
  const _ManualField({required this.store, required this.sourceId});
  final AppStore store;
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = RateSource.of(sourceId)!;
    final value = store.data.manualRates[sourceId];
    final set = value != null && value > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () =>
            showManualRateEditor(context, ref: ref, sourceId: sourceId),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              SourceSeal(SourceCategory.manual),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tasa manual ${s.currency.code}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Flexible: en pantallas angostas achica con ellipsis — NUNCA
              // desborda (el valor con 4 decimales es largo).
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                  set
                      ? '1 ${s.base.code} = ${fmtRate(value)} ${s.quote.code}'
                      : 'sin definir',
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: set ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                )),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// v23 · Editor de tasas propias con nombre (máx 8): lista con borrar y
/// alta en hoja modal (nombre + Bs/USD). Al tocar una tasa en Inicio se
/// APLICA como fuente manual — aquí solo vive la gestión.
class _CustomRates extends ConsumerWidget {
  const _CustomRates();

  Future<void> _abrirAlta(BuildContext context, AppStore store) async {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    // v23.3 (pez 2-a P0-1): alta con el patrón COMPLETO del kit —
    // showVeSheet (radio 14, asa, cabecera 48 + ✕), VeField/VeInput y pie
    // con VeBtn. Antes: modal crudo de radio 20, TextField con
    // OutlineInputBorder y TextButton/FilledButton — otra piel de hoja.
    final ok = await showVeSheet<bool>(
      context: context,
      title: 'Nueva tasa tuya',
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zelle, Efectivo, Binance… Aparecen en Tasas con sus brechas frente al BCV.',
              style: TextStyle(
                fontSize: 13.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            VeField(
              label: 'Nombre',
              child: VeInput(
                controller: nameCtrl,
                placeholder: 'Zelle',
                maxLength: 18,
                semantic: 'Nombre de la tasa',
              ),
            ),
            const SizedBox(height: 10),
            VeField(
              label: 'Bs por USD',
              child: MoneyField(
                controller: rateCtrl,
                maxDecimals: 4,
                hintText: '0,00',
              ),
            ),
          ],
        ),
      ),
      footer: Builder(
        builder: (sheetCtx) => Row(
          children: [
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.secondary,
                expands: true,
                onPressed: () => Navigator.of(sheetCtx).pop(false),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.primary,
                expands: true,
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      store.addCustomRate(nameCtrl.text, parseLocaleNum(rateCtrl.text) ?? 0);
    }
    nameCtrl.dispose();
    rateCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final rates = store.data.customRates;
    return Column(
      children: [
        for (final r in rates)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const SourceSeal(SourceCategory.manual),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${fmtRate(r.bsPerUsd)} Bs',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 6),
                // Borrar directo: sin confirmación — la lista es corta y la
                // acción se rehace en segundos (patrón del carrito).
                // v23.3 (pez 2-a P1-1): pista 44×44 + Semantics — era un
                // blanco de ~23 dp sin etiqueta (acción destructiva).
                Semantics(
                  button: true,
                  label: 'Borrar tasa ${r.name}',
                  child: InkWell(
                    onTap: () => store.removeCustomRate(r.id),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.close,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rates.length < AppStore.kMaxCustomRates)
          Align(
            alignment: Alignment.centerLeft,
            child: VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              onPressed: () => _abrirAlta(context, store),
              icon: LucideIcons.plus,
              child: const Text('Agregar tasa'),
            ),
          ),
        if (rates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'También aparecen en Tasas, junto al BCV y al paralelo.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Ancla apariencia (v32 plana): previews de tema + switches del kit.
class _Apariencia extends ConsumerWidget {
  const _Apariencia();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final store = ref.watch(appStoreProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // TASK-33 Linear: selector de tema con PREVIEWS (patrón
        // Vercel/Linear) — los dos temas de la app se ven antes de
        // elegir. Sustituye a los chips planos.
        ThemePreviewRow(
          value: theme.mode,
          onChanged: (v) =>
              theme.setMode(v, ref.read(sharedPreferencesProvider)),
        ),
        // Material You (dp6 · mejora 2): opt-in. Solo tiñe acciones y
        // selección; superficies y semántica de dinero siguen de marca.
        _FilaSwitch(
          titulo: 'Color dinámico del sistema (Material You)',
          sub: 'Android 12 o superior. Botones y selección usan el color '
              'del fondo.',
          value: theme.dynamicColor,
          onChanged: (v) => theme.setDynamicColor(
            v,
            ref.read(sharedPreferencesProvider),
          ),
        ),
        // Bloqueo biométrico (17.7): local_auth ya vivía como servicio;
        // ahora con toggle. Al activar verifica soporte real primero.
        _FilaSwitch(
          titulo: 'Bloqueo biométrico al abrir',
          sub: 'Huella, rostro o PIN al abrir. Se pide una sola vez.',
          value: store.settings.biometricLock,
          onChanged: (v) async {
            if (v) {
              final ok = await BiometricService().canCheck;
              if (!ok) {
                if (context.mounted) {
                  showToast(
                    context,
                    'Este equipo no tiene biometría ni PIN de bloqueo configurados',
                    kind: ToastKind.warn,
                  );
                }
                return; // no se activa sin soporte real
              }
            }
            store.setBiometricLock(v);
          },
        ),
      ],
    );
  }
}

/// Selector de tema con previews mini (TASK-33 · patrón Vercel/Linear).
///
/// Tres tarjetas tocables — Claro · Grafito · Sistema — cada una pintando un
/// mock diminuto del tema con los tokens REALES (bg, card, border, primary,
/// muted): el usuario ve los dos temas de la app antes de elegir. La
/// seleccionada lleva borde primario al 45 % y un check en la esquina.
class ThemePreviewRow extends ConsumerWidget {
  const ThemePreviewRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final (ThemeMode mode, String label, bool claro) in const [
          (ThemeMode.light, 'Claro', true),
          (ThemeMode.dark, 'Grafito', false),
          (ThemeMode.system, 'Sistema', true),
        ]) ...[
          Expanded(
            child: _ThemePreviewCard(
              label: label,
              claro: claro,
              system: mode == ThemeMode.system,
              selected: value == mode,
              onTap: () => onChanged(mode),
            ),
          ),
          if (mode != ThemeMode.system) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _ThemePreviewCard extends ConsumerWidget {
  const _ThemePreviewCard({
    required this.label,
    required this.claro,
    required this.system,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool claro;
  final bool system;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Tokens reales del tema que representa la tarjeta.
    final Color bg = claro ? VeColors.bgLight : VeColors.bgDark;
    final Color card = claro ? VeColors.cardLight : VeColors.cardDark;
    final Color primary = claro ? VeColors.primaryLight : VeColors.primaryDark;
    final Color muted = claro ? VeColors.mutedLight : VeColors.mutedDark;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        // v25 «HOJA»: miniatura SIN caja — la selección vive en la etiqueta
        // (tinta + w700), no en un borde.
        child: Column(
          children: [
            // Mock del tema: fondo + tarjeta con cifra + barra primaria.
            AspectRatio(
              aspectRatio: 1.9,
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(6),
                // Mock a base de Stack: resistente a cualquier tamaño (el
                // Column anidado desbordaba 5.9 px a 320 px de ancho).
                child: Stack(
                  children: [
                    // Tarjeta del mock.
                    Positioned.fill(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.topLeft,
                        // «cifra» del mock: barra gruesa tinta.
                        child: Container(
                          height: 5,
                          width: 24,
                          decoration: BoxDecoration(
                            color: claro ? VeColors.fgLight : VeColors.fgDark,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Botón del mock: esquina inferior derecha.
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        height: 4,
                        width: 14,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Ticker del mock: fila muted abajo a la izquierda.
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        height: 3,
                        width: 18,
                        decoration: BoxDecoration(
                          color: muted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (system)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.brightness_auto_outlined,
                      size: 11,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                // Flexible + ellipsis: a 320 px la tarjeta mide ~78 px y el
                // rótulo con icono no siempre cabe entero.
                Flexible(
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Diagnóstico de fuentes (dp6 · mejora 8): consulta cada región en vivo y
/// mide latencia y fuentes obtenidas. El data layer (diagnoseRegions) ya
/// vivía en board.dart — aquí solo la vista honesta. v32: plano, sin caja.
class _Diagnostico extends ConsumerStatefulWidget {
  const _Diagnostico();

  @override
  ConsumerState<_Diagnostico> createState() => _DiagnosticoState();
}

class _DiagnosticoState extends ConsumerState<_Diagnostico> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // (scheme e ink: usados por las filas de resultado abajo)
        if (_running)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: 12),
              Text('Consultando regiones…'),
            ],
          )
        else
          GhostButton(
            'Ejecutar diagnóstico',
            icon: Icons.network_check_rounded,
            onPressed: _run,
          ),
        if (_result != null) ...[
          const SizedBox(height: 12),
          for (final r in _result!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Stamp(
                    r.ok ? 'OK' : 'Sin respuesta',
                    color: r.ok ? ink.pos : ink.neg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          '${r.sources} fuentes · ${r.latencyMs} ms',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (r.error != null)
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                            r.error!,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 11,
                              color: ink.neg.withValues(alpha: 0.8),
                            ),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// ─── Registros de la app (v20.4 · observabilidad 100 % local) ──────────────
/// Visor del buffer talker: errores de red del tablero, reconexiones SSE,
/// fallos del worker en 2º plano y eventos de la Sala Viva. PRIVACIDAD: el
/// buffer vive SOLO en la memoria del teléfono (rotación 500) — no hay
/// envío a ningún servidor, coherente con «Tus datos viven en tu teléfono».
class _Registros extends ConsumerWidget {
  const _Registros();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        GhostButton(
          'Ver registros',
          icon: Icons.receipt_long_outlined,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TalkerScreen(
                talker: veTalker,
                appBarTitle: 'Registros de la app',
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Errores de red y eventos de la sala. Solo en este teléfono; nada '
          'sale de aquí.',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

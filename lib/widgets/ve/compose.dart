/// ─── Composición «Ve» · rows, sheets y hairlines (v25 «HOJA») ──────────────
/// Piezas de composición sobre Material 3 puro. La pantalla es UNA hoja de
/// papel continua: los contenedores (cards/grupos/sheets/sticky bars) son
/// TRANSPARENTES — la jerarquía la crean la tipografía, la tinta y el
/// espacio vertical; solo las hairlines (línea al 65 %) dividen filas y
/// secciones. CERO bordes, CERO sombras, CERO blur.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ve_theme.dart';

/// Hairline firma de la hoja (línea al 65 % de alpha).
BorderSide veHairline(BuildContext context) {
  final border = context.ve.colorScheme.border;
  return BorderSide(color: border.withValues(alpha: 0.65));
}

// ──────────────────────────────────────────────────────────────── Card ─────

/// «Tarjeta» v25 «HOJA»: contenedor INVISIBLE. Sin borde, sin fill, sin
/// sombra — solo aire y, si es interactiva, Material transparente + InkWell
/// con el asiento táctil 0.985. La jerarquía la pone el contenido.
class VeCard extends StatefulWidget {
  const VeCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.clip = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool clip;

  @override
  State<VeCard> createState() => _VeCardState();
}

class _VeCardState extends State<VeCard> {
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null;

    Widget content = Padding(padding: widget.padding, child: widget.child);

    if (!interactive) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(kVeRadius),
        clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
        child: content,
      );
    }

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _press = true),
          onTapUp: (_) => setState(() => _press = false),
          onTapCancel: () => setState(() => _press = false),
          child: AnimatedScale(
            // v21.1: presión táctil — el bloque se asienta 1.5 % al tocar
            // con la curva firma. Respeta disableAnimations.
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            scale: _press && !MediaQuery.disableAnimationsOf(context)
                ? 0.985
                : 1.0,
            child: Material(type: MaterialType.transparency, child: content),
          ),
        ),
      ),
    );
  }
}

/// Grupo de filas divididas (Group + Row del prototipo) v25 «HOJA»:
/// contenedor transparente con hairlines entre hijos y filas de mínimo 52 px
class VeGroup extends StatelessWidget {
  const VeGroup({super.key, required this.children, this.semantic});

  final List<Widget> children;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Semantics(
      label: semantic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.border.withValues(alpha: 0.65),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Fila de lista v25 «HOJA»: transparente (sin hover-fill), ≥52 px, tap con
/// InkWell; `danger` en tinta negativa.
class VeRow extends StatefulWidget {
  const VeRow({
    super.key,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
    this.danger = false,
    this.showChevron = false,
    this.semantic,
  });

  final Widget label;
  final Widget? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;
  final String? semantic;

  @override
  State<VeRow> createState() => _VeRowState();
}

class _VeRowState extends State<VeRow> {
  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;

    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: widget.danger ? ink.neg : scheme.foreground,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: widget.label,
                ),
              ),
              if (widget.sub != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: scheme.mutedForeground,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: widget.sub!,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.right != null) ...[
          const SizedBox(width: 12),
          DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.mutedForeground,
            ),
            child: widget.right!,
          ),
        ],
        if (widget.showChevron) ...[
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 14,
            color: scheme.mutedForeground,
          ),
        ],
      ],
    );

    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: content,
    );

    if (widget.onTap == null) {
      return Semantics(label: widget.semantic, child: row);
    }
    return Semantics(
      label: widget.semantic,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: widget.onTap, child: row),
      ),
    );
  }
}

// ──────────────────────────────────────────────────── Jerarquía texto ──────

/// Rótulo de sección en mayúsculas (eyebrow): 11 px w600 tracking .08em,
/// con slot `right` para acciones de encabezado.
class VeEyebrow extends StatelessWidget {
  const VeEyebrow({
    super.key,
    required this.child,
    this.right,
    // v22.0 (GUI clara · orden del dueño): línea de explicación bajo el
    // eyebrow — cada sección de Inicio dice en una frase qué ofrece, sin
    // adivinar. Muda (12 px, muted): jerarquía sin ruido.
    this.hint,
  });

  final Widget child;
  final Widget? right;

  /// Explicación de una línea para la sección (opcional).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.84,
                    color: scheme.mutedForeground,
                  ),
                  child: child,
                ),
              ),
              ?right,
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                hint!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  height: 1.35,
                  color: scheme.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Título de página del prototipo: eyebrow opcional arriba, 22 px Space
/// Grotesk semibold tracking -0.02em, acciones a la derecha.
class VeTitle extends StatelessWidget {
  const VeTitle({
    super.key,
    required this.child,
    this.sub,
    this.right,
    this.leading,
  });

  final Widget child;

  /// Subtítulo DEBAJO del título (v20 · orden del dueño): antes se pintaba
  /// ENCIMA en caps y leía como «texto arriba del header». Ahora es un
  /// subtítulo de verdad, mudo, bajo el número grande.
  final Widget? sub;
  final Widget? right;

  /// Acción al inicio (botón atrás de rutas sin tab: Historial).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: VeText.displayNum(
                    30,
                    color: scheme.foreground,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: scheme.mutedForeground,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: sub!,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 12), right!],
        ],
      ),
    );
  }
}

/// Entrada de pantalla (anim-in del prototipo): fade + 6 px hacia arriba en
/// 180 ms al montar la ruta.
class VeEntry extends StatelessWidget {
  const VeEntry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────── Sheet ─────

/// Sheet del prototipo: bottom-sheet en móvil y modal centrado en escritorio
/// (≥ 700 px), con la MISMA cromática exacta: cabecera 48 px (título + ✕),
/// cuerpo scrollable y pie opcional con área segura.
///
/// TECHO (TASK-35 · p3, como el `max-h-[88dvh]` del prototipo): la hoja
/// completa JAMÁS supera el 88 % de la altura ÚTIL (bajo la barra de
/// estado) — el cuerpo scrollea dentro de ese límite y nada «sube sin
/// techo» por encima del notch.
///
/// Construido sobre `showModalBottomSheet` (móvil) y `showDialog` (escritorio).
Future<T?> showVeSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? footer,
  Widget? trailing,
  bool wide = false,
  bool dismissible = true,
}) {
  final bool desktop = MediaQuery.sizeOf(context).width >= 700;
  final shad = context.ve;
  final barrier = shad.brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.40);
  // TECHO (v24 fix): se calcula con el MediaQuery del CONTEXTO QUE ABRE —
  // el modal bottom sheet con useSafeArea expone un MediaQuery sin padding
  // y el 88 % «útil» se inflaría sobre la barra de estado.
  final double ceiling =
      (MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top) *
      0.88;

  if (desktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: barrier,
      // El overlay del PopupRoute posiciona al hijo ARRIBA-IZQUIERDA si
      // nadie lo alinea (bug visto en runtime): el modal se centra aquí y
      // el chrome se auto-limita con su maxWidth + techo.
      builder: (context) => Center(
        child: _VeSheetChrome(
          title: title,
          footer: footer,
          trailing: trailing,
          wide: wide,
          dismissible: dismissible,
          ceiling: ceiling,
          body: builder(context),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrier,
    isDismissible: dismissible,
    enableDrag: false,
    // FIX CRÍTICO (TASK-35 · p3): el overlay posiciona el contenido suelto
    // arriba-izquierda — sin este Align, la hoja «subía» hasta el notch.
    // Alineado al borde inferior + ancho completo + techo del chrome: hoja
    // de abajo hacia arriba CON techo del 88 % útil.
    builder: (context) => Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: double.infinity,
        child: _VeSheetChrome(
          title: title,
          footer: footer,
          trailing: trailing,
          wide: wide,
          dismissible: dismissible,
          ceiling: ceiling,
          body: builder(context),
          bottomSheet: true,
        ),
      ),
    ),
  );
}

/// Hoja de MEDIA PANTALLA arrastrable (v20 · orden del dueño): los menús
/// contextuales de producto/ítem NACEN a la mitad («suban y que den a la
/// mitad») y solo cubren todo si el usuario las SUBE deslizando el
/// contenido hacia arriba — snap en 0.5 y 0.95, nunca de golpe.
///
/// En escritorio (≥700) mantiene el modal centrado de [showVeSheet]: la
/// media pantalla arrastrable es un patrón de teléfono.
Future<T?> showVeHalfSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? footer,
  Widget? trailing,
  bool wide = false,
  bool dismissible = true,
}) {
  final bool desktop = MediaQuery.sizeOf(context).width >= 700;
  if (desktop) {
    return showVeSheet<T>(
      context: context,
      title: title,
      builder: builder,
      footer: footer,
      trailing: trailing,
      wide: wide,
      dismissible: dismissible,
    );
  }
  final shad = context.ve;
  final barrier = shad.brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.40);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: barrier,
    isDismissible: dismissible,
    enableDrag: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      // Nace a la mitad; mínimo utilizable 0.30; techo casi total.
      initialChildSize: 0.5,
      minChildSize: 0.30,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.95],
      builder: (context, scrollController) => _VeHalfChrome(
        title: title,
        footer: footer,
        trailing: trailing,
        wide: wide,
        dismissible: dismissible,
        scrollController: scrollController,
        body: builder(context),
      ),
    ),
  );
}

/// Chrome de la hoja a media pantalla: asa de arrastre + cabecera del
/// sistema + cuerpo que scrollea CON el controlador de la hoja (subir el
/// scroll expande la hoja) + pie pegado.
class _VeHalfChrome extends StatelessWidget {
  const _VeHalfChrome({
    required this.title,
    required this.body,
    required this.footer,
    required this.wide,
    required this.dismissible,
    required this.scrollController,
    this.trailing,
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final Widget? trailing;
  final bool wide;
  final bool dismissible;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final double maxW = wide ? 576 : 448;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asa de arrastre (señal nativa de hoja deslizable).
              Container(
                height: 18,
                alignment: Alignment.center,
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.mutedForeground.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: veHairline(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                        maxLines: 1,
                      )),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                    if (dismissible)
                      // v23.3 (pez 2-a P1-1): caja de golpe ≥44 — visual
                      // 32 (mismo icono 15), pista 44×44 centrada.
                      const _VeSheetCloseBtn(),
                  ],
                ),
              ),
              // Cuerpo: el MISMO controlador de la hoja — al llegar al
              // tope del contenido, seguir subiendo EXPANDE la hoja.
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: body,
                ),
              ),
              if (footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(top: veHairline(context)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [Expanded(child: footer!)]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cromática compartida del sheet (cabecera · cuerpo · pie).
class _VeSheetChrome extends StatelessWidget {
  const _VeSheetChrome({
    required this.title,
    required this.body,
    required this.footer,
    required this.wide,
    required this.dismissible,
    this.trailing,
    this.bottomSheet = false,
    this.ceiling,
  });

  final String title;
  final Widget body;
  final Widget? footer;

  /// Acción compacta junto al título (antes del ✕): p. ej. «Leídas ·
  /// Limpiar» del centro de avisos.
  final Widget? trailing;

  /// Techo ya resuelto por quien abre (MediaQuery del contexto REAL — el
  /// modal bottom sheet con useSafeArea expone su MediaQuery sin padding).
  final double? ceiling;

  final bool wide;
  final bool dismissible;
  final bool bottomSheet;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final double maxW = wide ? 576 : 448;
    // Techo del prototipo (Sheet · max-h-[88dvh]): altura ÚTIL (bajo la
    // barra de estado) por 0.88 — móvil y escritorio.
    final mq = MediaQuery.of(context);
    final double ceiling =
        this.ceiling ?? (mq.size.height - mq.padding.top) * 0.88;

    Widget chrome = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: ceiling),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.card,
          // v25 «HOJA»: hojas radio 20, sin borde — solo el scrim separa.
          borderRadius: bottomSheet
              ? const BorderRadius.vertical(top: Radius.circular(20))
              : BorderRadius.circular(20),
        ),
        child: Material(
          // Ancestro Material transparente: los cuerpos de la app mezclan
          // controles con widgets Material propios (MoneyField, TextField
          // de nombre, PopupMenu de divisas…) que lo exigen.
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.only(left: 16, right: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: veHairline(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.foreground,
                        ),
                        maxLines: 1,
                      )),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                    if (dismissible)
                      // v23.3 (pez 2-a P1-1): caja de golpe ≥44 — visual
                      // 32 (mismo icono 15), pista 44×44 centrada.
                      const _VeSheetCloseBtn(),
                  ],
                ),
              ),
              // El cuerpo ocupa lo que sobre bajo el techo y scrollea —
              // JAMÁS empuja la cabecera sobre la barra de estado.
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: body,
                ),
              ),
              if (footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    border: Border(top: veHairline(context)),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [Expanded(child: footer!)]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!bottomSheet) {
      chrome = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: chrome,
      );
    }
    return chrome;
  }
}

// ─────────────────────────────────────────────────────────── StickyBar ─────

/// Barra pegada al fondo del viewport (StickyBar del prototipo): fondo
/// casi opaco + borde superior. Colocar como último hijo de un Stack
/// sobre el contenido scrollable.
///
/// v25 «HOJA»: papel SÓLIDO (puede tapar contenido al scrollear) + hairline
/// superior al 65 % — la única separación contra la hoja.
class VeStickyBar extends StatelessWidget {
  const VeStickyBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.background,
        border: Border(top: veHairline(context)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Empty ─────

/// Estado vacío v25 «HOJA»: SIN borde punteado y SIN medallón — icono
/// desnudo en muted, título, subtítulo y acción opcional centrada. La
/// ausencia se anuncia con aire y tinta, no con una caja.
class VeEmpty extends StatelessWidget {
  const VeEmpty({
    super.key,
    required this.title,
    this.sub,
    this.action,
    this.icon,
  });

  final String title;
  final String? sub;
  final Widget? action;

  /// Icono (Lucide en toda la app: receiptText, images, shoppingCart…).
  /// Sin icono el título queda solo, como siempre.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: scheme.mutedForeground),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          if (sub != null) ...[
            const SizedBox(height: 5),
            Text(
              sub!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                height: 1.5,
                color: scheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Ambiente ─────

/// Fondo ambiental del prototipo (app-ambient + app-dots): dos radiales
/// tenues (pos arriba-derecha 7 %, warn a la izquierda 6 %) y una rejilla de
/// puntos `--line` de 22 px que se desvanece al 72 % de la altura.
///
/// Pintado UNA sola vez (RepaintBoundary + shouldRepaint false) — costo
/// trivial incluso en pantallas grandes.
/// Fondo ambiental v25 «HOJA»: FUERA. La pantalla es papel plano — el
/// scaffold ya pinta el fondo; esta pieza queda como no-op transparente
/// para no romper a quien la monta (main_shell).
class VeAmbient extends StatelessWidget {
  const VeAmbient({super.key, this.dots = true});

  final bool dots;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

// ───────────────────────────────────────────────── Flash de número ────────

/// Flash del prototipo (anim-flash): cuando [value] cambia, el fondo del
/// hijo destella en pos/18 % y se disuelve en 900 ms. Para cifras de tasas.
class VeFlash extends StatefulWidget {
  const VeFlash({super.key, required this.value, required this.child});

  /// Valor vigilado: cada cambio dispara el flash.
  final Object value;
  final Widget child;

  @override
  State<VeFlash> createState() => _VeFlashState();
}

class _VeFlashState extends State<VeFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant VeFlash old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = context.ve;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _c.isAnimating
              ? ink.pos.withValues(alpha: (dark ? 0.14 : 0.18) * (1 - _c.value))
              : null,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────── Cifra tabular ─────────

/// Texto numérico tabular del prototipo (clase .num): Inter con tnum —
/// para montos y contadores que no deben bailar de ancho.
class VeNum extends StatelessWidget {
  const VeNum(this.data, {super.key, this.style, this.semanticsLabel});

  final String data;
  final TextStyle? style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Semantics(
      label: semanticsLabel ?? data,
      child: Text(
        data,
        style:
            (style ??
                    TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: scheme.foreground,
                    ))
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// ✕ de la hoja (v23.3 P1-1: visual 32, pista 44×44 centrada): ghost
/// Material puro — tinta muted que sube a fg y fondo accent al hover.
class _VeSheetCloseBtn extends StatefulWidget {
  const _VeSheetCloseBtn();

  @override
  State<_VeSheetCloseBtn> createState() => _VeSheetCloseBtnState();
}

class _VeSheetCloseBtnState extends State<_VeSheetCloseBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Material(
            color: _hover ? scheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  LucideIcons.x,
                  size: 15,
                  color: _hover ? scheme.foreground : scheme.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

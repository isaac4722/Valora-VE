/// ─── Editor de ítems con detalle (v17.2 · requisito D) ──────────────────────
/// Sheet firma (no Material crudo) que captura TODO el detalle de un ítem:
/// nombre · precio + moneda · cantidad · TIENDA (autocompletado con las
/// tiendas conocidas del libro) · CÓDIGO DE BARRAS (a mano o con el escáner
/// ROI) · PESO/TAMAÑO de la presentación (g/kg · ml/L).
///
/// Con tamaño capturado (>0) muestra en vivo el precio por unidad de compra:
/// «Bs 12,50 por kg» (price/size×1000 si la unidad base es g/ml) o
/// «$ 1,20 por litro» (price/size si kg/l).
///
/// Devuelve un CartItem por Navigator.pop (id vacío = nuevo ítem); el caller
/// decide addToCart vs updateCartItem. Cancelar/cerrar = null.
library;

import 'package:flutter/material.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/ui.dart';
import 'roi_scanner.dart';

/// Abre el editor; [initial] presente = editar, ausente = agregar (se puede
/// prellenar con [presetName] / [presetBarcode] desde el escáner).
Future<CartItem?> showItemEditorSheet(
  BuildContext context, {
  required AppStore store,
  CartItem? initial,
  String? presetName,
  String? presetBarcode,
}) {
  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      // Deja sitio al teclado sin tapar los campos del fondo.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: _ItemEditor(
          store: store,
          initial: initial,
          presetName: presetName,
          presetBarcode: presetBarcode,
        ),
      ),
    ),
  );
}

/// Campo de tienda con autocompletado sobre las tiendas conocidas del libro.
/// Libre (editable y borrable — null al vaciar); las opciones filtran sin
/// acentos. Reutilizado por el checkout (tienda única y multitienda).
class StoreAutocompleteField extends StatelessWidget {
  const StoreAutocompleteField({
    super.key,
    required this.stores,
    this.initialValue,
    required this.onChanged,
    this.hint = 'Tienda (opcional)',
  });

  final List<String> stores;
  final String? initialValue;

  /// Texto vigente (null = vacío). Dispara en cada cambio Y al elegir opción.
  final ValueChanged<String?> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: initialValue == null
          ? null
          : TextEditingValue(text: initialValue!),
      displayStringForOption: (s) => s,
      optionsBuilder: (TextEditingValue v) {
        final q = fold(v.text.toLowerCase());
        if (q.isEmpty) return const Iterable<String>.empty();
        return stores.where((s) => fold(s.toLowerCase()).contains(q));
      },
      onSelected: (s) => onChanged(s),
      fieldViewBuilder: (context, ctrl, focus, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focus,
          onSubmitted: (_) => onFieldSubmitted(),
          onChanged: (v) => onChanged(v.trim().isEmpty ? null : v.trim()),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.storefront_outlined, size: 17),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl,
              builder: (context, val, _) => val.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Borrar tienda',
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () {
                        ctrl.clear();
                        onChanged(null);
                      },
                    ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190, maxWidth: 320),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final s in options.take(6))
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      leading: const Icon(Icons.storefront_outlined, size: 16),
                      title: Text(s, style: const TextStyle(fontSize: 13)),
                      onTap: () => onSelected(s),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modo del tamaño capturado: ninguno · peso (g/kg) · volumen (ml/L).
enum _SizeMode { none, weight, volume }

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    required this.store,
    this.initial,
    this.presetName,
    this.presetBarcode,
  });

  final AppStore store;
  final CartItem? initial;
  final String? presetName;
  final String? presetBarcode;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _sizeCtrl;
  final _qtyCtrl = TextEditingController(text: '1');
  late Currency _currency;
  String? _storeName;
  _SizeMode _mode = _SizeMode.none;
  String _unit = 'g'; // g | kg | ml | l

  @override
  void initState() {
    super.initState();
    final it = widget.initial;
    _nameCtrl = TextEditingController(
      text: it?.name ?? widget.presetName ?? '',
    );
    _priceCtrl = TextEditingController(
      text: it == null ? '' : fmtMoney(it.price, CurrencyX.from(it.currency)),
    );
    _barcodeCtrl = TextEditingController(
      text: it?.barcode ?? widget.presetBarcode ?? '',
    );
    _sizeCtrl = TextEditingController(
      text: (it?.size != null && it!.size! > 0)
          ? fmtNum(it.size!, decimals: 2)
          : '',
    );
    _currency = CurrencyX.from(it?.currency ?? 'VES');
    _storeName = it?.store;
    // Modo/unidad inferidos de lo ya capturado (CartItem no tiene presentación).
    final su = it?.sizeUnit;
    if (su == 'g' || su == 'kg') {
      _mode = _SizeMode.weight;
      _unit = su!;
    } else if (su == 'ml' || su == 'l') {
      _mode = _SizeMode.volume;
      _unit = su!;
    }
    _qtyCtrl.text = '${it?.quantity ?? 1}';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _barcodeCtrl.dispose();
    _sizeCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyCtrl.text) ?? 1;
  double get _price => parseLocaleNum(_priceCtrl.text) ?? 0;
  double get _size =>
      _mode == _SizeMode.none ? 0 : (parseLocaleNum(_sizeCtrl.text) ?? 0);

  /// «Bs 12,50 por kg» · «$ 1,20 por litro» — null si no hay tamaño>0 ni precio.
  String? _unitPriceText() {
    if (_size <= 0 || _price <= 0) return null;
    final cur = _currency;
    final bool baseSmall = _unit == 'g' || _unit == 'ml';
    final per = baseSmall ? _price / _size * 1000 : _price / _size;
    final baseName = (_unit == 'g' || _unit == 'kg') ? 'kg' : 'litro';
    return '${fmtCurrency(per, cur)} por $baseName';
  }

  Future<void> _scanBarcode() async {
    final code = await RoiScannerScreen.scan(context);
    if (code == null || code == '__manual__') return;
    if (!mounted) return;
    setState(() => _barcodeCtrl.text = code);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final qty = _qty.clamp(1, 999);
    if (name.isEmpty || _price <= 0) {
      showToast(
        context,
        'Escribe nombre y precio válido (> 0)',
        kind: ToastKind.warn,
      );
      return;
    }
    final base = widget.initial;
    final hasSize = _size > 0;
    final item =
        (base ??
                CartItem(
                  id: '',
                  name: name,
                  quantity: qty,
                  price: _price,
                  currency: _currency.code,
                ))
            .copyWith(
              name: name,
              quantity: qty,
              price: _price,
              currency: _currency.code,
              barcode: _barcodeCtrl.text.trim().isEmpty
                  ? null
                  : _barcodeCtrl.text.trim(),
              store: _storeName,
              clearStore: _storeName == null,
              size: hasSize ? _size : null,
              clearSize: !hasSize,
              sizeUnit: hasSize ? _unit : null,
              clearSizeUnit: !hasSize,
            );
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.initial != null;
    final unitPrice = _unitPriceText();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  editing ? 'Editar ítem' : 'Agregar ítem',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            editing
                ? 'El detalle viaja con el ítem hasta el historial'
                : 'Todo es opcional salvo nombre y precio',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // Nombre.
          TextField(
            controller: _nameCtrl,
            autofocus: !editing && widget.presetName == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Producto'),
          ),
          const SizedBox(height: 8),
          // Precio + moneda.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Precio unitario',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CurrencySelect(
                value: _currency,
                onChanged: (c) => setState(() => _currency = c),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Cantidad.
          Row(
            children: [
              Text(
                'CANTIDAD',
                style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => setState(
                  () => _qtyCtrl.text = '${(_qty - 1).clamp(1, 999)}',
                ),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.remove_circle_outline, size: 20),
                ),
              ),
              // Ancho elástico 52–72: a textScale >=1.3 «999» tabular se
              // recortaba dentro de los 52 px fijos (fix a11y).
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52, maxWidth: 72),
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: VeText.displayNum(14, color: scheme.onSurface),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              InkWell(
                onTap: () => setState(
                  () => _qtyCtrl.text = '${(_qty + 1).clamp(1, 999)}',
                ),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.add_circle_outline, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tienda (autocompletado con las tiendas del libro).
          StoreAutocompleteField(
            stores: widget.store.stores,
            initialValue: _storeName,
            onChanged: (v) => setState(() => _storeName = v),
          ),
          const SizedBox(height: 8),
          // Código de barras (a mano o escaneado con ROI).
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Código de barras (opcional)',
                    prefixIcon: Icon(Icons.qr_code_2, size: 17),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _scanBarcode,
                tooltip: 'Escanear código',
                icon: const Icon(Icons.qr_code_scanner, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Peso / tamaño de la presentación.
          Text(
            'PESO / TAMAÑO',
            style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              ChipTag(
                'Sin peso',
                selected: _mode == _SizeMode.none,
                onTap: () => setState(() => _mode = _SizeMode.none),
              ),
              ChipTag(
                'Peso (g · kg)',
                selected: _mode == _SizeMode.weight,
                onTap: () => setState(() {
                  _mode = _SizeMode.weight;
                  _unit = _unit == 'l' || _unit == 'ml' ? 'g' : _unit;
                }),
              ),
              ChipTag(
                'Volumen (ml · L)',
                selected: _mode == _SizeMode.volume,
                onTap: () => setState(() {
                  _mode = _SizeMode.volume;
                  _unit = _unit == 'g' || _unit == 'kg' ? 'ml' : _unit;
                }),
              ),
            ],
          ),
          if (_mode != _SizeMode.none) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sizeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _mode == _SizeMode.weight
                          ? 'Contenido (600)'
                          : 'Contenido (500)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final u
                        in (_mode == _SizeMode.weight
                            ? const ['g', 'kg']
                            : const ['ml', 'l']))
                      ChipTag(
                        u,
                        selected: _unit == u,
                        onTap: () => setState(() => _unit = u),
                      ),
                  ],
                ),
              ],
            ),
          ],
          // Precio por unidad de compra (solo si size > 0 y precio > 0).
          if (unitPrice != null) ...[
            const SizedBox(height: 10),
            ReadWindow(
              semanticLabel: 'Precio por unidad de compra',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      unitPrice,
                      style: VeText.displayNum(16, color: scheme.onSurface),
                    ),
                  ),
                  Text(
                    'por unidad de compra',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Acción primaria única de la zona.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 16),
              label: Text(editing ? 'Guardar cambios' : 'Agregar a la lista'),
            ),
          ),
        ],
      ),
    );
  }
}

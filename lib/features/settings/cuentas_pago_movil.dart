// ─── Cuentas y Pago Móvil (v23 · comparativa CalculaYa 1.1.0) ─────────────
/// Cuentas propias de cobro: banco · tipo · número · CI · teléfono (máx 4).
/// Candado biométrico OPT-IN (default OFF) con el servicio existente; el
/// botón «Pago Móvil» del Conversor arma el mensaje de cobro con el monto
/// en bolívares y estos datos. Dato sensible: solo en el teléfono
/// (allowBackup=false desde v20.4).
part of 'settings_screen.dart';

/// Sección de Ajustes: lista de cuentas + alta en hoja + candado biométrico.
class CuentasPagoMovil extends ConsumerStatefulWidget {
  const CuentasPagoMovil({super.key});

  @override
  ConsumerState<CuentasPagoMovil> createState() => _CuentasPagoMovilState();
}

class _CuentasPagoMovilState extends ConsumerState<CuentasPagoMovil> {
  /// Candado vivo: false hasta que la huella (si está pedida) abra.
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    // Como main.dart (§12): el servicio se instancia aquí — no es estado,
    // es un puente a local_auth.
    final biometric = BiometricService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VeEyebrow(child: Text('CUENTAS Y PAGO MÓVIL')),
        _VeSettingsCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guarda tus datos de cobro una vez y comparte el Pago Móvil desde el Conversor. Todo queda en este teléfono.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (!store.settings.accountsBiometric || _abierta) ...[
                  for (final a in store.data.accounts) _AccountTile(account: a),
                  if (store.data.accounts.isEmpty)
                    _EmptyAccounts(onAdd: () => _abrirAlta(context, store))
                  else if (store.data.accounts.length < AppStore.kMaxAccounts)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: VeBtn(
                        variant: VeBtnVariant.ghost,
                        size: VeBtnSize.sm,
                        icon: LucideIcons.plus,
                        onPressed: () => _abrirAlta(context, store),
                        child: const Text('Agregar cuenta'),
                      ),
                    ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Pedir huella para ver mis cuentas',
                      style: TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      'Opcional. El candado de la app ya protege todo.',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    value: store.settings.accountsBiometric,
                    onChanged: (v) async {
                      if (v) {
                        final ok = await biometric.authenticate(
                          reason: 'Activar el candado de tus cuentas',
                        );
                        if (!ok) return;
                      }
                      store.setAccountsBiometric(v);
                      setState(() => _abierta = !v || true);
                    },
                  ),
                ] else
                  // Puerta biométrica: mismo patrón que la puerta de marca
                  // al abrir la app (§12) — sin soporte no bloquea.
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Icon(
                          LucideIcons.fingerprint,
                          size: 30,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tus cuentas están bajo huella',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        VeBtn(
                          variant: VeBtnVariant.secondary,
                          icon: LucideIcons.fingerprint,
                          onPressed: () async {
                            final ok = await biometric.authenticate(
                              reason: 'Ver tus cuentas y datos de cobro',
                            );
                            if (ok) setState(() => _abierta = true);
                          },
                          child: const Text('Desbloquear'),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Alta de cuenta: hoja con banco (lista), tipo, número, CI y teléfono.
  /// Validación SUAVE: avisos cuando algo luce raro, jamás bloqueo (la
  /// longitud real varía por banco — hallazgo goldfish).
  Future<void> _abrirAlta(BuildContext context, AppStore store) async {
    final labelCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String bank = kVkBanks.first;
    String type = 'corriente';
    // v23.3 (pez 2-a P0-1): alta con el patrón COMPLETO del kit —
    // showVeSheet (radio 14, asa, cabecera 48 + ✕), VeField/VeInput/
    // VeSelect/VeSegmented y pie con VeBtn. Antes: modal crudo de radio 20
    // con DropdownButtonFormField, SegmentedButton Material y TextButton/
    // FilledButton — otra piel de hoja para el mismo flujo.
    final ok = await showVeSheet<bool>(
      context: context,
      title: 'Nueva cuenta de cobro',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VeField(
                  label: 'Nombre (opcional)',
                  hint: 'Cómo la reconoces: «Principal», «Zelle»…',
                  child: VeInput(
                    controller: labelCtrl,
                    maxLength: 18,
                    placeholder: 'Cuenta principal',
                    semantic: 'Nombre de la cuenta',
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Titular (nombre completo)',
                  child: VeInput(
                    controller: holderCtrl,
                    maxLength: 40,
                    placeholder: 'Como aparece en el banco',
                    semantic: 'Titular de la cuenta',
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Banco',
                  child: VeSelect<String>(
                    value: bank,
                    semantic: 'Banco',
                    options: [
                      for (final b in kVkBanks)
                        VeSelectOption(
                          value: b,
                          label: b,
                          leading: BankBadge(bank: b, size: 20),
                        ),
                    ],
                    onChanged: (v) => setSheet(() => bank = v),
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Tipo',
                  child: VeSegmented<String>(
                    value: type,
                    onChanged: (v) => setSheet(() => type = v),
                    segments: const [
                      VeSegment(value: 'corriente', label: 'Corriente'),
                      VeSegment(value: 'ahorro', label: 'Ahorro'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Número de cuenta',
                  hint: 'Suele tener 20 dígitos',
                  child: VeInput(
                    controller: numberCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 20,
                    placeholder: '20 dígitos',
                    semantic: 'Número de cuenta',
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Cédula',
                  child: VeInput(
                    controller: docCtrl,
                    maxLength: 10,
                    placeholder: 'V12345678',
                    semantic: 'Cédula',
                  ),
                ),
                const SizedBox(height: 10),
                VeField(
                  label: 'Teléfono',
                  child: VeInput(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    placeholder: '04141234567',
                    semantic: 'Teléfono',
                  ),
                ),
              ],
            ),
          ),
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
      final number = numberCtrl.text.trim();
      final docId = docCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      // Suaves y simétricas (diseño P4): cuenta 20 · CI 5-9 con la letra
      // fuera de la cuenta · teléfono 11 — un solo snackbar junta los
      // avisos y el guardado NUNCA se bloquea (la longitud real varía por
      // banco — hallazgo goldfish).
      final avisos = pagoMovilSoftWarnings(
        number: number,
        docId: docId,
        phone: phone,
      );
      if (avisos.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ojo: ${avisos.join(' · ')}.')));
      }
      store.addAccount(
        PayAccount(
          id: store.newId(),
          bank: bank,
          type: type,
          number: number,
          docId: docId,
          phone: phone,
          label: labelCtrl.text.trim(),
          holderName: holderCtrl.text.trim(),
        ),
      );
    }
    // La hoja resuelve su futuro ANTES de terminar la animación de
    // salida: los campos siguen pintándose unos ms más y botar los
    // controllers aquí los mataba a mitad de fade («used after being
    // disposed», cazado por el test del alta). Viven hasta que el texto
    // deje de pintarse.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      labelCtrl.dispose();
      holderCtrl.dispose();
      numberCtrl.dispose();
      docCtrl.dispose();
      phoneCtrl.dispose();
    });
  }
}

/// Estado vacío de cuentas (v27): una tarjeta con la puerta de alta.
class _EmptyAccounts extends ConsumerWidget {
  const _EmptyAccounts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.landmark, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            'Aún no tienes cuentas',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Guarda tu banco, número, cédula y teléfono una vez. El Conversor '
            'arma el mensaje de cobro por ti.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          VeBtn(
            variant: VeBtnVariant.primary,
            size: VeBtnSize.sm,
            icon: LucideIcons.plus,
            onPressed: onAdd,
            child: const Text('Agregar cuenta'),
          ),
        ],
      ),
    );
  }
}

/// Fila de cuenta (v27): insignia del banco, alias o banco, número y un
/// menú con las tres acciones que importan: cuenta principal, copiar datos
/// y borrar. Toda la fila respira; el blanco de la estrella es de 44 px.
class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final PayAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BankBadge(bank: account.bank, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (account.holderName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    account.holderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${account.bank} · ${account.typeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'N.º ${account.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (account.docId.isNotEmpty || account.phone.isNotEmpty)
                  Text(
                    [
                      if (account.docId.isNotEmpty) 'CI ${account.docId}',
                      if (account.phone.isNotEmpty) 'Tel. ${account.phone}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: account.isDefault
                ? 'Cuenta principal'
                : 'Marcar ${account.displayLabel} como cuenta principal',
            child: IconButton(
              tooltip: account.isDefault
                  ? 'Cuenta principal'
                  : 'Marcar como principal',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                account.isDefault
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                size: 20,
                color: account.isDefault ? ink.warn : scheme.onSurfaceVariant,
              ),
              onPressed: account.isDefault
                  ? null
                  : () => store.setDefaultAccount(account.id),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Más acciones',
            iconSize: 18,
            onSelected: (v) {
              if (v == 'copy') {
                final text = [
                  account.displayLabel,
                  '${account.bank} · ${account.typeLabel}',
                  'N.º ${account.number}',
                  if (account.docId.isNotEmpty) 'CI ${account.docId}',
                  if (account.phone.isNotEmpty) 'Tel. ${account.phone}',
                ].join('\n');
                copiarAlPortapapeles(
                  context,
                  text,
                  'Datos de la cuenta copiados',
                );
              } else if (v == 'delete') {
                store.removeAccount(account.id);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Copiar datos')),
              PopupMenuItem(value: 'delete', child: Text('Borrar cuenta')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Avisos SUAVES de datos de cobro (diseño P4, simétricos por campo):
/// cuenta 20 dígitos · cédula 5-9 (la letra no cuenta) · teléfono 11.
/// Vacío no avisa; espacios y guiones no son dígitos. Pura y sin UI —
/// el alta la junta en UN snackbar y el guardado jamás se bloquea.
List<String> pagoMovilSoftWarnings({
  required String number,
  required String docId,
  required String phone,
}) {
  int digitos(String s) => s.replaceAll(RegExp('[^0-9]'), '').length;
  final avisos = <String>[];
  final nCuenta = digitos(number);
  if (number.isNotEmpty && nCuenta != 20) {
    avisos.add(
      'la cuenta tiene $nCuenta dígitos, no 20. Revisa que esté completa',
    );
  }
  final nCi = digitos(docId);
  if (docId.isNotEmpty && (nCi < 5 || nCi > 9)) {
    avisos.add(
      'la cédula tiene $nCi dígitos, no entre 5 y 9. Revisa la letra y '
      'el número',
    );
  }
  final nTel = digitos(phone);
  if (phone.isNotEmpty && nTel != 11) {
    avisos.add(
      'el teléfono tiene $nTel dígitos, no 11. Revisa que esté completo',
    );
  }
  return avisos;
}

/// Mensaje de cobro por Pago Móvil (compartible): monto es-VE + datos.
/// Formato plano, sin marcas — lo pega cualquier chat.
String pagoMovilMessage({
  required double montoBs,
  required PayAccount account,
}) {
  final buf = StringBuffer('Pago Móvil · Bs ${fmtNum(montoBs, decimals: 2)}\n');
  if (account.holderName.trim().isNotEmpty) {
    buf.writeln('Titular: ${account.holderName.trim()}');
  }
  buf.writeln('Banco: ${account.bank}');
  buf.writeln('Cuenta ${account.typeLabel.toLowerCase()}: ${account.number}');
  if (account.docId.isNotEmpty) buf.writeln('CI: ${account.docId}');
  if (account.phone.isNotEmpty) buf.writeln('Teléfono: ${account.phone}');
  return buf.toString().trimRight();
}

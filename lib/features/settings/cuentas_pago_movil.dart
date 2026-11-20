// ─── Cuentas y Pago Móvil (v23 · comparativa CalculaYa 1.1.0) ─────────────
/// Cuentas propias de cobro: banco · tipo · número · CI · teléfono (máx 4).
/// Candado biométrico OPT-IN (default OFF) con el servicio existente; el
/// botón «Pago Móvil» del Conversor arma el mensaje de cobro con el monto
/// en bolívares y estos datos. Dato sensible: solo en el teléfono
/// (allowBackup=false desde v20.4).
part of 'settings_screen.dart';

/// Sección de Ajustes: lista de cuentas + alta en hoja + candado biométrico.
class CuentasPagoMovil extends StatefulWidget {
  const CuentasPagoMovil({super.key});

  @override
  State<CuentasPagoMovil> createState() => _CuentasPagoMovilState();
}

class _CuentasPagoMovilState extends State<CuentasPagoMovil> {
  /// Candado vivo: false hasta que la huella (si está pedida) abra.
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
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
                  'Tus datos de cobro para compartir el monto por Pago Móvil '
                  'desde el Conversor. Se guardan SOLO en este teléfono.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                if (!store.settings.accountsBiometric || _abierta) ...[
                  for (final a in store.data.accounts)
                    _AccountTile(account: a),
                  if (store.data.accounts.isEmpty)
                    Text(
                      'Sin cuentas todavía. Agrega una y el Conversor arma el '
                      'mensaje de cobro por ti.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (store.data.accounts.length < AppStore.kMaxAccounts)
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
                      'Opcional — el candado de la app ya protege todo',
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
    final numberCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String bank = kVkBanks.first;
    String type = 'corriente';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nueva cuenta de cobro',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: bank,
                  decoration: const InputDecoration(
                    labelText: 'Banco',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final b in kVkBanks)
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (v) => setSheet(() => bank = v ?? bank),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'corriente', label: Text('Corriente')),
                    ButtonSegment(value: 'ahorro', label: Text('Ahorro')),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) =>
                      setSheet(() => type = s.first),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: numberCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: 'Número de cuenta',
                    hintText: '20 dígitos',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: docCtrl,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Cédula (ej. V12345678)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '04141234567',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok == true) {
      final number = numberCtrl.text.trim();
      // Suaves: avisos en pantalla, guardado siempre posible.
      if (number.isNotEmpty && number.length != 20 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ojo: la cuenta tiene ${number.length} dígitos, no 20 — '
              'revisa que esté completa.',
            ),
          ),
        );
      }
      store.addAccount(
        PayAccount(
          id: store.newId(),
          bank: bank,
          type: type,
          number: number,
          docId: docCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
        ),
      );
    }
    numberCtrl.dispose();
    docCtrl.dispose();
    phoneCtrl.dispose();
  }
}

/// Fila de cuenta: banco + tipo, número (monoespaciada), CI y teléfono.
class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final PayAccount account;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account.bank} · ${account.typeLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'N.º ${account.number}'
                  '${account.docId.isEmpty ? '' : ' · CI ${account.docId}'}'
                  '${account.phone.isEmpty ? '' : ' · ${account.phone}'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => store.removeAccount(account.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje de cobro por Pago Móvil (compartible): monto es-VE + datos.
/// Formato plano, sin marcas — lo pega cualquier chat.
String pagoMovilMessage({
  required double montoBs,
  required PayAccount account,
}) {
  final buf = StringBuffer('Pago Móvil — Bs ${fmtNum(montoBs, decimals: 2)}\n');
  buf.writeln('Banco: ${account.bank}');
  buf.writeln('Cuenta ${account.typeLabel.toLowerCase()}: ${account.number}');
  if (account.docId.isNotEmpty) buf.writeln('CI: ${account.docId}');
  if (account.phone.isNotEmpty) buf.writeln('Teléfono: ${account.phone}');
  return buf.toString().trimRight();
}

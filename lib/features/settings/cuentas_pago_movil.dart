// ─── Cuentas y cobro (v30 · H-43: el tipo decide los datos) ─────────────────
/// Cuentas propias de cobro por TIPO: Pago Móvil (banco + cédula +
/// teléfono) · Transferencia (banco + tipo + número de 20 + cédula) ·
/// Zelle (titular + email/teléfono US). El alta elige el tipo PRIMERO
/// (picker de 44 px) y muestra SOLO sus campos; la fila, la copia, el
/// mensaje de cobro y la tarjeta 1080×1080 renderizan EXACTAMENTE las
/// líneas del tipo (`PayAccount.dataLines`, única fuente). Candado
/// biométrico OPT-IN (default OFF). Dato sensible: solo en el teléfono
/// (allowBackup=false desde v20.4).
part of 'settings_screen.dart';

/// Sección de Ajustes: lista de cuentas + alta por tipo + candado.
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

    // v32: GUI plana — el intro lo pone el encabezado de la sección en la
    // pantalla principal; aquí solo cuentas, alta y candado, sin caja.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          const SizedBox(height: 8),
          _FilaSwitch(
            titulo: 'Pedir huella para ver mis cuentas',
            sub: 'Opcional. El candado de la app ya protege todo.',
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
          // al abrir la app (§12) — sin soporte no bloquea. v32: centrado.
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
                    fontSize: 13.5,
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
    );
  }

  /// Alta de cuenta por TIPO (v30 · H-43): el picker de 44 px elige
  /// PRIMERO y la hoja muestra SOLO los campos de ese tipo. R-30c: si
  /// falta algo, la hoja NO se cierra — el snackbar dice QUÉ falta por
  /// tipo. R-30b: al guardar, los campos cruzados se condicionan (una
  /// transferencia jamás guarda teléfono de pago móvil).
  Future<void> _abrirAlta(BuildContext context, AppStore store) async {
    final labelCtrl = TextEditingController();
    final holderCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final docCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var kind = PayAccountKind.pagoMovil;
    var bank = kVkBanks.first;
    var type = 'corriente';

    // La candidata EN VIVO de la hoja: solo los campos de su tipo.
    PayAccount candidate(String id) => PayAccount(
      id: id,
      kind: kind,
      // R-30b: campos condicionados — el tipo decide qué existe.
      bank: kind == PayAccountKind.zelle ? '' : bank,
      type: kind == PayAccountKind.transferencia ? type : 'corriente',
      number: kind == PayAccountKind.transferencia
          ? numberCtrl.text.trim()
          : '',
      docId: kind == PayAccountKind.zelle
          ? ''
          : docCtrl.text.trim(),
      phone: switch (kind) {
        PayAccountKind.pagoMovil => phoneCtrl.text.trim(),
        PayAccountKind.zelle => phoneCtrl.text.trim(),
        PayAccountKind.transferencia => '',
      },
      label: labelCtrl.text.trim(),
      // El titular solo existe en el Zelle (H-43) — condicionado al tipo.
      holderName: kind == PayAccountKind.zelle
          ? holderCtrl.text.trim()
          : '',
    );

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
                // ── El TIPO primero (H-43): picker de 44 px — el MISMO
                // control segmentado de fecha del Conversor.
                VeField(
                  label: 'Tipo de cobro',
                  child: VeSegmented<PayAccountKind>(
                    value: kind,
                    height: 44,
                    onChanged: (v) => setSheet(() => kind = v),
                    segments: const [
                      VeSegment(value: PayAccountKind.pagoMovil, label: 'Pago móvil'),
                      VeSegment(
                        value: PayAccountKind.transferencia,
                        label: 'Transferencia',
                      ),
                      VeSegment(value: PayAccountKind.zelle, label: 'Zelle'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
                // ── SOLO los campos del tipo elegido.
                if (kind != PayAccountKind.zelle) ...[
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
                ],
                if (kind == PayAccountKind.transferencia) ...[
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
                ],
                if (kind == PayAccountKind.zelle) ...[
                  VeField(
                    label: 'Titular (nombre completo)',
                    child: VeInput(
                      controller: holderCtrl,
                      maxLength: 40,
                      placeholder: 'Como aparece en Zelle',
                      semantic: 'Titular de la cuenta',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (kind != PayAccountKind.zelle) ...[
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
                ],
                if (kind == PayAccountKind.pagoMovil)
                  VeField(
                    label: 'Teléfono',
                    child: VeInput(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      placeholder: '04141234567',
                      semantic: 'Teléfono',
                    ),
                  )
                else if (kind == PayAccountKind.zelle)
                  VeField(
                    label: 'Correo o teléfono de EE. UU.',
                    child: VeInput(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 40,
                      placeholder: 'nombre@correo.com',
                      semantic: 'Correo o teléfono de Zelle',
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
                // R-30c: la validación vive AQUÍ — la hoja no se cierra con
                // datos incompletos y el snackbar dice qué falta por tipo.
                onPressed: () {
                  final falta = candidate('x').missingFields;
                  if (falta.isNotEmpty) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Falta ${falta.join(' · falta ')}.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.of(sheetCtx).pop(true);
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final nueva = candidate(store.newId());
      // Avisos SUAVES por tipo (nunca bloqueo: la longitud real varía por
      // banco; el correo/US se corrige al vuelo).
      final avisos = accountSoftWarnings(nueva);
      if (avisos.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ojo: ${avisos.join(' · ')}.')));
      }
      store.addAccount(nueva);
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

/// Estado vacío de cuentas (v30): una tarjeta con la puerta de alta.
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
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            'Elige el tipo — pago móvil, transferencia o Zelle — y guarda sus '
            'datos una vez. El Conversor arma el cobro por ti.',
            style: TextStyle(
              fontSize: 13.5,
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

/// Fila de cuenta (v30 · H-43): la insignia del banco (o el monograma del
/// Zelle), el título del tipo y las líneas EXACTAS del tipo debajo —
/// `dataLines` es la única fuente. Menú de tres acciones: cuenta
/// principal, copiar datos (las mismas líneas) y borrar.
class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final PayAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Zelle no tiene banco: monograma propio (púrpura de la marca).
          account.kind == PayAccountKind.zelle
              ? _ZelleBadge(size: 38)
              : BankBadge(bank: account.bank, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    account.displayLabel,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Las líneas EXACTAS del tipo (H-43): nada de campos
                // cruzados — la transferencia no pinta «Teléfono».
                for (final (k, v) in account.dataLines)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$k: $v',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.onSurfaceVariant,
                      ),
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
            child: VeIconBtn(
              icon: account.isDefault
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              label: account.isDefault
                  ? 'Cuenta principal'
                  : 'Marcar como principal',
              onTap: account.isDefault
                  ? null
                  : () => store.setDefaultAccount(account.id),
            ),
          ),
          // v28 · acciones INLINE (sin menú flotante): copiar y borrar son
          // botones de icono identificables al lado de la cuenta. v32: al
          // tamaño común del kit (36/17).
          VeIconBtn(
            icon: Icons.copy_rounded,
            label: 'Copiar datos de la cuenta',
            onTap: () {
              // La copia = título + las líneas del tipo (misma fuente).
              final text = [
                account.displayLabel,
                for (final (k, v) in account.dataLines) '$k: $v',
              ].join('\n');
              copiarAlPortapapeles(
                context,
                text,
                'Datos de la cuenta copiados',
              );
            },
          ),
          VeIconBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Borrar cuenta',
            danger: true,
            onTap: () => store.removeAccount(account.id),
          ),
        ],
      ),
    );
  }
}

/// Monograma del Zelle (cuentas sin banco): la «Z» de la marca sobre
/// púrpura, el mismo hueco que ocupa una insignia de banco.
class _ZelleBadge extends StatelessWidget {
  const _ZelleBadge({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Zelle',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: SizedBox(
          width: size,
          height: size,
          child: const ColoredBox(
            color: Color(0xFF6D1EDB),
            child: Center(
              child: Text(
                'Z',
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avisos SUAVES de datos de cobro POR TIPO (v30 · H-43, sustituye al shim
/// `pagoMovilSoftWarnings`): transferencia → cuenta de 20 dígitos y cédula
/// 5-9; pago móvil → cédula 5-9 y teléfono 11; Zelle → correo con dominio
/// o teléfono de EE. UU. de 10. Vacío no avisa (eso es validación dura del
/// alta); espacios y guiones no son dígitos. Pura y sin UI — el alta la
/// junta en UN snackbar y el guardado jamás se bloquea.
List<String> accountSoftWarnings(PayAccount a) {
  int digitos(String s) => s.replaceAll(RegExp('[^0-9]'), '').length;
  final avisos = <String>[];

  void cedula(String docId) {
    final n = digitos(docId);
    if (docId.isNotEmpty && (n < 5 || n > 9)) {
      avisos.add(
        'la cédula tiene $n dígitos, no entre 5 y 9. Revisa la letra y '
        'el número',
      );
    }
  }

  switch (a.kind) {
    case PayAccountKind.transferencia:
      final nCuenta = digitos(a.number);
      if (a.number.isNotEmpty && nCuenta != 20) {
        avisos.add(
          'la cuenta tiene $nCuenta dígitos, no 20. Revisa que esté completa',
        );
      }
      cedula(a.docId);
    case PayAccountKind.pagoMovil:
      cedula(a.docId);
      final nTel = digitos(a.phone);
      if (a.phone.isNotEmpty && nTel != 11) {
        avisos.add(
          'el teléfono tiene $nTel dígitos, no 11. Revisa que esté completo',
        );
      }
    case PayAccountKind.zelle:
      final c = a.phone.trim();
      if (c.contains('@')) {
        if (!RegExp(r'@[^.@\s]+\.[^.@\s]+').hasMatch(c)) {
          avisos.add('el correo no tiene dominio completo. Revísalo');
        }
      } else if (c.isNotEmpty) {
        // Teléfono US: 10 dígitos (local) o 11 (con el +1 de país).
        final n = digitos(c);
        if (n != 10 && n != 11) {
          avisos.add(
            'el teléfono de EE. UU. tiene $n dígitos, no 10. Revísalo',
          );
        }
      }
  }
  return avisos;
}

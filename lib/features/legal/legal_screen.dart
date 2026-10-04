/// ─── Legal: licencias de plugins y privacidad [Linear Edition] ───────
library;

import \'package:flutter/material.dart\';
import \'package:lucide_icons_flutter/lucide_icons.dart\';
import \'package:shadcn_ui/shadcn_ui.dart\';

import \'../../widgets/ve/ve.dart\';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          const VeAmbient(opacity: 0.35, child: SizedBox.expand()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── AppBar Linear minimalista ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        VeBtn(
                          variant: VeBtnVariant.ghost,
                          size: VeBtnSize.icon,
                          icon: LucideIcons.arrowLeft,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 4),
                        Text(\'Licencias y privacidad\',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.foreground,
                            )),
                        const Spacer(),
                        VeBadge(
                          label: \'Offline-first\',
                          variant: VeBadgeVariant.muted,
                          icon: LucideIcons.shieldCheck,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Header Hero ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VeEyebrow(\'VALORAVE · LEGAL & PRIVACIDAD\'),
                        const SizedBox(height: 8),
                        VeTitle(\'Tus datos.\nEn tu teléfono.\', size: 28),
                        const SizedBox(height: 10),
                        Text(
                          \'Sin cuentas, sin telemetría, sin nube. Filosofía offline-first explicada sin letra pequeña.\',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Contenido ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList.list(
                    children: [
                      // 1 · PRIVACIDAD
                      VeCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.border),
                                  ),
                                  child: Icon(LucideIcons.shieldCheck,
                                      size: 18, color: theme.colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(\'Privacidad\',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: theme.colorScheme.foreground)),
                                    Text(\'Cero telemetría · Cero cuentas\',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.colorScheme.mutedForeground)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: theme.colorScheme.border),
                            const SizedBox(height: 14),
                            Text(
                              \'ValoraVE no tiene cuentas, no te pide datos personales y no \'
                              \'envía nada a servidores propios. Todo lo que registras —productos, \'
                              \'compras, movimientos, fotos de tickets— vive en tu teléfono. \'
                              \'Los respaldos son archivos JSON tuyos: los exportas y los \'
                              \'importas donde quieras.\n\n\'
                              \'Para las tasas, la app consulta en directo fuentes públicas \'
                              \'(ve.dolarapi.com, pydolarve.org, co.dolarapi.com, mx.dolarapi.com, \'
                              \'br.dolarapi.com y respaldos de datos.gov.co y AwesomeAPI). \'
                              \'Esas consultas son anónimas: llevan la URL y nada más.\',
                              style: TextStyle(
                                  fontSize: 13, height: 1.7, color: theme.colorScheme.mutedForeground),
                            ),
                            const SizedBox(height: 14),
                            VeGroup(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  VeBadge(label: \'Sin tracking\', icon: LucideIcons.eyeOff, variant: VeBadgeVariant.muted),
                                  VeBadge(label: \'JSON local\', icon: LucideIcons.hardDrive, variant: VeBadgeVariant.muted),
                                  VeBadge(label: \'APIs públicas\', icon: LucideIcons.globe, variant: VeBadgeVariant.muted),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 2 · SALA EN VIVO
                      VeCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.border),
                                  ),
                                  child: const Icon(LucideIcons.usersRound,
                                      size: 18, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(\'Sala en vivo\',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: theme.colorScheme.foreground)),
                                    Text(\'Sincronización P2P privada\',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.colorScheme.mutedForeground)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: theme.colorScheme.border),
                            const SizedBox(height: 14),
                            Text(
                              \'La sala de compras usa tres caminos: un servidor socket.io que \'
                              \'TÚ decides (viene vacío: configuras la URL en Ajustes), \'
                              \'Google Nearby Connections (WiFi-Direct/Bluetooth, sin internet) \'
                              \'y WiFi local entre pares. El código de la sala es lo único que \'
                              \'compartes; no hay registro.\',
                              style: TextStyle(
                                  fontSize: 13, height: 1.7, color: theme.colorScheme.mutedForeground),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.muted.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.colorScheme.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.radio, size: 14, color: theme.colorScheme.mutedForeground),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(\'3 transportes · 1 código de 6 letras · 0 usuarios registrados\',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: theme.colorScheme.mutedForeground)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3 · LICENCIAS
                      VeCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.muted,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.border),
                                  ),
                                  child: Icon(LucideIcons.scale,
                                      size: 18, color: theme.colorScheme.foreground),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(\'Licencias\',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            color: theme.colorScheme.foreground)),
                                    Text(\'Propiedad intelectual & OSS\',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme.colorScheme.mutedForeground)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Divider(height: 1, color: theme.colorScheme.border),
                            const SizedBox(height: 14),
                            Text(
                              \'App: ValoraVE — código propietario de su autor. \'
                              \'Tipografías: Inter (SIL OFL 1.1) y Space Grotesk (SIL OFL 1.1), \'
                              \'empaquetadas localmente para que la primera ejecución sin red \'
                              \'tipografíe igual. Plugins oficiales de pub.dev con su licencia \'
                              \'BSD/MIT correspondiente (Flutter, provider, hive, dio, \'
                              \'socket_io_client, flutter_local_notifications, syncfusion \'
                              \'community license, entre otros).\',
                              style: TextStyle(
                                  fontSize: 13, height: 1.7, color: theme.colorScheme.mutedForeground),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                VeBadge(label: \'Inter — OFL 1.1\', variant: VeBadgeVariant.outline),
                                const SizedBox(width: 6),
                                VeBadge(label: \'Space Grotesk — OFL 1.1\', variant: VeBadgeVariant.outline),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Footer sutil
                      Center(
                        child: Text(\'Hecho con privacidad en Venezuela · valorave.app\',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground.withOpacity(0.7))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

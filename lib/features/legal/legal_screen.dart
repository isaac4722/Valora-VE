/// ─── Legal: licencias de plugins y privacidad ───────────────────────────────
/// Sin cuentas, sin telemetría, sin nube: los datos viven en el teléfono.
/// Fuentes de tasas públicas consultadas en directo (dolarapi.com y
/// respaldos), nunca a través de servidores propios de terceros.
library;

import 'package:flutter/material.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Licencias y privacidad')),
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Privacidad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'ValoraVE no tiene cuentas, no te pide datos personales y no '
                  'envía nada a servidores propios. Todo lo que registras —productos, '
                  'compras, movimientos, fotos de tickets— vive en tu teléfono. '
                  'Los respaldos son archivos JSON tuyos: los exportas y los '
                  'importas donde quieras.\n\n'
                  'Para las tasas, la app consulta en directo fuentes públicas '
                  '(ve.dolarapi.com, pydolarve.org, co.dolarapi.com, mx.dolarapi.com, '
                  'br.dolarapi.com y respaldos de datos.gov.co y AwesomeAPI). '
                  'Esas consultas son anónimas: llevan la URL y nada más.',
                  style: TextStyle(fontSize: 13, height: 1.55, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sala en vivo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'La sala de compras usa tres caminos: un servidor socket.io que '
                  'TÚ decides (viene vacío: configuras la URL en Ajustes), '
                  'Google Nearby Connections (WiFi-Direct/Bluetooth, sin internet) '
                  'y WiFi local entre pares. El código de la sala es lo único que '
                  'compartes; no hay registro.',
                  style: TextStyle(fontSize: 13, height: 1.55, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Licencias', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'App: ValoraVE — código propietario de su autor. '
                  'Tipografías: Inter (SIL OFL 1.1) y Space Grotesk (SIL OFL 1.1), '
                  'empaquetadas localmente para que la primera ejecución sin red '
                  'tipografíe igual. Plugins oficiales de pub.dev con su licencia '
                  'BSD/MIT correspondiente (Flutter, provider, hive, dio, '
                  'socket_io_client, flutter_local_notifications, syncfusion '
                  'community license, entre otros).',
                  style: TextStyle(fontSize: 13, height: 1.55, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

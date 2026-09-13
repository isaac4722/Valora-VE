/// ─── Trabajo en 2º plano (workmanager) ──────────────────────────────────────
/// · refresco horario de tasas (rates-sync del SW web) — escribe widgets y
///   dispara metas de precio aunque la app esté cerrada.
/// · respaldo semanal automático con retención 4 (mejora 7).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/store.dart';
import 'alerts.dart';
import 'notifications.dart';
import 'widget_service.dart';

const kFetchTask = 've.valorave.rates-sync';
const kBackupTask = 've.valorave.backup-weekly';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final store = AppStore();
    await store.hydrate();
    switch (task) {
      case kFetchTask:
        // El board real se refresca con el motor completo (board.dart) que
        // requiere dio: aquí solo el núcleo tolerante (sin tocar UI).
        try {
          final rates = await fetchBoardSimple();
          if (rates.isNotEmpty) {
            await WidgetService.updateBcv(
              bcv: rates['ves-bcv'],
              parallel: rates['ves-parallel'],
            );
          }
        } catch (_) {/* sin red: nada */}
        // Recordatorio diario con app cerrada (precisión horaria; el claim
        // por día en AlertEngine evita duplicar con el camino in-app) +
        // METAS DE PRECIO de producto en 2º plano (17.7 · price_targets):
        // evalúa contra el último registro guardado y avisa por el canal
        // price_targets; el persist escribe al centro (Hive) y se ve al
        // abrir la app.
        try {
          final prefs = await SharedPreferences.getInstance();
          final engine = AlertEngine(prefs);
          engine.reminderCheck(NotificationsService(), now: DateTime.now());
          engine.checkProductTargets(
            store: store,
            notifs: NotificationsService(),
            persist: (kind, title, body) =>
                store.pushNotification(kind: kind, title: title, body: body),
          );
        } catch (_) {/* sin canal de notifs: no bloquea */}
        return true;
      case kBackupTask:
        await autoBackup(store);
        return true;
    }
    return false;
  });
}

/// Fetch mínimo en background (evita el árbol completo por tamaño).
Future<Map<String, double>> fetchBoardSimple() async {
  final out = <String, double>{};
  try {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    final req = await client.getUrl(Uri.parse('https://ve.dolarapi.com/v1/dolares'));
    final res = await req.close();
    if (res.statusCode == 200) {
      final body = await res.transform(utf8.decoder).join();
      final rows = jsonDecode(body) as List;
      for (final row in rows.whereType<Map>()) {
        final fuente = '${row['fuente'] ?? ''}';
        final rate = (row['promedio'] as num?)?.toDouble() ?? 0;
        if (fuente == 'oficial' && rate > 0) out['ves-bcv'] = rate;
        if (fuente == 'paralelo' && rate > 0) out['ves-parallel'] = rate;
      }
    }
  } catch (_) {}
  return out;
}

/// Respaldo semanal con retención de 4 archivos.
Future<void> autoBackup(AppStore store) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}/backups');
    await backups.create(recursive: true);
    final name =
        'backup-valorave-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    await File('${backups.path}/$name')
        .writeAsString(const JsonEncoder.withIndent('  ').convert({
      'version': 12,
      'data': store.data.toJson(),
      'savedAt': DateTime.now().toIso8601String(),
    }));
    // Retención: deja los 4 más recientes.
    final files = (await backups.list().toList())
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in files.skip(4)) {
      await f.delete();
    }
  } catch (_) {/* no bloquea */}
}

Future<void> initWorkmanager() async {
  await Workmanager().initialize(callbackDispatcher);
  // Cada hora: refresco + widget + alertas de metas (rates-sync).
  await Workmanager().registerPeriodicTask(
    kFetchTask,
    kFetchTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  // Semanal: respaldo automático (retención 4).
  await Workmanager().registerPeriodicTask(
    kBackupTask,
    kBackupTask,
    frequency: const Duration(days: 7),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

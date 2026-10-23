/// ─── Trabajo en 2º plano · stub de WEB ──────────────────────────────────────
/// El navegador no tiene workmanager ni filesystem: fetchBoardSimple
/// devuelve vacío (el tablero de la web se refresca en primer plano),
/// autoBackup no escribe nada y initWorkmanager no registra tareas.
/// El `callbackDispatcher` existe para compilar idéntico; en web nadie lo
/// invoca (el dispatch es nativo).
library;

import '../data/store.dart';

const kFetchTask = 've.valorave.rates-sync';
const kBackupTask = 've.valorave.backup-weekly';

void callbackDispatcher() {}

/// En web el tablero vive del refresco en primer plano: vacío honesto.
Future<Map<String, double>> fetchBoardSimple() async => const {};

/// Sin filesystem en web: no hay respaldo semanal en disco.
Future<void> autoBackup(AppStore store) async {}

Future<void> initWorkmanager() async {}

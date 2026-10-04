/// ─── Servidor de nombres de isolate (hive_ce IsolatedHive) ─────────────────
///
/// hive_ce 2.20 exige que TODOS los isolates que tocan las cajas compartan
/// el mismo `IsolateNameServer`: así el isolate de Hive es UNO y las cajas
/// jamás abren el mismo archivo desde dos dueños (corrupción documentada).
///
/// `dart:isolate` expone el IsolateNameServer del proceso SOLO en la VM;
/// en web no existe (y en web no hay workmanager ni riesgo) — el stub
/// devuelve null/false y hive_ce simplemente crea su isolate normal.
library;

export 'ins_server_stub.dart'
    if (dart.library.io) 'ins_server_vm.dart';

/// Stub web del servidor de nombres: en web no hay workmanager ni segundo
/// isolate con acceso a las cajas — el lookup falla y hive_ce opera su
/// isolate propio (comportamiento idéntico al de hoy).
library;

import 'package:hive_ce/hive_ce.dart' show IsolateNameServer;

class SystemIsolateNameServer extends IsolateNameServer {
  const SystemIsolateNameServer();

  @override
  dynamic lookupPortByName(String name) => null;

  @override
  bool registerPortWithName(dynamic port, String name) => false;

  @override
  bool removePortNameMapping(String name) => false;
}

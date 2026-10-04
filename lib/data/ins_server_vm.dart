/// Implementación VM: el IsolateNameServer estático de dart:isolate es
/// visible desde TODO isolate del proceso — la app y el workmanager
/// registran/buscan el mismo puerto del isolate dueño de las cajas.
import 'dart:isolate' as dart;

import 'package:hive_ce/hive_ce.dart' show IsolateNameServer;

class SystemIsolateNameServer extends IsolateNameServer {
  const SystemIsolateNameServer();

  @override
  dynamic lookupPortByName(String name) =>
      dart.IsolateNameServer.lookupPortByName(name);

  @override
  bool registerPortWithName(dynamic port, String name) =>
      dart.IsolateNameServer.registerPortWithName(port as dart.SendPort, name);

  @override
  bool removePortNameMapping(String name) =>
      dart.IsolateNameServer.removePortNameMapping(name);
}

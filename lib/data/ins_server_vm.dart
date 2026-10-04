/// Implementación VM: el IsolateNameServer estático de dart:ui es visible
/// desde TODO isolate del proceso Flutter — la app y el workmanager
/// registran/buscan el mismo puerto del isolate dueño de las cajas.
///
/// (El IsolateNameServer del sistema vive en dart:ui, no en dart:isolate.)
library;

import 'dart:isolate' show SendPort;
import 'dart:ui' as ui;

import 'package:hive_ce/hive_ce.dart' show IsolateNameServer;

class SystemIsolateNameServer extends IsolateNameServer {
  const SystemIsolateNameServer();

  @override
  dynamic lookupPortByName(String name) => ui.IsolateNameServer.lookupPortByName(name);

  @override
  bool registerPortWithName(dynamic port, String name) =>
      ui.IsolateNameServer.registerPortWithName(port as SendPort, name);

  @override
  bool removePortNameMapping(String name) =>
      ui.IsolateNameServer.removePortNameMapping(name);
}

/// ─── TESTS · drain() del AlertEngine (fix TASK-32 · notificaciones en
/// 2º plano) ──────────────────────────────────────────────────────────────────
/// El worker de workmanager debe ESPERAR los show() en vuelo antes de
/// retornar; antes los futuros quedaban huérfanos y el engine moría sin
/// notificar (el aviso solo salía al abrir la app). drain() cubre ese hueco.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlertEngine.drain · worker en 2º plano (TASK-32)', () {
    test('reminderCheck encola el show y drain() lo espera (persist 1:1)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final engine = AlertEngine(prefs);
      engine.setReminderEnabled(true);
      engine.setReminderHour(9);

      final persist = <(NotifKind, String, String)>[];
      // Plugin ausente en el host de pruebas: show() se protege adentro y
      // completa — exactamente el caso del isolate de 2º plano sin canal.
      engine.reminderCheck(
        NotificationsService(),
        now: DateTime(2026, 9, 24, 9, 15),
        persist: (k, t, b) => persist.add((k, t, b)),
      );
      expect(persist, hasLength(1), reason: 'el claim del día pasó (1ª vez)');
      expect(persist.first.$1, NotifKind.reminder);

      // El drain DEBE completar sin colgar (antes: futuro huérfano).
      await engine.drain();
    });

    test('drain() es idempotente y con cola vacía completa al instante', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final engine = AlertEngine(await SharedPreferences.getInstance());
      await engine.drain();
      await engine.drain();
      expect(engine.drain(), completes);
    });

    test('claim por día: el mismo día no duplica avisos tras drain', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final engine = AlertEngine(prefs);
      engine.setReminderEnabled(true);
      engine.setReminderHour(9);

      final persist = <(NotifKind, String, String)>[];
      final notifs = NotificationsService();
      engine.reminderCheck(
        notifs,
        now: DateTime(2026, 9, 24, 9, 5),
        persist: (k, t, b) => persist.add((k, t, b)),
      );
      await engine.drain();
      engine.reminderCheck(
        notifs,
        now: DateTime(2026, 9, 24, 9, 55),
        persist: (k, t, b) => persist.add((k, t, b)),
      );
      await engine.drain();
      expect(persist, hasLength(1), reason: 'claim por día deduplica');
    });
  });
}

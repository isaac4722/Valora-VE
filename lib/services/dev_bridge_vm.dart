/// ─── Servidor de pruebas local · implementación VM (v21.6) ──────────────────
/// HttpServer de dart:io en 127.0.0.1 (SOLO loopback): el único camino
/// hacia este puerto desde fuera de la app es el servicio `tcp:<puerto>`
/// de ADB — exactamente como DevTools. Por eso el toggle vive en
/// Ajustes → Diagnóstico y en release arranca apagado.
///
/// Endpoints (JSON, es-VE en los mensajes):
///   GET /health                → estado de la app y contadores del store.
///   GET /test?scenario=cart    → siembra carrito multitienda (5 ítems).
///            ?scenario=products → siembra 3 productos del libro.
///            ?scenario=purchase → siembra 2 compras en el historial.
///   GET /erase                 → BORRA datos del usuario (carrito, compras,
///                                productos, transacciones, tiendas,
///                                plantillas, canasta) conservando ajustes y
///                                tablero. Exige cabecera x-valora-token.
///   GET /nav?to=/historial     → deep link interno (rutas en lista blanca).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/currencies.dart';
import '../core/models.dart';
import '../core/version.dart';
import '../data/store.dart';

class DevBridge {
  /// Puerto base: del 8090 hacia arriba busca hueco (tolerante — si todo
  /// está ocupado el servidor no arranca y la app sigue normal).
  static const int kBasePort = 8090;

  /// Claves de preferencias (SharedPreferences ya vive a nivel de app).
  static const String kPrefEnabled = 'valorave.dev-server';
  static const String kPrefToken = 'valorave.dev-token';

  /// Rutas navegables por /nav (lista blanca — el router tiene más rutas
  /// con parámetros, como /sala; solo se exponen las fijas de pestañas y
  /// push habituales del puente).
  static const Set<String> kNavRoutes = {
    '/',
    '/conversor',
    '/lista',
    '/productos',
    '/analisis',
    '/historial',
    '/ajustes',
    '/tickets',
  };

  static HttpServer? _server;
  static AppStore? _store;
  static String? _token;
  static GoRouter? _router;
  static final DateTime _bootedAt = DateTime.now();

  static bool get supported => true;
  static bool get running => _server != null;
  static int get port => _server?.port ?? 0;
  static String? get token => _token;
  static int get uptimeSec => DateTime.now().difference(_bootedAt).inSeconds;

  /// Vincula el router único (patrón QuickActions/DeepLink de ValoraApp)
  /// para que /nav pueda navegar sin BuildContext.
  static void bindRouter(GoRouter router) => _router = router;

  /// main.dart: arranca si debug, o si el dueño activó el toggle (prefs).
  /// Nunca lanza: una herramienta de depuración no puede tumbar el arranque.
  static Future<void> init({
    required AppStore store,
    required SharedPreferences prefs,
    bool debug = false,
  }) async {
    final enabled = debug || prefs.getBool(kPrefEnabled) == true;
    _token = prefs.getString(kPrefToken);
    if (!enabled) return;
    await start(store: store);
  }

  /// Busca puerto libre desde kBasePort y sirve. Devuelve true si quedó
  /// escuchando. [port] explícito (tests usan 0 = efímero).
  static Future<bool> start({required AppStore store, int? port}) async {
    await stop();
    _store = store;
    for (var p = port ?? kBasePort;
        p < (port != null ? port + 1 : kBasePort + 10);
        p++) {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, p);
        _server!.listen(_handle, onError: (_) {});
        return true;
      } catch (_) {
        _server = null; // puerto ocupado: prueba el siguiente
      }
    }
    return false;
  }

  static Future<void> stop() async {
    _server?.close(force: true);
    _server = null;
  }

  /// Token de sesión: se genera una sola vez y vive en prefs; Ajustes lo
  /// muestra para que el cliente del puente lo reenvíe en /erase.
  /// SIEMPRE sincroniza _token (también si ya existía en prefs): el
  /// servidor puede haber arrancado antes de que existiera la preferencia.
  static String ensureToken(SharedPreferences prefs) {
    final existing = prefs.getString(kPrefToken);
    final t = (existing != null && existing.isNotEmpty)
        ? existing
        : List.generate(
            8,
            (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
    prefs.setString(kPrefToken, t);
    _token = t;
    return t;
  }

  /// Fija el token directamente (rotación desde Ajustes y pruebas del
  /// puente sin pasar por SharedPreferences).
  static void setTokenForSession(String t) => _token = t;

  // ── HTTP ─────────────────────────────────────────────────────────────────
  static void _json(HttpRequest req, int status, Map<String, dynamic> body) {
    req.response.statusCode = status;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    req.response.close();
  }

  static Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      switch (path) {
        case '/health':
          return _json(req, 200, _health());
        case '/erase':
          return await _erase(req);
        case '/test':
          return await _test(req);
        case '/nav':
          return _nav(req);
        default:
          return _json(req, 404, {
            'ok': false,
            'error': 'Ruta desconocida: $path',
            'endpoints': ['/health', '/test', '/erase', '/nav'],
          });
      }
    } catch (e) {
      return _json(req, 500, {'ok': false, 'error': '$e'});
    }
  }

  static Map<String, dynamic> _health() {
    final s = _store!;
    return {
      'ok': true,
      'app': 'ValoraVE',
      'version': kAppVersionVisible,
      'mode': const bool.fromEnvironment('dart.vm.product')
          ? 'release'
          : 'debug',
      'port': port,
      'uptimeSec': uptimeSec,
      'cart': s.cart.length,
      'purchases': s.purchases.length,
      'products': s.products.length,
      'transactions': s.transactions.length,
      'stores': s.stores.length,
      'nav': _router != null,
    };
  }

  static Future<void> _erase(HttpRequest req) async {
    if (req.method != 'GET') {
      return _json(req, 405, {'ok': false, 'error': 'Solo GET'});
    }
    // /erase es destructivo: exige el token mostrado en Ajustes. Las otras
    // rutas quedan abiertas porque solo siembran o leen.
    if (_token == null || req.headers.value('x-valora-token') != _token) {
      return _json(req, 403, {
        'ok': false,
        'error': 'Token ausente o incorrecto (cabecera x-valora-token)',
      });
    }
    final s = _store!;
    final cleared = {
      'cart': s.cart.length,
      'purchases': s.purchases.length,
      'products': s.products.length,
      'transactions': s.transactions.length,
      'stores': s.stores.length,
      'templates': s.templates.length,
      'basket': s.data.basket.length,
    };
    // replaceAll (mismo mecanismo del respaldo): reset total conservando
    // tablero, tasas y ajustes del dueño — solo muere el dato de prueba.
    s.replaceAll(
      AppData(
        board: s.data.board,
        rateSource: s.data.rateSource,
        manualRates: s.data.manualRates,
        settings: s.data.settings,
      ),
    );
    return _json(req, 200, {'ok': true, 'cleared': cleared});
  }

  static Future<void> _test(HttpRequest req) async {
    if (req.method != 'GET') {
      return _json(req, 405, {'ok': false, 'error': 'Solo GET'});
    }
    final scenario = req.uri.queryParameters['scenario'] ?? '';
    final s = _store!;
    switch (scenario) {
      case 'cart':
        _seedCart(s);
        return _json(req, 200, {
          'ok': true,
          'scenario': 'cart',
          'cart': s.cart.length,
        });
      case 'products':
        _seedProducts(s);
        return _json(req, 200, {
          'ok': true,
          'scenario': 'products',
          'products': s.products.length,
        });
      case 'purchase':
        _seedPurchases(s);
        return _json(req, 200, {
          'ok': true,
          'scenario': 'purchase',
          'purchases': s.purchases.length,
        });
      default:
        return _json(req, 400, {
          'ok': false,
          'error': 'scenario inválido: usa cart | products | purchase',
        });
    }
  }

  static void _nav(HttpRequest req) {
    if (req.method != 'GET') {
      return _json(req, 405, {'ok': false, 'error': 'Solo GET'});
    }
    final to = req.uri.queryParameters['to'] ?? '/';
    // Lista blanca PRIMERO (la ruta inválida es 400 aunque el router no
    // esté vinculado) y luego el estado del puente (409).
    if (!kNavRoutes.contains(to)) {
      return _json(req, 400, {
        'ok': false,
        'error': 'Ruta fuera de la lista blanca',
        'allowed': kNavRoutes.toList(),
      });
    }
    if (_router == null) {
      return _json(req, 409, {'ok': false, 'error': 'Router no vinculado'});
    }
    _router!.push(to);
    return _json(req, 200, {'ok': true, 'to': to});
  }

  // ── Datos sembrados (compra venezolana realista) ─────────────────────────
  static void _seedCart(AppStore s) {
    void add(
      String name,
      int qty,
      double price,
      String currency, {
      String? store,
      double? size,
      String? sizeUnit,
      String? barcode,
    }) {
      s.addToCart(
        CartItem(
          id: s.newId(),
          name: name,
          quantity: qty,
          price: price,
          currency: currency,
          store: store,
          size: size,
          sizeUnit: sizeUnit,
          barcode: barcode,
        ),
      );
    }

    add('Arroz Mary 1 kg', 2, 2.50, 'USD',
        store: 'Central Madeirense', size: 1, sizeUnit: 'kg');
    add('Pasta Don Vito 800 g', 1, 1.20, 'USD',
        store: 'Central Madeirense', size: 800, sizeUnit: 'g');
    add('Café Llia 250 g', 1, 4.00, 'USD', store: 'Bicentenario');
    add('Harina de maíz Robin 1 kg', 3, 1.00, 'USD',
        store: 'Bicentenario', size: 1, sizeUnit: 'kg');
    add('Aceite Girasol 1 L', 1, 2.80, 'USD', size: 1, sizeUnit: 'l');
  }

  static void _seedProducts(AppStore s) {
    final ctx = s.contextOf(module: RateModule.calculator);
    final vesRate = ctx.unitsPerUSD(Currency.ves) ?? 0;
    void addProduct(
      String name,
      double priceUsd,
      String store, {
      double size = 0,
      String? unit,
    }) {
      s.addProduct(
        Product(
          id: '',
          name: name,
          category: ProductCategory.otros,
          presentation: unit == null
              ? Presentation.unit
              : (unit == 'g' || unit == 'kg'
                    ? Presentation.weight
                    : Presentation.volume),
          size: size,
          sizeUnit: unit,
          createdAt: DateTime.now(),
          records: const [],
        ),
        PriceRecord(
          id: '',
          price: priceUsd,
          originalPrice: priceUsd,
          currency: 'USD',
          quantity: 1,
          store: store,
          rate: vesRate,
          sourceId: ctx.sel(Currency.ves),
          date: DateTime.now(),
        ),
      );
    }

    addProduct('Arroz Mary 1 kg', 2.50, 'Central Madeirense',
        size: 1000, unit: 'g');
    addProduct('Café Llia 250 g', 4.00, 'Bicentenario', size: 250, unit: 'g');
    addProduct('Aceite Girasol 1 L', 2.80, 'Central Madeirense',
        size: 1000, unit: 'ml');
  }

  static void _seedPurchases(AppStore s) {
    final ctx = s.contextOf(module: RateModule.calculator);
    final rate = ctx.unitsPerUSD(Currency.ves) ?? 0;
    Purchase compra(
      String store,
      List<(String, int, double)> items,
      int daysAgo,
    ) {
      final pis = items
          .map(
            (e) => PurchaseItem(
              name: e.$1,
              quantity: e.$2,
              priceUSD: e.$3,
              originalPrice: e.$3,
              currency: 'USD',
            ),
          )
          .toList();
      final total = pis.fold<double>(0, (a, p) => a + p.priceUSD * p.quantity);
      return Purchase(
        id: '',
        date: DateTime.now().subtract(Duration(days: daysAgo)),
        store: store,
        items: pis,
        totalUSD: total,
        totalBS: rate > 0 ? total * rate : 0,
        rate: rate,
        rateSourceId: ctx.sel(Currency.ves),
        paidCurrency: 'USD',
        notes: 'Compra de prueba (puente v21.6)',
      );
    }

    s.addPurchase(
      compra('Central Madeirense', [('Arroz Mary 1 kg', 2, 2.50), ('Pasta Don Vito 800 g', 1, 1.20)], 3),
    );
    s.addPurchase(
      compra('Bicentenario', [('Café Llia 250 g', 1, 4.00), ('Harina Robin 1 kg', 3, 1.00)], 9),
    );
  }
}

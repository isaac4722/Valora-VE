/// ─── Contenido de los recorridos por módulo (v17.2) ────────────────────────
/// Un walkthrough por módulo, español neutro, 3-5 pasos, honesto. El disparo
/// automático lo hace MainShell al cambiar de pestaña (una vez por módulo);
/// el replay manual vive en Ajustes → Tutorial.
library;

import 'walkthrough.dart';

/// Recorridos por ruta (el moduleId coincide con la clave de SharedPreferences).
const kWalkthroughs = <String, ({String title, List<WalkthroughStep> steps})>{
  '/': (
    title: 'Inicio',
    steps: [
      WalkthroughStep(
        title: 'La tasa del día, primero',
        body: 'La tarjeta grande muestra la tasa activa de tu país: píldoras de brecha vs BCV y comparación con ayer. Toca copiar para llevarla al chat.',
      ),
      WalkthroughStep(
        title: 'Todas las tasas de tu moneda',
        body: 'En «Cotización principal» verás cada fuente disponible (BCV, paralelo, promedio y tu manual) y la fuente activa de las demás divisas. Toca una fila para activarla.',
      ),
      WalkthroughStep(
        title: 'Foco y resumen',
        body: '«Divisas del foco» abre el conversor con cada moneda; «Resumen del mes» y «Tus tiendas» resumen tu actividad real.',
      ),
    ],
  ),
  '/conversor': (
    title: 'Conversor',
    steps: [
      WalkthroughStep(
        title: 'Elige la fuente de tasa',
        body: 'La fila «Fuente de tasa» te deja elegir entre las tasas que da la API para esa moneda. Por defecto es la oficial; tu elección vive solo en el conversor.',
      ),
      WalkthroughStep(
        title: 'Fechas históricas',
        body: 'Debajo del título está la fecha de la tasa. «Elegir fecha» abre un calendario con los días guardados: perfecto para comparar con el pasado.',
      ),
      WalkthroughStep(
        title: 'Comparte con tu marca',
        body: '«Compartir» abre el menú propio: texto, imagen con la marca de ValoraVE o guardar la imagen. Nunca compartimos sin preguntarte cómo.',
      ),
    ],
  ),
  '/lista': (
    title: 'Lista de compras',
    steps: [
      WalkthroughStep(
        title: 'Escanea solo lo que importa',
        body: 'El escáner procesa únicamente el recuadro de apuntado: más rápido y sin lecturas falsas. Si el código no existe, te ofrece agregarlo a mano.',
      ),
      WalkthroughStep(
        title: 'Ítems con peso y tienda',
        body: 'Al editar un ítem puedes capturar el peso (600 g, 1,5 l) y su tienda. La app calcula cuánto vale el kilo o el litro por ti.',
      ),
      WalkthroughStep(
        title: 'Checkout con todo',
        body: '«Finalizar compra» abre un modal: una tienda única o varias, cuenta ajustada, nota y foto del ticket. Guarda y entra al historial con un toque.',
      ),
    ],
  ),
  '/productos': (
    title: 'Productos',
    steps: [
      WalkthroughStep(
        title: 'La ficha completa',
        body: 'Toca un producto: verás su gráfica de precio, la variación del último registro y todo su historial por tienda.',
      ),
      WalkthroughStep(
        title: 'Actualizar precio',
        body: 'Desde la ficha agregas el precio de hoy, escaneas el código de barras o cambias la tienda. Si queda bajo tu meta, te avisamos.',
      ),
      WalkthroughStep(
        title: 'Importa y comparte',
        body: 'Importa tu catálogo en CSV y comparte la lista cuando la necesites.',
      ),
    ],
  ),
  '/historial': (
    title: 'Historial',
    steps: [
      WalkthroughStep(
        title: 'Tus compras completas',
        body: 'Cada compra guardada vive aquí con su desglose, la tienda y el total. Filtra por período o por tienda.',
      ),
      WalkthroughStep(
        title: 'El ticket siempre a mano',
        body: 'Toca la foto del ticket para verla en grande. Las fotos viejas se comprimen solas para que la app no crezca sin control.',
      ),
    ],
  ),
  '/finanzas': (
    title: 'Finanzas',
    steps: [
      WalkthroughStep(
        title: 'Balance del mes',
        body: 'Ingresos, gastos y balance en USD normalizado, con la comparación contra el mes anterior.',
      ),
      WalkthroughStep(
        title: 'Constancias como quieras',
        body: 'La constancia se comparte o descarga en texto, imagen o PDF desde el menú propio. También puedes imprimirla.',
      ),
    ],
  ),
  '/analisis': (
    title: 'Análisis',
    steps: [
      WalkthroughStep(
        title: 'Toca la gráfica',
        body: 'Toca cualquier punto para ver la cifra exacta de ese día: las series responden con cursor y tooltip.',
      ),
      WalkthroughStep(
        title: 'Cobertura honesta',
        body: 'Los rangos dicen la cobertura real de datos («1 Año · N días con datos»), nunca prometemos más de lo que hay.',
      ),
    ],
  ),
  '/sala': (
    title: 'Sala en vivo',
    steps: [
      WalkthroughStep(
        title: 'Elige cómo conectar',
        body: 'Cinco modos sin internet: Cerca (Nearby), WiFi local, Hotspot, Bluetooth o tu propio servidor. Solo las consultas de tasas usan datos, y tú decides cada cuánto.',
      ),
      WalkthroughStep(
        title: 'Verificación PIN + emoji',
        body: 'Todo ingreso pide el PIN de 4 dígitos y el emoji coincidente. Si el emoji no es el mismo, la conexión se cancela: nadie entra a una sala que no es.',
      ),
      WalkthroughStep(
        title: 'Descubre o entra por código',
        body: 'Las salas públicas cercanas aparecen solas; también puedes buscar por código. Al crear, eliges tu nombre, el nombre de la sala y si es pública.',
      ),
    ],
  ),
  '/ajustes': (
    title: 'Ajustes',
    steps: [
      WalkthroughStep(
        title: 'Modo offline total',
        body: 'En «Datos y conexión» decides si la app consulta APIs y cada cuánto. Todo lo descargado queda guardado en tu teléfono, sin duplicados.',
      ),
      WalkthroughStep(
        title: 'Recorridos cuando quieras',
        body: 'Aquí mismo puedes repetir este tipo de recorridos en cada módulo.',
      ),
    ],
  ),
};

/// Recorrido manual (Ajustes). Devuelve los módulos con nombre legible.
const kWalkthroughLabels = <String, String>{
  '/': 'Inicio',
  '/conversor': 'Conversor',
  '/lista': 'Lista de compras',
  '/productos': 'Productos',
  '/historial': 'Historial',
  '/finanzas': 'Finanzas',
  '/analisis': 'Análisis',
  '/sala': 'Sala en vivo',
  '/ajustes': 'Ajustes',
};

# lista-sync · sala de compras en vivo (ValoraVE)

Mini servicio **Socket.io** del protocolo `lista-sync` (MVP-CRUD.md §6):
salas efímeras en memoria para compartir la lista de compras en tiempo
real. Sin persistencia, sin cuentas: sala vacía → GC inmediato.

## Ejecutar

```bash
bun install && bun run start        # Bun (recomendado)
npm install && npm start            # Node también funciona
PORT=3030 bun run index.ts          # puerto fijo 3030 por defecto
```

## Contrato

- `path: '/'` — NO cambiar (lo usa el proxy/gateway).
- Código de sala: 6 caracteres de `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
  (sin O/I, se confunden con 0/1).
- Límites: 8 miembros · 120 ítems · 16 KB por payload.
- Eventos cliente→servidor: `create_room{name}` · `join_room{code,name}` ·
  `typing` · `item_add{item}` · `item_update{id,patch}` ·
  `item_remove{id}` · `list_clear{}` · `list_replace{items}` ·
  `leave_room` · `presence_ping` · `disconnect`.
- Acks: `{type:'room_created',code,...}` · `{type:'room_joined',...}` ·
  `{type:'ok'}` · `{type:'room_error',reason}` con razones `not_found`,
  `room_full`, `too_large`, `bad_item`, `bad_update`, `bad_remove`,
  `bad_items`, `list_full`, `not_in_room`.
- Eventos servidor→todos (incluye el origen, eco idempotente):
  `item_add` · `item_update{id,patch,byId}` · `item_remove{id,byId}` ·
  `list_clear{byId}` · `list_replace{items,byId}` · `member_joined` ·
  `member_left` · `presence{online[]}` · `typing{names}`.
- Presencia: escáner cada 5 s, miembro obsoleto tras 35 s sin hablar;
  emite `presence`/`typing` sólo cuando cambia la firma.
- `item_update`: last-write-wins; `checkedBy:''` limpia la atribución.

La app Flutter se conecta con `socket_io_client` usando la URL que el
usuario configura en Ajustes (transporte «Servidor»). El protocolo es
idéntico en los tres transportes de la app (Servidor / Cerca / WiFi
local): sólo cambia cómo viajan los bytes.

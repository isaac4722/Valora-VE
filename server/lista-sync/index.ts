/**
 * lista-sync · mini servicio de «Grupo de compras en vivo» (ValoraVE)
 * ─────────────────────────────────────────────────────────────────────────
 * Socket.io PURO sobre http, listo para desplegar (Bun o Node).
 *   · Puerto 3030 FIJO (configurable por env PORT para pruebas).
 *   · path '/' — NO cambiar: lo usan el gateway/proxy para forwardear.
 *   · CORS abierto + pingTimeout 60s (sesiones de supermercado con red floja).
 *
 * DISEÑO CRÍTICO DE SINCRONÍA (leer antes de tocar):
 *   · Los eventos de ítems son OPERACIONES GRANULARES (item_add / item_update
 *     / item_remove / list_clear / list_replace), nunca «estado completo» —
 *     así cada cambio es pequeño, ordenado y difícil de pisar.
 *   · El cliente aplica los eventos remotos SIN re-emitirlos (guard de
 *     supresión en el cliente): lo que sale por el diff del store es sólo
 *     lo que el usuario tocó.
 *   · Conflictos de item_update: gana el ÚLTIMO evento recibido
 *     (last-write-wins por orden de llegada del socket) — sin relojes ni
 *     vectores: para una lista de mercado la simplicidad gana.
 *   · Sincronización completa perezosa: el estado completo viaja SOLO en el
 *     `room_joined` (respuesta al join) y en `list_replace` (si un miembro la
 *     envía explícitamente). El joiner RECIBE el estado del servidor y
 *     reconstruye su carrito con él (elección de diseño v13.3).
 *
 * Todo vive EN MEMORIA: sala vacía → GC inmediato. Sin persistencia, sin
 * cuentas — la sala es opcional y la app funciona igual offline.
 */
import { createServer } from 'http'
import { Server, type Socket } from 'socket.io'

const PORT = Number(process.env.PORT ?? 3030)

const httpServer = createServer()
const io = new Server(httpServer, {
  // DO NOT change the path, it is used by the proxy/gateway to forward
  path: '/',
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
  pingTimeout: 60000,
  pingInterval: 25000,
})

// ─── Modelo de sala (en memoria) ───────────────────────────────────────────

interface RoomMember {
  id: string
  name: string
  /** epoch ms de su última señal (presence_ping u operación). */
  lastSeen: number
  /** epoch ms de su último `typing` (undefined = no está escribiendo). */
  typing?: number
}

interface RoomItem {
  id: string
  name: string
  quantity: number
  price: number
  currency: string
  checked?: boolean
  /** nombre visible de quien marcó (≤24 chars; '' en patch = limpiar) */
  checkedBy?: string
  /** memberId que la creó — informativo, nunca lo pisa un patch */
  by: string
}

interface Room {
  code: string
  members: Map<string, RoomMember>
  items: Map<string, RoomItem>
}

const rooms = new Map<string, Room>()

// Límites anti-abuso: 8 miembros · 120 ítems · payloads ≤ 16KB
const MAX_MEMBERS = 8
const MAX_ITEMS = 120
const MAX_PAYLOAD = 16 * 1024

// Presencia: un miembro está «en línea» si habló hace menos de STALE_MS.
// 35s > pingInterval 25s del engine: cubre una pérdida de red sin conservar
// fantasmas (el engine ping NO toca lastSeen — sólo presence_ping y las
// operaciones de ítems). Ambas por env para pruebas efímeras.
const STALE_MS = Number(process.env.STALE_MS ?? 35000)
const SCAN_MS = Number(process.env.SCAN_MS ?? 5000)
// «Escribiendo…»: un stamp de typing vive TYPING_MS; el escáner lo poda.
const TYPING_MS = Number(process.env.TYPING_MS ?? 3000)

/** A-Z sin O/I (se confunden con 0/1) + 2-9 → 32 símbolos sin ambigüedades. */
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'

function newRoomCode(): string {
  for (;;) {
    const bytes = crypto.getRandomValues(new Uint8Array(6))
    let code = ''
    for (const b of bytes) code += CODE_ALPHABET[b % CODE_ALPHABET.length]
    if (!rooms.has(code)) return code
  }
}

/** Tamaño del payload en bytes UTF-8 (tope 16KB — rechaza con room_error). */
function tooLarge(data: unknown): boolean {
  try {
    return Buffer.byteLength(JSON.stringify(data ?? {}), 'utf8') > MAX_PAYLOAD
  } catch {
    return true
  }
}

/** Nombre corto y limpio: trim, ≤24 chars, nunca vacío. */
function cleanName(raw: unknown): string {
  const s = typeof raw === 'string' ? raw.trim().slice(0, 24) : ''
  return s || 'Comprador'
}

/** Colisión de nombres → sufijo numérico («Ana», «Ana 2», «Ana 3»…). */
function uniqueName(room: Room, name: string): string {
  const taken = new Set([...room.members.values()].map((m) => m.name.toLowerCase()))
  if (!taken.has(name.toLowerCase())) return name
  for (let n = 2; ; n++) {
    const candidate = `${name} ${n}`
    if (!taken.has(candidate.toLowerCase())) return candidate
  }
}

/** Divisa: 3 mayúsculas (USD, VES, EUR…) — el cliente ya valida contra su catálogo. */
function validCurrency(c: unknown): c is string {
  return typeof c === 'string' && /^[A-Z]{3}$/.test(c)
}

/** Valida y normaliza un ítem entrante (item_add / list_replace). */
function sanitizeItem(raw: unknown, by: string): RoomItem | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const r = raw as Record<string, unknown>
  const id = typeof r.id === 'string' && r.id.length >= 1 && r.id.length <= 64 ? r.id : null
  const name = typeof r.name === 'string' ? r.name.trim().slice(0, 200) : ''
  const quantity =
    typeof r.quantity === 'number' && Number.isFinite(r.quantity)
      ? Math.min(999, Math.max(1, Math.round(r.quantity)))
      : NaN
  const price =
    typeof r.price === 'number' && Number.isFinite(r.price) && r.price >= 0 ? r.price : NaN
  if (!id || !name || Number.isNaN(quantity) || Number.isNaN(price) || !validCurrency(r.currency)) {
    return null
  }
  const item: RoomItem = { id, name, quantity, price, currency: r.currency, by }
  if (typeof r.checked === 'boolean') item.checked = r.checked
  // La marca viaja con el alta (nombre de quien marcó, ≤24 chars).
  if (typeof r.checkedBy === 'string') {
    const cb = r.checkedBy.trim().slice(0, 24)
    if (cb) item.checkedBy = cb
  }
  return item
}

/** Valida un patch de item_update: sólo campos seguros, valores saneados. */
function sanitizePatch(raw: unknown): Partial<RoomItem> | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null
  const r = raw as Record<string, unknown>
  const out: Partial<RoomItem> = {}
  if (r.name !== undefined) {
    const n = typeof r.name === 'string' ? r.name.trim().slice(0, 200) : ''
    if (!n) return null
    out.name = n
  }
  if (r.quantity !== undefined) {
    if (typeof r.quantity !== 'number' || !Number.isFinite(r.quantity) || r.quantity < 1 || r.quantity > 999) return null
    out.quantity = Math.round(r.quantity)
  }
  if (r.price !== undefined) {
    if (typeof r.price !== 'number' || !Number.isFinite(r.price) || r.price < 0) return null
    out.price = r.price
  }
  if (r.currency !== undefined) {
    if (!validCurrency(r.currency)) return null
    out.currency = r.currency
  }
  if (r.checked !== undefined) {
    if (typeof r.checked !== 'boolean') return null
    out.checked = r.checked
  }
  // checkedBy — string recortada, MÁX 24 chars (más largo se rechaza con
  // bad_update); vacía se acepta para limpiar.
  if (r.checkedBy !== undefined) {
    if (typeof r.checkedBy !== 'string') return null
    const cb = r.checkedBy.trim()
    if (cb.length > 24) return null
    out.checkedBy = cb
  }
  return Object.keys(out).length > 0 ? out : null
}

const membersOf = (room: Room): RoomMember[] => [...room.members.values()]
const itemsOf = (room: Room): RoomItem[] => [...room.items.values()]

/** Log conciso: [CÓDIGO] evento · n miembros · n ítems */
function log(room: Room | string, event: string, extra = ''): void {
  const code = typeof room === 'string' ? room : room.code
  const n = typeof room === 'string' ? '' : ` · ${room.members.size} miembros · ${room.items.size} ítems`
  console.log(`[lista-sync] [${code}] ${event}${n}${extra ? ` · ${extra}` : ''}`)
}

// ─── Ciclo de vida del socket (un socket = un miembro, una sala) ───────────

/** Sala actual del socket (o null). */
function currentRoom(socket: Socket): Room | null {
  const code = socket.data.roomCode as string | undefined
  return code ? rooms.get(code) ?? null : null
}

/** El socket demostró vida: refresca su lastSeen (si es miembro). */
function touch(socket: Socket): void {
  const m = currentRoom(socket)?.members.get(socket.id)
  if (m) m.lastSeen = Date.now()
}

/** El miembro hizo algo VISIBLE (item_*): su «escribiendo…» terminó. */
function clearTyping(socket: Socket): void {
  const m = currentRoom(socket)?.members.get(socket.id)
  if (m) delete m.typing
}

function joinMember(socket: Socket, room: Room, name: string): void {
  // Acaba de hablar (su join): entra EN LÍNEA por definición.
  room.members.set(socket.id, { id: socket.id, name, lastSeen: Date.now() })
  socket.data.roomCode = room.code
  socket.join(room.code)
}

/** leave_room / disconnect: salir, avisar y GC inmediato si queda vacía. */
function leaveCurrent(socket: Socket): void {
  const room = currentRoom(socket)
  socket.data.roomCode = undefined
  if (!room) return
  room.members.delete(socket.id)
  socket.leave(room.code)
  if (room.members.size === 0) {
    rooms.delete(room.code)
    log(room.code, `GC (sala vacía)`)
  } else {
    io.to(room.code).emit('member_left', { type: 'member_left', id: socket.id })
    log(room, 'member_left')
  }
}

/** ack de error normalizado (siempre {type:'room_error', reason}). */
function ackError(ack: unknown, reason: string): void {
  if (typeof ack === 'function') (ack as (r: unknown) => void)({ type: 'room_error', reason })
}
function ackOk(ack: unknown, extra: Record<string, unknown> = {}): void {
  if (typeof ack === 'function') (ack as (r: unknown) => void)({ type: 'ok', ...extra })
}

// ─── Presencia: escáner que decide quién está en línea ─────────────────────
// Cada SCAN_MS recorre las salas y compara los miembros con lastSeen fresco
// contra el snapshot anterior: SOLO emite `presence` al cambiar (sin ruido).

/** Último conjunto online por sala («id,id» — comparación barata). */
const lastPresence = new Map<string, string>()
/** Último conjunto escribiendo por sala («nombre,nombre»). */
const lastTyping = new Map<string, string>()

function scanPresence(): void {
  const now = Date.now()
  for (const room of rooms.values()) {
    const members = membersOf(room)
    const onlineIds = members
      .filter((m) => now - m.lastSeen < STALE_MS)
      .map((m) => m.id)
    const sig = onlineIds.join(',')
    if (lastPresence.get(room.code) !== sig) {
      lastPresence.set(room.code, sig)
      io.to(room.code).emit('presence', { type: 'presence', online: onlineIds })
      log(room, 'presence', `${onlineIds.length}/${room.members.size} en línea`)
    }
    // «Escribiendo…»: poda stamps vencidos (> TYPING_MS), junta los NOMBRES
    // de miembros EN LÍNEA con typing fresco y emite sólo al cambiar.
    const online = new Set(onlineIds)
    const typingNames: string[] = []
    for (const m of members) {
      if (m.typing !== undefined && now - m.typing > TYPING_MS) delete m.typing
      if (m.typing !== undefined && online.has(m.id)) typingNames.push(m.name)
    }
    const tsig = typingNames.join(',')
    if (lastTyping.get(room.code) !== tsig) {
      lastTyping.set(room.code, tsig)
      io.to(room.code).emit('typing', { names: typingNames })
      log(room, 'typing', typingNames.length > 0 ? `«${typingNames.join('», «')}»` : '(nadie)')
    }
  }
  // Sala desaparecida del Map (GC) → fuera de los snapshots también.
  for (const code of lastPresence.keys()) {
    if (!rooms.has(code)) lastPresence.delete(code)
  }
  for (const code of lastTyping.keys()) {
    if (!rooms.has(code)) lastTyping.delete(code)
  }
}
setInterval(scanPresence, SCAN_MS)

io.on('connection', (socket) => {
  log('—', `connect ${socket.id}`)

  // ── Crear sala: código nuevo + el creador entra como primer miembro ──
  socket.on('create_room', (data, ack) => {
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const name = cleanName((data as { name?: unknown } | undefined)?.name)
    const room: Room = { code: newRoomCode(), members: new Map(), items: new Map() }
    rooms.set(room.code, room)
    joinMember(socket, room, name)
    // Respuesta con superset del contrato {code, id}: members/items de una
    // vez para que el creador pinte la sala sin segundo viaje.
    if (typeof ack === 'function') {
      ack({ type: 'room_created', code: room.code, id: room.code, members: membersOf(room), items: itemsOf(room) })
    }
    log(room, 'room_created', `«${name}»`)
  })

  // ── Unirse: not_found / room_full / colisión de nombre con sufijo ──
  socket.on('join_room', (data, ack) => {
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const d = (data ?? {}) as { code?: unknown; name?: unknown }
    const code = typeof d.code === 'string' ? d.code.trim().toUpperCase() : ''
    const room = rooms.get(code)
    if (!room) return ackError(ack, 'not_found')
    if (!room.members.has(socket.id) && room.members.size >= MAX_MEMBERS) {
      return ackError(ack, 'room_full')
    }
    const name = uniqueName(room, cleanName(d.name))
    leaveCurrent(socket) // si venía de otra sala (no debería, pero cuesta nada)
    joinMember(socket, room, name)
    if (typeof ack === 'function') {
      ack({ type: 'room_joined', code: room.code, members: membersOf(room), items: itemsOf(room) })
    }
    // A los DEMÁS (el joiner ya recibe el estado en el ack)
    socket.to(room.code).emit('member_joined', { type: 'member_joined', member: { id: socket.id, name } })
    log(room, 'member_joined', `«${name}»`)
  })

  // ── «Escribiendo…»: estampa y deja el resto al escáner ──
  // Sin payload ni ack. La emisión a la sala sale del PROPIO escáner (misma
  // deduplicación por snapshot); se escanea aquí para latencia <1s.
  socket.on('typing', () => {
    const m = currentRoom(socket)?.members.get(socket.id)
    if (!m) return
    m.typing = Date.now()
    m.lastSeen = m.typing // escribir también demuestra vida (presencia)
    scanPresence()
  })

  // ── Operaciones granulares: difunden a TODOS (incluye el origen) ──
  socket.on('item_add', (data, ack) => {
    touch(socket)
    clearTyping(socket)
    const room = currentRoom(socket)
    if (!room) return ackError(ack, 'not_in_room')
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const item = sanitizeItem((data as { item?: unknown } | undefined)?.item, socket.id)
    if (!item) return ackError(ack, 'bad_item')
    if (!room.items.has(item.id)) {
      if (room.items.size >= MAX_ITEMS) return ackError(ack, 'list_full')
    }
    room.items.set(item.id, item) // eco repetido → reemplazo idempotente
    io.to(room.code).emit('item_add', { type: 'item_add', item })
    ackOk(ack)
    log(room, 'item_add', `«${item.name}»`)
  })

  socket.on('item_update', (data, ack) => {
    touch(socket)
    clearTyping(socket)
    const room = currentRoom(socket)
    if (!room) return ackError(ack, 'not_in_room')
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const d = (data ?? {}) as { id?: unknown; patch?: unknown }
    const id = typeof d.id === 'string' ? d.id : ''
    const patch = sanitizePatch(d.patch)
    if (!id || !patch || !room.items.has(id)) return ackError(ack, 'bad_update')
    // last-write-wins; checkedBy '' limpia la atribución (sin clave falsa).
    const nextItem = { ...room.items.get(id)!, ...patch }
    if (nextItem.checkedBy === '') delete nextItem.checkedBy
    room.items.set(id, nextItem)
    // byId: autor del cambio (extra del wire, sanitizePatch no lo pisa) —
    // el cliente lo usa para el flash/notificación y para saltar su propio eco.
    io.to(room.code).emit('item_update', { type: 'item_update', id, patch, byId: socket.id })
    ackOk(ack)
    log(room, 'item_update', id)
  })

  socket.on('item_remove', (data, ack) => {
    touch(socket)
    clearTyping(socket)
    const room = currentRoom(socket)
    if (!room) return ackError(ack, 'not_in_room')
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const id = (data as { id?: unknown } | undefined)?.id
    if (typeof id !== 'string' || !room.items.has(id)) return ackError(ack, 'bad_remove')
    room.items.delete(id)
    io.to(room.code).emit('item_remove', { type: 'item_remove', id, byId: socket.id })
    ackOk(ack)
    log(room, 'item_remove', id)
  })

  socket.on('list_clear', (data, ack) => {
    touch(socket)
    const room = currentRoom(socket)
    if (!room) return ackError(ack, 'not_in_room')
    if (tooLarge(data)) return ackError(ack, 'too_large')
    room.items.clear()
    io.to(room.code).emit('list_clear', { type: 'list_clear', byId: socket.id })
    ackOk(ack)
    log(room, 'list_clear')
  })

  // ── Sincronización completa: un miembro empuja su lista entera ──
  socket.on('list_replace', (data, ack) => {
    touch(socket)
    const room = currentRoom(socket)
    if (!room) return ackError(ack, 'not_in_room')
    if (tooLarge(data)) return ackError(ack, 'too_large')
    const raw = (data as { items?: unknown } | undefined)?.items
    if (!Array.isArray(raw) || raw.length > MAX_ITEMS) return ackError(ack, 'bad_items')
    const items: RoomItem[] = []
    for (const r of raw) {
      const item = sanitizeItem(r, socket.id)
      if (!item) return ackError(ack, 'bad_items') // todo o nada: nunca a medias
      items.push(item)
    }
    room.items.clear()
    for (const item of items) room.items.set(item.id, item)
    io.to(room.code).emit('list_replace', { type: 'list_replace', items: itemsOf(room), byId: socket.id })
    ackOk(ack)
    log(room, 'list_replace', `${items.length} ítems`)
  })

  // ── Salida explícita / caída: mismo camino (member_left + GC) ──
  socket.on('leave_room', (_data, ack) => {
    touch(socket)
    leaveCurrent(socket)
    ackOk(ack)
  })

  // ── Presencia: latido del cliente (sin ack — el escáner hace el resto) ──
  socket.on('presence_ping', () => touch(socket))

  socket.on('disconnect', (reason) => {
    leaveCurrent(socket)
    log('—', `disconnect ${socket.id} (${reason})`)
  })

  socket.on('error', (err) => {
    console.error(`[lista-sync] socket error ${socket.id}:`, err?.message ?? err)
  })
})

httpServer.listen(PORT, () => {
  console.log(`[lista-sync] Grupo de compras en vivo · socket.io en :${PORT} (path '/')`)
})

// Cierre limpio (SIGTERM/SIGINT)
function shutdown(signal: string): void {
  console.log(`[lista-sync] ${signal} recibido — cerrando…`)
  httpServer.close(() => process.exit(0))
  setTimeout(() => process.exit(0), 1500).unref()
}
process.on('SIGTERM', () => shutdown('SIGTERM'))
process.on('SIGINT', () => shutdown('SIGINT'))

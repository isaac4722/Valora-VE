package ve.valorave.app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.IOException
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * BtSppPlugin — Bluetooth clásico RFCOMM/SPP para la Sala Viva (v18.0).
 *
 * Hecho a mano (MethodChannel + EventChannel) porque ningún paquete de pub.dev
 * soporta el ROL SERVIDOR sobre RFCOMM: flutter_bluetooth_serial lleva
 * congelado desde 2021 y las variantes _plus solo exponen el lado cliente.
 *
 * Servicio: "ValoraVE" sobre el UUID SPP propio (mismo en anfitrión e
 * invitado — es la misma app). El anfitrión acepta VARIOS invitados; cada
 * socket aceptado recibe un id "btN". El invitado abre UN socket al
 * anfitrión (id "host" en sus eventos).
 *
 * Permisos (solo los del modo elegido):
 *  · API 31+: BLUETOOTH_CONNECT siempre; BLUETOOTH_SCAN además para descubrir.
 *  · API <31: BLUETOOTH/BLUETOOTH_ADMIN (manifest, maxSdk 30) +
 *    ACCESS_FINE_LOCATION para el discovery.
 *
 * Eventos hacia Dart (mapas): accepted{id} · data{id,data} · peerClosed{id} ·
 * connected{} · closed{} · found{address,name} · discoveryDone{} ·
 * bonded{address} · bondFailed{address} · state{value} · error{code}.
 * Códigos de error: unavailable · off · permissions · bt_connect · bt_timeout.
 */
class BtSppPlugin : FlutterPlugin, ActivityAware {
    companion object {
        const val CHANNEL = "valorave/bt_spp"
        const val EVENTS = "valorave/bt_spp/events"
        const val SERVICE_NAME = "ValoraVE"
        val SPP_UUID: java.util.UUID =
            java.util.UUID.fromString("8e0c4a52-7c11-4d9a-8f3b-2a5e6c1d0b94")
        private const val PERM_REQUEST = 48132
    }

    private var channel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private var appContext: Context? = null
    private var activity: android.app.Activity? = null
    private var adapter: BluetoothAdapter? = null

    // Host: servidor + múltiples pares. Invitado: UN socket al anfitrión.
    private var server: BluetoothServerSocket? = null
    private var acceptThread: Thread? = null
    private val peers = java.util.concurrent.ConcurrentHashMap<String, Peer>()
    private val peerSeq = java.util.concurrent.atomic.AtomicInteger(0)
    private var clientSocket: BluetoothSocket? = null
    private var clientThread: Thread? = null
    private val running = java.util.concurrent.atomic.AtomicBoolean(false)
    private var discovering = false
    private var receiver: BroadcastReceiver? = null

    private class Peer(val id: String, val socket: BluetoothSocket)

    // ── Ciclo de vida del plugin ────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        adapter = (binding.applicationContext
            .getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result -> onCall(call, result) }
        eventChannel = EventChannel(binding.binaryMessenger, EVENTS)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                sink = events
            }

            override fun onCancel(args: Any?) {
                sink = null
            }
        })
        registerReceiver()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        channel = null
        eventChannel = null
        destroy()
        unregisterReceiver()
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ── Métodos expuestos ───────────────────────────────────────────────────

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(state())

            "hasPermissions" -> {
                val scan = call.argument<Boolean>("scan") ?: false
                result.success(hasPermissions(scan))
            }

            "requestPermissions" -> {
                val scan = call.argument<Boolean>("scan") ?: false
                requestPermissions(scan)
                result.success(hasPermissions(scan))
            }

            "serverStart" -> result.success(serverStart())

            "serverStop" -> {
                stopServer()
                result.success(true)
            }

            "connect" -> {
                val address = call.argument<String>("address") ?: ""
                result.success(startClient(address))
            }

            "disconnect" -> {
                stopClient()
                result.success(true)
            }

            "write" -> {
                val id = call.argument<String>("id") ?: "host"
                val data = call.argument<ByteArray>("data")
                result.success(if (data == null) false else write(id, data))
            }

            "closePeer" -> {
                closePeer(call.argument<String>("id") ?: "", notify = true)
                result.success(true)
            }

            "startDiscovery" -> result.success(startDiscovery())

            "cancelDiscovery" -> {
                cancelDiscovery()
                result.success(true)
            }

            "bondedDevices" -> result.success(bondedDevices())

            "isBonded" -> {
                val address = call.argument<String>("address") ?: ""
                result.success(isBonded(address))
            }

            "bond" -> {
                val address = call.argument<String>("address") ?: ""
                result.success(startBond(address))
            }

            "destroy" -> {
                destroy()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // ── Estado y permisos ───────────────────────────────────────────────────

    private fun state(): String = when (adapter?.state) {
        BluetoothAdapter.STATE_ON -> "on"
        BluetoothAdapter.STATE_TURNING_ON -> "turning_on"
        BluetoothAdapter.STATE_TURNING_OFF -> "turning_off"
        BluetoothAdapter.STATE_OFF -> "off"
        else -> if (adapter == null) "unavailable" else "off"
    }

    private fun hasPermissions(scan: Boolean): Boolean {
        val ctx = appContext ?: return false
        return if (Build.VERSION.SDK_INT >= 31) {
            var ok = ContextCompat.checkSelfPermission(
                ctx, Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            if (scan) {
                ok = ok && ContextCompat.checkSelfPermission(
                    ctx, Manifest.permission.BLUETOOTH_SCAN
                ) == PackageManager.PERMISSION_GRANTED
            }
            ok
        } else {
            // <31: el discovery exige ubicación fina; conectar/existir no.
            if (scan) ContextCompat.checkSelfPermission(
                ctx, Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED else true
        }
    }

    /// Pide SOLO los permisos del gesto en curso (diálogo del sistema).
    private fun requestPermissions(scan: Boolean) {
        val act = activity ?: return
        val perms = if (Build.VERSION.SDK_INT >= 31) {
            if (scan) arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            ) else arrayOf(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            if (scan) arrayOf(Manifest.permission.ACCESS_FINE_LOCATION) else return
        }
        ActivityCompat.requestPermissions(act, perms, PERM_REQUEST)
    }

    // ── Servidor (anfitrión) ────────────────────────────────────────────────

    private fun serverStart(): Boolean {
        val a = adapter ?: run {
            emit(mapOf("kind" to "error", "code" to "unavailable")); return false
        }
        if (state() != "on") {
            emit(mapOf("kind" to "error", "code" to "off")); return false
        }
        if (!hasPermissions(false)) {
            emit(mapOf("kind" to "error", "code" to "permissions")); return false
        }
        if (server != null) return true
        running.set(true)
        return try {
            server = a.listenUsingRfcommWithServiceRecord(SERVICE_NAME, SPP_UUID)
            acceptThread = Thread { acceptLoop() }.also { it.start() }
            true
        } catch (e: SecurityException) {
            emit(mapOf("kind" to "error", "code" to "permissions")); false
        } catch (e: IOException) {
            emit(mapOf("kind" to "error", "code" to "bt_connect")); false
        }
    }

    private fun acceptLoop() {
        while (running.get()) {
            val sock = try {
                server?.accept()
            } catch (e: SecurityException) {
                emit(mapOf("kind" to "error", "code" to "permissions")); null
            } catch (e: IOException) {
                null // servidor cerrado o cayó
            } ?: break
            val id = "bt${peerSeq.incrementAndGet()}"
            val peer = Peer(id, sock)
            peers[id] = peer
            emit(mapOf("kind" to "accepted", "id" to id))
            Thread { readPeerLoop(peer) }.start()
        }
    }

    private fun readPeerLoop(peer: Peer) {
        val buf = ByteArray(8192)
        try {
            val input = peer.socket.inputStream
            while (running.get() && peers.containsKey(peer.id)) {
                val n = input.read(buf)
                if (n < 0) break
                emit(mapOf("kind" to "data", "id" to peer.id, "data" to buf.copyOf(n)))
            }
        } catch (e: IOException) {
            // El par se fue: se limpia abajo.
        }
        closePeer(peer.id, notify = true)
    }

    private fun closePeer(id: String, notify: Boolean) {
        val peer = peers.remove(id) ?: return
        try {
            peer.socket.close()
        } catch (_: IOException) {
        }
        if (notify) emit(mapOf("kind" to "peerClosed", "id" to id))
    }

    private fun stopServer() {
        running.set(false)
        try {
            server?.close()
        } catch (_: IOException) {
        }
        server = null
        acceptThread = null
        for (id in peers.keys.toList()) closePeer(id, notify = false)
        peers.clear()
    }

    // ── Cliente (invitado) ──────────────────────────────────────────────────

    private fun startClient(address: String): Boolean {
        val a = adapter ?: run {
            emit(mapOf("kind" to "error", "code" to "unavailable")); return false
        }
        if (state() != "on") {
            emit(mapOf("kind" to "error", "code" to "off")); return false
        }
        if (!hasPermissions(false)) {
            emit(mapOf("kind" to "error", "code" to "permissions")); return false
        }
        if (address.isBlank()) return false
        running.set(true)
        Thread {
            try {
                val dev = a.getRemoteDevice(address)
                cancelDiscovery()
                val sock = dev.createRfcommSocketToServiceRecord(SPP_UUID)
                sock.connect() // bloquea; el emparejamiento previo lo hace el hub
                clientSocket = sock
                emit(mapOf("kind" to "connected"))
                clientThread = Thread { readClientLoop(sock) }.also { it.start() }
            } catch (e: SecurityException) {
                emit(mapOf("kind" to "error", "code" to "permissions"))
            } catch (e: IllegalArgumentException) {
                emit(mapOf("kind" to "error", "code" to "bt_connect"))
            } catch (e: IOException) {
                emit(mapOf("kind" to "error", "code" to "bt_connect"))
            }
        }.start()
        return true
    }

    private fun readClientLoop(sock: BluetoothSocket) {
        val buf = ByteArray(8192)
        try {
            while (running.get() && clientSocket == sock) {
                val n = sock.inputStream.read(buf)
                if (n < 0) break
                emit(mapOf("kind" to "data", "id" to "host", "data" to buf.copyOf(n)))
            }
        } catch (e: IOException) {
            // Se perdió al anfitrión.
        }
        if (clientSocket == sock) {
            clientSocket = null
            try {
                sock.close()
            } catch (_: IOException) {
            }
            emit(mapOf("kind" to "closed"))
        }
    }

    private fun stopClient() {
        running.set(false)
        val sock = clientSocket
        clientSocket = null
        try {
            sock?.close()
        } catch (_: IOException) {
        }
        clientThread = null
    }

    // ── Escritura ───────────────────────────────────────────────────────────

    private fun write(id: String, data: ByteArray): Boolean = try {
        if (id == "host") {
            val sock = clientSocket
                ?: return false
            synchronized(sock) {
                sock.outputStream.write(data)
                sock.outputStream.flush()
            }
            true
        } else {
            val peer = peers[id] ?: return false
            synchronized(peer.socket) {
                peer.socket.outputStream.write(data)
                peer.socket.outputStream.flush()
            }
            true
        }
    } catch (e: IOException) {
        false
    } catch (e: SecurityException) {
        false
    }

    // ── Discovery + emparejamiento ──────────────────────────────────────────

    private fun registerReceiver() {
        if (receiver != null) return
        val ctx = appContext ?: return
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        receiver = object : BroadcastReceiver() {
            @Suppress("DEPRECATION")
            override fun onReceive(c: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val dev: BluetoothDevice? =
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        if (dev != null) {
                            val name = try {
                                dev.name ?: ""
                            } catch (e: SecurityException) {
                                ""
                            }
                            emit(
                                mapOf(
                                    "kind" to "found",
                                    "address" to dev.address,
                                    "name" to name
                                )
                            )
                        }
                    }

                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        discovering = false
                        emit(mapOf("kind" to "discoveryDone"))
                    }

                    BluetoothAdapter.ACTION_STATE_CHANGED -> {
                        emit(mapOf("kind" to "state", "value" to state()))
                    }

                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        val dev: BluetoothDevice? =
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        if (dev != null) {
                            val st = intent.getIntExtra(
                                BluetoothDevice.EXTRA_BOND_STATE, -1
                            )
                            when (st) {
                                BluetoothDevice.BOND_BONDED ->
                                    emit(mapOf("kind" to "bonded", "address" to dev.address))

                                BluetoothDevice.BOND_NONE ->
                                    emit(mapOf("kind" to "bondFailed", "address" to dev.address))
                            }
                        }
                    }
                }
            }
        }
        ContextCompat.registerReceiver(ctx, receiver!!, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
    }

    private fun unregisterReceiver() {
        val r = receiver ?: return
        try {
            appContext?.unregisterReceiver(r)
        } catch (_: IllegalArgumentException) {
        }
        receiver = null
    }

    private fun startDiscovery(): Boolean {
        val a = adapter ?: return false
        if (state() != "on") return false
        if (!hasPermissions(true)) {
            emit(mapOf("kind" to "error", "code" to "permissions")); return false
        }
        if (discovering) return true
        discovering = try {
            a.startDiscovery()
        } catch (e: SecurityException) {
            emit(mapOf("kind" to "error", "code" to "permissions")); return false
        }
        return discovering
    }

    private fun cancelDiscovery() {
        try {
            if (adapter?.isDiscovering == true) adapter?.cancelDiscovery()
        } catch (_: SecurityException) {
        }
        discovering = false
    }

    private fun bondedDevices(): List<Map<String, String>> {
        val a = adapter ?: return emptyList()
        if (!hasPermissions(false)) return emptyList()
        val out = mutableListOf<Map<String, String>>()
        try {
            for (d in a.bondedDevices) {
                val name = try {
                    d.name ?: ""
                } catch (e: SecurityException) {
                    ""
                }
                out.add(mapOf("address" to d.address, "name" to name))
            }
        } catch (e: SecurityException) {
            // Sin permiso: lista vacía.
        }
        return out
    }

    private fun isBonded(address: String): Boolean {
        val a = adapter ?: return false
        if (!hasPermissions(false)) return false
        return try {
            a.bondedDevices.any { it.address == address }
        } catch (e: SecurityException) {
            false
        }
    }

    /// Empareja (diálogo del sistema). El resultado llega por evento
    /// bonded/bondFailed — createBond() solo indica si se INICIÓ.
    private fun startBond(address: String): Boolean {
        val a = adapter ?: return false
        if (!hasPermissions(false)) {
            emit(mapOf("kind" to "error", "code" to "permissions")); return false
        }
        return try {
            val dev = a.getRemoteDevice(address)
            if (dev.bondState == BluetoothDevice.BOND_BONDED) {
                emit(mapOf("kind" to "bonded", "address" to address))
                true
            } else {
                dev.createBond()
            }
        } catch (e: SecurityException) {
            emit(mapOf("kind" to "error", "code" to "permissions")); false
        } catch (e: IllegalArgumentException) {
            false
        }
    }

    // ── Limpieza total ──────────────────────────────────────────────────────

    private fun destroy() {
        cancelDiscovery()
        stopServer()
        stopClient()
    }

    /// Envía un evento a Dart SIEMPRE en el hilo principal.
    private fun emit(payload: Map<String, Any?>) {
        val s = sink ?: return
        main.post { s.success(payload) }
    }
}

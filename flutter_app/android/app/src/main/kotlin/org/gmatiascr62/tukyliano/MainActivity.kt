package org.gmatiascr62.tukyliano

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Hereda de AudioServiceActivity y no de FlutterActivity porque sin eso el
// servicio de audio no se engancha con la app: al tocar la notificación con
// la pantalla bloqueada se abriría una copia nueva en vez de volver a la que
// ya está sonando. AudioServiceActivity ES una FlutterActivity.
//
// Lo demás que hay acá son dos cosas que Flutter no sabe hacer solo y que el
// audio en segundo plano necesita: pedir permiso para notificar, y sostener
// el Wi-Fi mientras suena una radio.
class MainActivity : AudioServiceActivity() {

    private var candadoDelWifi: WifiManager.WifiLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pedirPoderNotificar()
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler {
            llamada, contestar ->
            when (llamada.method) {
                "puedeNotificar" -> contestar.success(puedeNotificar())
                "comoEstaElServicio" -> contestar.success(comoEstaElServicio())
                "agarrarElWifi" -> { agarrarElWifi(); contestar.success(null) }
                "soltarElWifi" -> { soltarElWifi(); contestar.success(null) }
                else -> contestar.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        soltarElWifi()
        super.onDestroy()
    }

    // Desde Android 13 hay que pedirle permiso al usuario para mostrar
    // notificaciones, y sin notificación no hay audio en segundo plano: la
    // notificación con los controles ES el permiso de seguir sonando.
    //
    // Se pide al abrir la app y no al tocar play porque hacerlo desde Flutter
    // necesitaría otra biblioteca. Es un toque, una sola vez. Android no
    // vuelve a preguntar si ya dijeron que no dos veces: por eso la app
    // también muestra si el permiso está dado o no.
    private fun pedirPoderNotificar() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (puedeNotificar()) return
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), PEDIDO)
    }

    private fun puedeNotificar(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    // Le pregunta a Android si el servicio de audio está corriendo y si está
    // en primer plano.
    //
    // Esto existe porque buscando por qué el audio se cortaba se gastaron
    // cuatro versiones adivinando: si el servicio arrancaba, si publicaba la
    // notificación, si era el permiso, si era el celular. Nada de eso se veía
    // desde adentro de la app. Esto lo contesta el sistema operativo, que es
    // el único que sabe.
    //
    // getRunningServices está obsoleto para espiar a otras apps, pero sigue
    // devolviendo los servicios propios, que es justo lo que se necesita.
    @Suppress("DEPRECATION")
    private fun comoEstaElServicio(): String {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mio = am.getRunningServices(Integer.MAX_VALUE).firstOrNull {
            it.service.className.contains("audioservice.AudioService")
        } ?: return "servicio: no corre"
        return if (mio.foreground) "servicio: primer plano" else "servicio: de fondo"
    }

    // El servicio de audio ya sostiene la CPU despierta, pero NO el Wi-Fi.
    // Con la pantalla apagada el Wi-Fi entra en ahorro de energía, y una
    // radio en vivo se queda sin datos a los pocos segundos. Un episodio del
    // podcast no, porque sale de un archivo que está en el celular: por eso
    // el podcast seguía sonando y la radio no.
    //
    // HIGH_PERF es el modo que no deja dormir la antena. Se agarra solo
    // mientras suena una radio y se suelta al pausar: sostenerlo de más gasta
    // batería para nada.
    private fun agarrarElWifi() {
        if (candadoDelWifi?.isHeld == true) return
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val candado = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, CANDADO)
        candado.setReferenceCounted(false)
        candado.acquire()
        candadoDelWifi = candado
    }

    private fun soltarElWifi() {
        candadoDelWifi?.let { if (it.isHeld) it.release() }
        candadoDelWifi = null
    }

    private companion object {
        const val CANAL = "org.gmatiascr62.tukyliano/android"
        const val CANDADO = "tukyliano:radio"
        const val PEDIDO = 1001
    }
}

package org.gmatiascr62.tukyliano

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

// Hereda de AudioServiceActivity y no de FlutterActivity porque sin eso el
// servicio de audio no se engancha con la app: al tocar la notificación con
// la pantalla bloqueada se abriría una copia nueva en vez de volver a la que
// ya está sonando. No agrega nada más; AudioServiceActivity ES una
// FlutterActivity.
class MainActivity : AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pedirPoderNotificar()
    }

    // Desde Android 13 hay que pedirle permiso al usuario para mostrar
    // notificaciones, y sin notificación no hay audio en segundo plano: la
    // notificación con los controles ES el permiso de seguir sonando.
    //
    // Se pide al abrir la app y no al tocar play porque hacerlo desde Flutter
    // necesitaría un canal y una biblioteca más. Es un toque, una sola vez.
    // Si el usuario dice que no, la app anda igual: el audio suena mientras
    // la pantalla esté encendida.
    private fun pedirPoderNotificar() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return

        val permiso = Manifest.permission.POST_NOTIFICATIONS
        if (checkSelfPermission(permiso) == PackageManager.PERMISSION_GRANTED) return

        requestPermissions(arrayOf(permiso), PEDIDO_DE_NOTIFICACIONES)
    }

    private companion object {
        const val PEDIDO_DE_NOTIFICACIONES = 1001
    }
}

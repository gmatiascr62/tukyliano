package org.gmatiascr62.tukyliano

import com.ryanheise.audioservice.AudioServiceActivity

// Hereda de AudioServiceActivity y no de FlutterActivity porque sin eso el
// servicio de audio no se engancha con la app: al tocar la notificación con
// la pantalla bloqueada se abriría una copia nueva en vez de volver a la que
// ya está sonando. No agrega nada más; AudioServiceActivity ES una
// FlutterActivity.
class MainActivity : AudioServiceActivity()

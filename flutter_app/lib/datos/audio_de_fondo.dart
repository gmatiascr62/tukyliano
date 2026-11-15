import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:just_audio_background/just_audio_background.dart';

/// Lo que hace que el podcast y la radio sigan sonando con la pantalla
/// bloqueada.
///
/// Android no deja que una app en segundo plano reproduzca audio porque sí:
/// hace falta un servicio en primer plano, y un servicio en primer plano es
/// una notificación con los controles. Esto lo prende.
///
/// **El resultado se guarda y se muestra.** La primera versión de esto
/// atrapaba el error y lo escribía con debugPrint, que en un APK instalado no
/// lo lee nadie. Resultado: el audio se cortaba a los treinta segundos, no
/// aparecía ninguna notificación, y desde afuera no había forma de saber si
/// era el celular o la app. Un error que no se ve cuesta horas; este costó
/// una versión entera.
class AudioDeFondo {
  const AudioDeFondo._();

  /// True cuando el servicio quedó prendido. Mientras no se haya intentado,
  /// también es true: no hay nada que avisar todavía.
  static bool get anda => _anda;
  static bool _anda = true;

  /// Por qué no se pudo prender, si no se pudo. Null cuando anduvo.
  static String? get porQueNo => _porQueNo;
  static String? _porQueNo;

  /// Prende el servicio. Se llama una vez, al arrancar la app.
  ///
  /// Si falla, la app arranca igual: el audio suena mientras la pantalla esté
  /// encendida, que es como andaba antes de todo esto. Lo que no hace es
  /// fallar en silencio.
  static Future<void> prender() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'org.gmatiascr62.tukyliano.audio',
        androidNotificationChannelName: 'Audio de Tukyliano',
        // Para que el sistema no la pueda descartar mientras algo está
        // sonando: si se va la notificación, se va el permiso de seguir
        // sonando. Al pausar vuelve a ser descartable sola.
        androidNotificationOngoing: true,
        notificationColor: _verde,
      );
      _anda = true;
      _porQueNo = null;
    } catch (e) {
      _anda = false;
      _porQueNo = '$e';
    }
  }

  /// Para los tests: hacer de cuenta que el servicio anduvo o no, sin tener
  /// que prender nada de verdad.
  @visibleForTesting
  static void comoSi({required bool anda, String? porQue}) {
    _anda = anda;
    _porQueNo = porQue;
  }

  /// El verde del logo. Va a mano y no desde Tema para que este archivo no
  /// dependa de la pantalla.
  static const _verde = Color(0xFF58A030);
}

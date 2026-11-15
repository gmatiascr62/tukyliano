import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// Las dos cosas que el audio en segundo plano necesita y Flutter no sabe
/// hacer solo. Del otro lado está MainActivity.kt.
class Android {
  const Android._();

  static const MethodChannel _canal =
      MethodChannel('org.gmatiascr62.tukyliano/android');

  /// Si el usuario le dio permiso a la app para mostrar notificaciones.
  ///
  /// Importa porque la notificación con los controles **es** el permiso de
  /// seguir sonando: sin ella no aparece el reproductor en la barra y Android
  /// termina cortando el audio. Y porque Android deja de preguntar si ya
  /// dijeron que no dos veces, así que hay que poder mirarlo.
  static bool get puedeNotificar => _puedeNotificar;
  static bool _puedeNotificar = true;

  /// Se pregunta una vez al arrancar.
  static Future<void> preguntarSiPuedeNotificar() async {
    try {
      _puedeNotificar =
          await _canal.invokeMethod<bool>('puedeNotificar') ?? true;
    } catch (_) {
      // En los tests y fuera de Android no hay nadie del otro lado. No es un
      // problema: lo que no se puede averiguar se da por bueno.
      _puedeNotificar = true;
    }
  }

  /// Sostiene el Wi-Fi mientras suena una radio.
  ///
  /// El servicio de audio ya mantiene la CPU despierta, pero no la antena:
  /// con la pantalla apagada el Wi-Fi entra en ahorro y un stream en vivo se
  /// queda sin datos. Un archivo del celular no, y por eso el podcast seguía
  /// sonando con la pantalla bloqueada y la radio no.
  static Future<void> agarrarElWifi() => _llamar('agarrarElWifi');

  /// Se suelta al pausar: sostenerlo de más gasta batería para nada.
  static Future<void> soltarElWifi() => _llamar('soltarElWifi');

  static Future<void> _llamar(String que) async {
    try {
      await _canal.invokeMethod<void>(que);
    } catch (_) {
      // Sin Wi-Fi sostenido la radio igual suena mientras la pantalla esté
      // encendida: no es motivo para tirar nada abajo.
    }
  }

  /// Para los tests.
  @visibleForTesting
  static void comoSi({required bool puedeNotificar}) =>
      _puedeNotificar = puedeNotificar;
}

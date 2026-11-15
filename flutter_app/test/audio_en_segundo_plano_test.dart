import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/audio_de_fondo.dart';

/// Que el audio siga sonando con la pantalla bloqueada no depende de ninguna
/// línea de Dart: depende de cuatro cosas del lado de Android. Ninguna de las
/// cuatro la verifica el compilador, y si falta una el síntoma es siempre el
/// mismo —el audio se corta al bloquear el celular— sin ningún error que lo
/// explique.
///
/// Por eso están acá: son tests de archivos de configuración, que es raro,
/// pero el día que alguien toque el manifest sin saber esto, se entera.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final actividad = File(
    'android/app/src/main/kotlin/org/gmatiascr62/tukyliano/MainActivity.kt',
  ).readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('el audio en segundo plano', () {
    test('está el permiso para poder mostrar la notificación', () {
      // Desde Android 13 sin esto no se muestra NINGUNA notificación, y sin
      // notificación Android corta el audio al rato de que la app deja de
      // estar a la vista. audio_service no lo declara: es nuestro.
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });

    test('el permiso además se le pide al usuario en pantalla', () {
      // Declararlo no alcanza: desde Android 13 hay que pedirlo en tiempo de
      // ejecución o el sistema lo da por denegado.
      expect(actividad, contains('POST_NOTIFICATIONS'));
      expect(actividad, contains('requestPermissions'));
    });

    test('están los tres permisos que hacen falta', () {
      // WAKE_LOCK para que el celular no se duerma del todo mientras suena.
      // FOREGROUND_SERVICE para poder levantar el servicio.
      // ..._MEDIA_PLAYBACK porque Android 14 pide decir para qué es.
      for (final permiso in const [
        'android.permission.WAKE_LOCK',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      ]) {
        expect(manifest, contains(permiso), reason: 'falta $permiso');
      }
    });

    test('está declarado el servicio que reproduce', () {
      expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
      // Sin el tipo, Android 14 tira la app abajo al arrancar el servicio.
      expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    });

    test('está el receptor de los botones del auricular', () {
      expect(
        manifest,
        contains('com.ryanheise.audioservice.MediaButtonReceiver'),
      );
      expect(manifest, contains('android.intent.action.MEDIA_BUTTON'));
    });

    test('la actividad es la que sabe del servicio de audio', () {
      // Sin esto, tocar la notificación con la pantalla bloqueada abre una
      // copia nueva de la app en vez de volver a la que está sonando.
      expect(actividad, contains('AudioServiceActivity'));
      expect(actividad, isNot(contains('FlutterActivity()')));
    });

    test('está el paquete que levanta todo esto', () {
      expect(pubspec, contains('just_audio_background'));
    });

    test('si no se puede prender, queda anotado el motivo', () {
      // La primera versión atrapaba el error y lo escribía con debugPrint,
      // que en un APK instalado no lo lee nadie: el audio se cortaba a los
      // treinta segundos y desde afuera no había forma de saber por qué.
      AudioDeFondo.comoSi(anda: false, porQue: 'no se pudo, de mentira');

      expect(AudioDeFondo.anda, isFalse);
      expect(AudioDeFondo.porQueNo, 'no se pudo, de mentira');

      AudioDeFondo.comoSi(anda: true);
      expect(AudioDeFondo.porQueNo, isNull);
    });
  });
}

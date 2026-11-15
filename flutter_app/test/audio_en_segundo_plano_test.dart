import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  });
}

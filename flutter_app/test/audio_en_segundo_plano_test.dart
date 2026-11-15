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

    test('se usa audio_service directo', () {
      // just_audio_background hace lo mismo con tres renglones, pero lleva
      // años en beta y acá no andaba: el servicio arrancaba, el audio sonaba
      // y la notificación no aparecía nunca. Fallaba en silencio y no había
      // dónde mirar. Su propio README recomienda este camino.
      expect(pubspec, matches(RegExp(r'^  audio_service:', multiLine: true)));
      // El nombre aparece en el comentario que explica por qué no se usa, así
      // que lo que se mira es que no sea una dependencia.
      expect(
        pubspec,
        isNot(matches(RegExp(r'^  just_audio_background:', multiLine: true))),
      );
    });

    test('alguien le sostiene el Wi-Fi a la radio', () {
      // El servicio de audio mantiene la CPU despierta pero NO la antena:
      // con la pantalla apagada el Wi-Fi entra en ahorro y un stream en vivo
      // se queda sin datos. Un archivo del celular no, y por eso el podcast
      // seguía sonando con la pantalla bloqueada y la radio no.
      expect(actividad, contains('WIFI_MODE_FULL_HIGH_PERF'));
      final reproductor =
          File('lib/datos/reproductor.dart').readAsStringSync();
      expect(reproductor, contains('agarrarElWifi'));
      expect(reproductor, contains('soltarElWifi'));
    });

    test('se puede saber si el permiso de notificar está dado', () {
      // Android deja de preguntar después de dos negativas, así que si no se
      // puede mirar, el permiso queda apagado para siempre sin que nadie sepa
      // por qué el audio se corta.
      expect(actividad, contains('puedeNotificar'));
    });

    test('alguien le cuenta a Android qué está sonando', () {
      // Esto es lo que hace aparecer la notificación, y la notificación es lo
      // que deja seguir sonando en segundo plano. Sin esta cuenta no hay
      // nada.
      final fuente = File('lib/datos/audio_de_fondo.dart').readAsStringSync();
      expect(fuente, contains('playbackState.add'));
      expect(fuente, contains('mediaItem.add'));
    });

    test('escucha el stream que sí avisa cuando se toca play', () {
      // Este test existe por un bug que tuvo el audio en segundo plano sin
      // andar durante cuatro versiones, y que no se ve mirando la línea.
      //
      // Adentro de just_audio:
      //   _playbackEventSubject.addStream(
      //       playerEventStream.map((e) => e.playbackEvent).distinct());
      //
      // Si está sonando o no NO vive en playbackEvent, vive en playerEvent.
      // Al tocar play el playbackEvent no cambia, el .distinct() se come el
      // evento y playbackEventStream no emite. Y el servicio de Android
      // levanta la notificación SOLO en la transición a "sonando", que así
      // nunca le llegaba.
      final fuente = File('lib/datos/audio_de_fondo.dart').readAsStringSync();
      final escucha = RegExp(r'reproductor\?\.(\w+)\.listen')
          .allMatches(fuente)
          .map((m) => m.group(1))
          .toList();

      expect(escucha, contains('playerEventStream'));
      expect(
        escucha,
        isNot(contains('playbackEventStream')),
        reason: 'ese no avisa cuando se toca play',
      );
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

// El álbum del viaje: una foto cada dos lecciones.
//
// Lo que se mide acá es la cuenta del premio, que es lo único que el
// alumno ve y lo único que no se puede mirar en una captura: si se abre
// una foto de más, el álbum se termina antes que la ciudad; si se abre
// una de menos, la última no se abre nunca.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';
import 'package:tukyliano/logica/album.dart';
import 'package:tukyliano/modelos/percorso.dart';

Ciudad _olbia() => Ciudad(
  id: 'olbia',
  nombre: 'Olbia',
  lecciones: [
    for (var i = 1; i <= 10; i++) Leccion(id: 'olbia-$i', titulo: 'Lección $i'),
    const Leccion(id: 'olbia-prueba', titulo: 'La prueba', esPrueba: true),
  ],
  album: const [
    Foto(archivo: 'olbia-1.jpg', texto: 'Llegada'),
    Foto(archivo: 'olbia-2.jpg'),
    Foto(archivo: 'olbia-3.jpg'),
    Foto(archivo: 'olbia-4.jpg'),
    Foto(archivo: 'olbia-5.jpg'),
  ],
);

Progreso _con(List<String> hechas) {
  final progreso = Progreso(carpeta: () async => null);
  for (final id in hechas) {
    progreso.termino(id);
  }
  return progreso;
}

void main() {
  test('de cero no hay ninguna abierta, y cada una dice cuánto falta', () {
    final album = albumDelViaje([_olbia()], _con(const []));

    expect(album.length, 5);
    expect(album.every((f) => !f.abierta), isTrue);
    expect(album.map((f) => f.faltan), [2, 4, 6, 8, 10]);
  });

  test('cada dos lecciones se abre una', () {
    for (final (hechas, abiertas) in [
      (1, 0),
      (2, 1),
      (3, 1),
      (4, 2),
      (9, 4),
      (10, 5),
    ]) {
      final progreso = _con([for (var i = 1; i <= hechas; i++) 'olbia-$i']);
      final album = albumDelViaje([_olbia()], progreso);

      expect(
        cuantasAbiertas(album),
        abiertas,
        reason: 'con $hechas lecciones tienen que estar $abiertas abiertas',
      );
    }
  });

  test('las diez lecciones abren las cinco, ni una menos', () {
    // El caso que más importa: terminar la ciudad y que quede una foto
    // tapada para siempre sería prometer algo que no se puede cumplir.
    final progreso = _con([for (var i = 1; i <= 10; i++) 'olbia-$i']);

    expect(albumDelViaje([_olbia()], progreso).every((f) => f.abierta), isTrue);
  });

  test('la prueba no cuenta: el premio es de las lecciones', () {
    final soloLaPrueba = albumDelViaje([_olbia()], _con(['olbia-prueba']));

    expect(cuantasAbiertas(soloLaPrueba), 0);
    expect(soloLaPrueba.first.faltan, 2);
  });

  test('una ciudad sin fotos no mete huecos en el álbum', () {
    // Hoy sólo Olbia tiene álbum. Sin esto, Cagliari y las otras cinco
    // aparecerían como filas vacías.
    const cagliari = Ciudad(id: 'cagliari', nombre: 'Cagliari', lecciones: []);
    final album = albumDelViaje([_olbia(), cagliari], _con(const []));

    expect(album.length, 5);
    expect(album.every((f) => f.ciudad.id == 'olbia'), isTrue);
  });

  test('cada foto sabe de qué ciudad es y qué archivo mostrar', () {
    final album = albumDelViaje([_olbia()], _con(const []));

    expect(album.first.ciudad.nombre, 'Olbia');
    expect(album.first.foto.archivo, 'olbia-1.jpg');
    expect(album.first.foto.texto, 'Llegada');
  });

  test('toda foto declarada en el camino existe, y tiene su pie', () {
    // Se mide sobre el archivo que se publica, no sobre datos de prueba.
    // Un nombre mal escrito acá no rompe nada: la tarjeta queda con el
    // cuadro roto y recién se ve abriendo el álbum con esa lección hecha,
    // que puede ser semanas después.
    final json =
        jsonDecode(File('assets/percorso.json').readAsStringSync())
            as Map<String, dynamic>;
    final ciudades = [
      for (final c in json['ciudades'] as List) ?Ciudad.desdeJson(c),
    ];

    var cuantas = 0;
    for (final ciudad in ciudades) {
      for (final foto in ciudad.album) {
        cuantas++;
        expect(
          File('assets/album/${foto.archivo}').existsSync(),
          isTrue,
          reason: '${ciudad.id}: falta assets/album/${foto.archivo}',
        );
        expect(
          foto.texto,
          isNotEmpty,
          reason: '${ciudad.id}: ${foto.archivo} sin pie de foto',
        );
      }
      // Una ciudad con álbum tiene que poder abrirlo entero: si hubiera
      // más fotos que pares de lecciones, la última no se abriría nunca.
      if (ciudad.album.isNotEmpty) {
        expect(
          ciudad.album.length * leccionesPorFoto,
          lessThanOrEqualTo(ciudad.cuantasLecciones),
          reason: '${ciudad.id} tiene más fotos que lecciones para abrirlas',
        );
      }
    }
    expect(cuantas, greaterThan(0), reason: 'el álbum no puede estar vacío');
  });

  test('el camino de verdad trae las fotos de Olbia', () {
    // Que el modelo lea `album` del json, no sólo que la clase lo tenga.
    final ciudad = Ciudad.desdeJson({
      'id': 'olbia',
      'nombre': 'Olbia',
      'album': [
        {'archivo': 'olbia-1.jpg', 'texto': 'Llegada a Olbia'},
        {'texto': 'sin archivo: se descarta'},
      ],
    });

    expect(ciudad!.album.length, 1);
    expect(ciudad.album.first.archivo, 'olbia-1.jpg');
    expect(ciudad.album.first.texto, 'Llegada a Olbia');
  });
}

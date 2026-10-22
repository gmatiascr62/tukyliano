import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/logica/capacidad.dart';

/// Un /proc/meminfo como el de un celular, con la memoria que se le pida.
File _meminfoCon(int gigas) {
  final dir = Directory.systemTemp.createTempSync('meminfo');
  addTearDown(() => dir.deleteSync(recursive: true));
  final archivo = File('${dir.path}/meminfo');
  final kb = (gigas * 1024 * 1024).round();
  archivo.writeAsStringSync('''
MemTotal:       $kb kB
MemFree:         1234567 kB
MemAvailable:    2345678 kB
''');
  return archivo;
}

void main() {
  group('cuánta memoria tiene el celular', () {
    test('lo lee de /proc/meminfo', () async {
      final capacidad = await mirarElCelular(archivo: _meminfoCon(8));

      expect(capacidad.memoriaMb, closeTo(8 * 1024, 2));
    });

    test('con 8 GB va cómodo y no avisa nada', () async {
      final capacidad = await mirarElCelular(archivo: _meminfoCon(8));

      expect(capacidad.queTanBien, QueTanBien.bien);
      expect(capacidad.puede, isTrue);
      expect(capacidad.aviso, isEmpty);
    });

    test('con 4 GB anda, pero lo avisa', () async {
      final capacidad = await mirarElCelular(archivo: _meminfoCon(4));

      expect(capacidad.queTanBien, QueTanBien.justo);
      expect(capacidad.puede, isTrue);
      expect(capacidad.aviso, contains('lento'));
    });

    test('con 3 GB no se deja ni empezar', () async {
      // Bajarse mil megas para que después la app se cierre sola es peor que
      // decirlo antes. Eran 2 GB cuando el modelo pesaba un tercio.
      final capacidad = await mirarElCelular(archivo: _meminfoCon(3));

      expect(capacidad.queTanBien, QueTanBien.no);
      expect(capacidad.puede, isFalse);
      expect(capacidad.aviso, contains('4 GB'));
    });

    test('sin poder averiguarlo, deja probar', () async {
      // Pasa en la computadora y en los tests. No es razón para trabar a
      // nadie.
      final dir = Directory.systemTemp.createTempSync('sin_meminfo');
      addTearDown(() => dir.deleteSync(recursive: true));

      final capacidad = await mirarElCelular(
        archivo: File('${dir.path}/no_existe'),
      );

      expect(capacidad.memoriaMb, 0);
      expect(capacidad.puede, isTrue);
      expect(capacidad.aviso, isEmpty);
    });

    test('un meminfo raro no rompe nada', () async {
      final dir = Directory.systemTemp.createTempSync('meminfo_roto');
      addTearDown(() => dir.deleteSync(recursive: true));
      final archivo = File('${dir.path}/meminfo')
        ..writeAsStringSync('esto no es un meminfo');

      final capacidad = await mirarElCelular(archivo: archivo);

      expect(capacidad.memoriaMb, 0);
      expect(capacidad.puede, isTrue);
    });
  });

  group('cuántos hilos usar', () {
    test('la mitad de los núcleos', () {
      // Usar los ocho no acelera —los núcleos chicos frenan a los grandes—
      // pero sí calienta el teléfono.
      expect(hilosParaElModelo(nucleos: 8), 4);
      expect(hilosParaElModelo(nucleos: 6), 3);
    });

    test('nunca menos de dos ni más de cuatro', () {
      expect(hilosParaElModelo(nucleos: 1), 2);
      expect(hilosParaElModelo(nucleos: 2), 2);
      expect(hilosParaElModelo(nucleos: 16), 4);
    });
  });
}

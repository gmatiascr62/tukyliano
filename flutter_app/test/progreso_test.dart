import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/progreso.dart';

void main() {
  late Directory carpeta;

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('progreso');
  });

  tearDown(() => carpeta.deleteSync(recursive: true));

  Progreso abrir() => Progreso(carpeta: () async => carpeta);

  File elArchivo() => File('${carpeta.path}/$archivoProgreso');

  test('arranca en cero', () async {
    final progreso = abrir();
    await progreso.cargar();

    expect(progreso.aciertos, 0);
    expect(progreso.diasPracticados, 0);
  });

  test('los aciertos se guardan y siguen ahí la próxima vez', () async {
    final progreso = abrir();
    await progreso.cargar();
    progreso.acerto();
    progreso.acerto();
    // El guardado es asincrónico solo para averiguar la carpeta.
    await Future<void>.delayed(Duration.zero);

    final otraVez = abrir();
    await otraVez.cargar();

    expect(otraVez.aciertos, 2);
  });

  test('acertar también cuenta como haber practicado hoy', () async {
    final progreso = abrir();
    await progreso.cargar();
    progreso.acerto();

    expect(progreso.diasPracticados, 1);
  });

  test('entrar sin acertar nada igual cuenta como practicar', () async {
    final progreso = abrir();
    await progreso.cargar();
    progreso.practico();

    expect(progreso.aciertos, 0);
    expect(progreso.diasPracticados, 1);
  });

  test('practicar dos veces el mismo día cuenta un día', () async {
    final progreso = abrir();
    await progreso.cargar();
    progreso.practico();
    progreso.acerto();
    progreso.acerto();

    expect(progreso.diasPracticados, 1);
  });

  test('solo cuenta los días de la última semana', () async {
    final hoy = DateTime.now();
    String comoTexto(DateTime dia) =>
        '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
        '${dia.day.toString().padLeft(2, '0')}';

    elArchivo().writeAsStringSync(jsonEncode({
      'aciertos': 12,
      'dias': [
        comoTexto(hoy),
        comoTexto(hoy.subtract(const Duration(days: 3))),
        // Este ya no entra en los últimos siete.
        comoTexto(hoy.subtract(const Duration(days: 20))),
      ],
    }));

    final progreso = abrir();
    await progreso.cargar();

    expect(progreso.aciertos, 12);
    expect(progreso.diasPracticados, 2);
  });

  test('un archivo roto no impide usar la app', () async {
    elArchivo().writeAsStringSync('esto no es json {{{');

    final progreso = abrir();
    await progreso.cargar();

    expect(progreso.aciertos, 0);
  });

  test('sin carpeta donde guardar, el progreso vale para la sesión', () async {
    final progreso = Progreso(carpeta: () async => null);
    await progreso.cargar();
    progreso.acerto();

    expect(progreso.aciertos, 1);
  });
}

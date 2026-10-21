import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/datos/intento_de_carga.dart';

void main() {
  late Directory carpeta;

  setUp(() => carpeta = Directory.systemTemp.createTempSync('intento'));
  tearDown(() => carpeta.deleteSync(recursive: true));

  IntentoDeCarga abrir() => IntentoDeCarga(carpeta: () async => carpeta);

  File laMarca() => File('${carpeta.path}/$archivoDelIntento');

  test('la primera vez no hay nada que contar', () async {
    expect(await abrir().seCerroLaVezPasada(), isFalse);
  });

  test('una carga que termina bien no deja marca', () async {
    final intento = abrir();

    await intento.empiezo();
    await intento.salioBien();

    expect(laMarca().existsSync(), isFalse);
    expect(await abrir().seCerroLaVezPasada(), isFalse);
  });

  test('si la app se muere cargando, la marca queda', () async {
    // Esto es lo que pasa de verdad: empiezo() escribe, el código nativo
    // tumba el proceso y salioBien() nunca llega a correr.
    final intento = abrir();
    await intento.empiezo();

    expect(laMarca().existsSync(), isTrue);
    expect(await abrir().seCerroLaVezPasada(), isTrue);
  });

  test('la marca se escribe en el acto, no cuando el sistema quiera', () async {
    // Sin flush, la app podría morirse con la marca todavía en un buffer y el
    // aviso se perdería justo cuando hace falta.
    await abrir().empiezo();

    expect(laMarca().readAsStringSync(), isNotEmpty);
  });

  test('después de avisar se limpia, para no avisar para siempre', () async {
    final intento = abrir();
    await intento.empiezo();

    await intento.salioBien();

    expect(await abrir().seCerroLaVezPasada(), isFalse);
  });

  test('sin carpeta donde escribir, no molesta a nadie', () async {
    final intento = IntentoDeCarga(carpeta: () async => null);

    await intento.empiezo();

    expect(await intento.seCerroLaVezPasada(), isFalse);
    await expectLater(intento.salioBien(), completes);
  });
}

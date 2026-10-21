import 'package:tukyliano/datos/intento_de_carga.dart';

/// Un recuerdo de mentira, en memoria, para los tests de pantalla.
///
/// Igual que con la descarga: adentro de un test de widget el disco de verdad
/// no termina nunca. El de verdad se prueba en intento_de_carga_test.dart.
class IntentoFalso implements IntentoDeCarga {
  IntentoFalso({this.seCerro = false});

  bool seCerro;
  int empezados = 0;
  int terminados = 0;

  @override
  Future<bool> seCerroLaVezPasada() async => seCerro;

  @override
  Future<void> empiezo() async => empezados++;

  @override
  Future<void> salioBien() async {
    terminados++;
    seCerro = false;
  }
}

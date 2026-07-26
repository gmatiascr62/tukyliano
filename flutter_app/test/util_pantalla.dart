import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Los tests de widget corren por defecto en una superficie de 800x600, que es
/// más baja que cualquier celular: el teclado no entra y los toques caen fuera
/// de la pantalla. Esto la deja en un tamaño realista de celular.
void usarPantallaDeCelular(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

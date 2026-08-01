import 'package:flutter/material.dart';

/// Texto que se achica hasta entrar en el ancho disponible, en un solo
/// renglón y sin cortarse nunca con puntos suspensivos. Se usa donde el
/// alumno escribe y donde se muestra la respuesta correcta: ahí siempre hay
/// que poder leer todo.
///
/// El achicado lo hace [FittedBox], no una medición propia. La versión
/// anterior medía con un TextPainter y elegía un tamaño, pero medía con una
/// tipografía y el celular dibujaba con otra (el tema pide 'Roboto' y la
/// medición usaba la del sistema), así que a veces la cuenta daba "entra" y
/// en pantalla igual se recortaba. FittedBox mide el texto ya armado, con la
/// tipografía de verdad, y lo escala: no hay dos mediciones que puedan no
/// coincidir.
class TextoAjustado extends StatelessWidget {
  const TextoAjustado(
    this.texto, {
    super.key,
    required this.estilo,
    this.alineacion = TextAlign.center,
    this.trozos,
  });

  final String texto;
  final TextStyle estilo;
  final TextAlign alineacion;

  /// Partes con estilo propio (para colorear palabra por palabra). Si viene,
  /// se usan en lugar de [texto].
  final List<TextSpan>? trozos;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      // scaleDown solo achica: un texto corto queda en su tamaño original.
      fit: BoxFit.scaleDown,
      child: Text.rich(
        trozos == null
            ? TextSpan(text: texto, style: estilo)
            : TextSpan(style: estilo, children: trozos),
        textAlign: alineacion,
        maxLines: 1,
        // Sin corte de línea y sin puntos suspensivos: el texto se dibuja
        // entero y del achicado se encarga el FittedBox.
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    );
  }
}

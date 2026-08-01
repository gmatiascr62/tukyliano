import 'package:flutter/material.dart';

/// Texto que se achica hasta entrar en el ancho disponible, en vez de
/// cortarse con puntos suspensivos. Se usa donde el alumno escribe y donde se
/// muestra la respuesta correcta: ahí siempre hay que poder leer todo.
///
/// Mide con un TextPainter y va bajando el tamaño de a poco hasta que entra,
/// sin pasar de [tamanoMinimo].
class TextoAjustado extends StatelessWidget {
  const TextoAjustado(
    this.texto, {
    super.key,
    required this.estilo,
    this.tamanoMinimo = 11,
    this.maxLineas = 1,
    this.alineacion = TextAlign.center,
    this.trozos,
  });

  final String texto;
  final TextStyle estilo;
  final double tamanoMinimo;
  final int maxLineas;
  final TextAlign alineacion;

  /// Partes con estilo propio (para colorear palabra por palabra). Si viene,
  /// se usan en lugar de [texto], que igual sirve para medir.
  final List<TextSpan>? trozos;

  bool _entra(double tamano, double ancho, TextScaler escala) {
    final medidor = TextPainter(
      text: TextSpan(text: texto, style: estilo.copyWith(fontSize: tamano)),
      textDirection: TextDirection.ltr,
      textAlign: alineacion,
      maxLines: maxLineas,
      textScaler: escala,
    )..layout(maxWidth: ancho);

    // didExceedMaxLines cuenta renglones, así que no detecta una palabra sola
    // más ancha que el recuadro: esa no puede cortarse y se pasa de largo sin
    // sumar un renglón. Por eso también se compara el ancho.
    return !medidor.didExceedMaxLines && medidor.width <= ancho + 0.5;
  }

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context);
    final inicial = estilo.fontSize ?? 16;

    return LayoutBuilder(
      builder: (context, limites) {
        var tamano = inicial;
        if (limites.maxWidth.isFinite && texto.isNotEmpty) {
          while (tamano > tamanoMinimo && !_entra(tamano, limites.maxWidth, escala)) {
            tamano -= 0.5;
          }
        }

        final resultado = estilo.copyWith(fontSize: tamano);
        return Text.rich(
          trozos == null
              ? TextSpan(text: texto, style: resultado)
              : TextSpan(
                  style: resultado,
                  children: [
                    for (final trozo in trozos!)
                      TextSpan(
                        text: trozo.text,
                        // El tamaño lo manda el ajuste; el resto (el color)
                        // lo trae cada trozo.
                        style: trozo.style?.copyWith(fontSize: tamano),
                      ),
                  ],
                ),
          textAlign: alineacion,
          maxLines: maxLineas,
          // Si ni con el mínimo entra, recién ahí se recorta.
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

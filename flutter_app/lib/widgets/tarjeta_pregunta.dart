import 'package:flutter/material.dart';

import '../tema.dart';

/// Tarjeta blanca donde se muestra lo que hay que traducir. La usan el quiz
/// de verbos y la práctica de frases, para que las dos se vean igual.
class TarjetaPregunta extends StatelessWidget {
  const TarjetaPregunta({
    super.key,
    required this.texto,
    this.etiqueta = '',
    this.alto = 150,
  });

  final String texto;

  /// Título chico arriba ("Traducí al italiano"). Vacío = no se muestra.
  final String etiqueta;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: alto,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        boxShadow: Tema.sombra,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (etiqueta.isNotEmpty) ...[
            Text(
              etiqueta.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Tema.verde,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Flexible(
            child: Center(
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: Tema.titulo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Puntaje del quiz, como pastilla verde suave.
class ChipPuntaje extends StatelessWidget {
  const ChipPuntaje({super.key, required this.puntaje, required this.total});

  final int puntaje;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        // El texto exacto se mantiene para no cambiar lo que ya conocía la app.
        'Puntaje: $puntaje/$total',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Tema.verdeOscuro,
        ),
      ),
    );
  }
}

/// Feedback de la respuesta, con un ícono según el resultado.
class TextoFeedback extends StatelessWidget {
  const TextoFeedback({
    super.key,
    required this.texto,
    required this.color,
    this.tamano = 18,
  });

  final String texto;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    if (texto.isEmpty) return const SizedBox.shrink();

    final esCorrecto = color == Tema.correcto;
    final esError = color == Tema.incorrecto;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (esCorrecto || esError) ...[
          Icon(
            esCorrecto ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: tamano,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

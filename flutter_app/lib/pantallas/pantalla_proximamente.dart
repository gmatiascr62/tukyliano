import 'package:flutter/material.dart';

import '../tema.dart';

/// El cartel de las secciones que ya tienen su botón pero todavía no tienen
/// ejercicios.
///
/// El botón se agrega antes que el contenido a propósito: así el lugar queda
/// reservado en la barra y se ve desde el celular cómo va a quedar repartido,
/// sin esperar a que estén las frases.
class PantallaProximamente extends StatelessWidget {
  const PantallaProximamente({super.key, required this.adelanto});

  /// Una línea contando qué se va a practicar acá.
  final String adelanto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Próximamente',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Tema.textoTenue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              adelanto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
            ),
          ],
        ),
      ),
    );
  }
}

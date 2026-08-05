import 'package:flutter/material.dart';

import '../tema.dart';

/// Lo que se ve en las secciones que todavía no están hechas.
///
/// Están en la barra desde ya, aunque no funcionen, para que se vea para
/// dónde va la app.
class Proximamente extends StatelessWidget {
  const Proximamente({super.key, required this.icono, required this.detalle});

  final IconData icono;

  /// Una línea sobre qué va a ser esa sección.
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Tema.borde),
            const SizedBox(height: 16),
            const Text(
              'Próximamente',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Tema.textoTenue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Tema.textoTenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

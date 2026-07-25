import 'package:flutter/material.dart';

import '../tema.dart';

/// Fase 1: solo el esqueleto. La práctica con IA llega en la fase 4.
class PantallaFrases extends StatelessWidget {
  const PantallaFrases({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Frases', style: TextStyle(fontSize: 20, color: Tema.titulo)),
          SizedBox(height: 8),
          Text(
            'La práctica con IA llega en la fase 4',
            style: TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }
}

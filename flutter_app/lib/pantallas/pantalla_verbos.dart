import 'package:flutter/material.dart';

import '../tema.dart';

/// Fase 1: solo el esqueleto. El quiz de conjugaciones llega en la fase 3.
class PantallaVerbos extends StatelessWidget {
  const PantallaVerbos({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Verbos', style: TextStyle(fontSize: 20, color: Tema.titulo)),
          SizedBox(height: 8),
          Text(
            'El quiz llega en la fase 3',
            style: TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }
}

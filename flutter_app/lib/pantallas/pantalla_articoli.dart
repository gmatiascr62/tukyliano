import 'package:flutter/material.dart';

import '../tema.dart';

/// Placeholder, igual que PantallaEnBlanco en la app Kivy.
class PantallaArticoli extends StatelessWidget {
  const PantallaArticoli({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Tema.verdeSuave,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 42,
              color: Tema.verde,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Articoli',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Próximamente',
            style: TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }
}

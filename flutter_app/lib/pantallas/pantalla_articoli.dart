import 'package:flutter/material.dart';

import '../tema.dart';

/// Placeholder, igual que PantallaEnBlanco en la app Kivy.
class PantallaArticoli extends StatelessWidget {
  const PantallaArticoli({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Articoli',
        style: TextStyle(fontSize: 20, color: Tema.titulo),
      ),
    );
  }
}

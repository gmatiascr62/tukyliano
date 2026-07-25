import 'package:flutter/material.dart';

import '../tema.dart';

/// Las tres secciones que se navegan desde la barra de arriba.
enum Seccion { articoli, frases, verbos }

/// Fila de navegación (Articoli / Frases / Verbos) que se repite arriba de
/// todas las pantallas, equivalente a crear_fila_botones_top de la app Kivy.
class BarraSuperior extends StatelessWidget {
  const BarraSuperior({super.key, required this.onSeccion});

  final ValueChanged<Seccion> onSeccion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          _boton('Articoli', Seccion.articoli),
          const SizedBox(width: 2),
          _boton('Frases', Seccion.frases),
          const SizedBox(width: 2),
          _boton('Verbos', Seccion.verbos),
        ],
      ),
    );
  }

  Widget _boton(String texto, Seccion seccion) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => onSeccion(seccion),
        style: ElevatedButton.styleFrom(
          backgroundColor: Tema.boton,
          foregroundColor: Tema.textoBoton,
          shape: const RoundedRectangleBorder(),
          padding: EdgeInsets.zero,
        ),
        child: Text(texto, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

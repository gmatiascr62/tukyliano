import 'package:flutter/material.dart';

import '../tema.dart';

/// Las tres secciones que se navegan desde la barra de arriba.
enum Seccion { articoli, frases, verbos }

/// Fila de navegación (Articoli / Frases / Verbos). La sección actual queda
/// resaltada, que en la versión Kivy no se distinguía.
class BarraSuperior extends StatelessWidget {
  const BarraSuperior({
    super.key,
    required this.onSeccion,
    required this.actual,
  });

  final ValueChanged<Seccion> onSeccion;
  final Seccion actual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        boxShadow: Tema.sombra,
      ),
      child: Row(
        children: [
          _boton('Articoli', Seccion.articoli),
          _boton('Frases', Seccion.frases),
          _boton('Verbos', Seccion.verbos),
        ],
      ),
    );
  }

  Widget _boton(String texto, Seccion seccion) {
    final activa = seccion == actual;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: () => onSeccion(seccion),
            style: ElevatedButton.styleFrom(
              backgroundColor: activa ? Tema.verde : Colors.transparent,
              foregroundColor: activa ? Colors.white : Tema.textoTenue,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tema.radioChico),
              ),
            ),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 15,
                fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

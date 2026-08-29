import 'package:flutter/material.dart';

import '../tema.dart';

/// Las secciones que se navegan desde la barra de arriba, en el orden en que
/// aparecen. Las primeras son las que se ven sin deslizar.
enum Seccion {
  racconti,
  leer,
  frases,
  verbos,
  articoli,
  preposizioni,
  via,
  ci,
  ne,
  chat,
}

extension EtiquetaSeccion on Seccion {
  /// Lo que dice el botón. Casi todas van en italiano, aunque el resto de la
  /// app le hable al alumno en español: son los nombres de los temas.
  String get etiqueta => switch (this) {
        Seccion.frases => 'Frasi',
        Seccion.verbos => 'Verbi',
        Seccion.articoli => 'Articoli',
        Seccion.preposizioni => 'Preposizioni',
        Seccion.via => 'Via',
        Seccion.ci => 'Ci',
        Seccion.ne => 'Ne',
        Seccion.racconti => 'Racconti',
        Seccion.leer => 'Leer',
        Seccion.chat => 'Chat',
      };
}

/// Fila de navegación. La sección actual queda resaltada.
///
/// Se desliza en horizontal porque no entran juntas en un celular, y
/// achicarlas hasta que entren dejaría "Preposizioni" ilegible. Que la última
/// quede cortada en el borde es justamente lo que avisa que hay más.
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final seccion in Seccion.values) _boton(seccion),
          ],
        ),
      ),
    );
  }

  Widget _boton(Seccion seccion) {
    final activa = seccion == actual;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: () => onSeccion(seccion),
          style: ElevatedButton.styleFrom(
            backgroundColor: activa ? Tema.verde : Colors.transparent,
            foregroundColor: activa ? Colors.white : Tema.textoTenue,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Tema.radioChico),
            ),
          ),
          child: Text(
            seccion.etiqueta,
            style: TextStyle(
              fontSize: 15,
              fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

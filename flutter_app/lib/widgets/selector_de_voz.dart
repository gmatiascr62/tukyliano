import 'package:flutter/material.dart';

import '../datos/voz.dart';
import '../tema.dart';
import 'pastilla.dart';

/// Elige entre las voces italianas que tiene el celular.
///
/// Los nombres son ciudades: los códigos que da Android ("it-it-x-itc-local")
/// no dicen si la voz es de hombre o de mujer, así que ponerle un nombre de
/// persona sería adivinar.
class SelectorDeVoz extends StatelessWidget {
  const SelectorDeVoz({
    super.key,
    required this.voces,
    required this.elegida,
    required this.alElegir,
  });

  final List<VozItaliana> voces;
  final VozItaliana elegida;
  final ValueChanged<VozItaliana> alElegir;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VozItaliana>(
      tooltip: 'Elegir la voz',
      onSelected: alElegir,
      itemBuilder: (_) => [
        for (final voz in voces)
          PopupMenuItem(
            value: voz,
            child: Row(
              children: [
                Icon(
                  voz.id == elegida.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: Tema.verde,
                ),
                const SizedBox(width: 8),
                Text(voz.nombre),
              ],
            ),
          ),
      ],
      child: Pastilla(
        texto: elegida.nombre,
        icono: Icons.record_voice_over_outlined,
      ),
    );
  }
}

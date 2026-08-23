import 'package:flutter/material.dart';

import '../tema.dart';

/// Pastilla verde. Sirve de etiqueta (el nivel de un cuento) y de botón chico
/// (la voz, la velocidad, el modo de solo escuchar); cuando está [activa] se
/// invierte el color.
class Pastilla extends StatelessWidget {
  const Pastilla({
    super.key,
    required this.texto,
    this.icono,
    this.activa = false,
    this.alTocar,
  });

  final String texto;
  final IconData? icono;
  final bool activa;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final color = activa ? Colors.white : Tema.verdeOscuro;
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        // Se achica al texto en vez de estirarse. En una fila daba igual
        // (queda sin ancho fijo), pero adentro de un Wrap cada pastilla se
        // llevaba el renglón entero.
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: activa ? Tema.verde : Tema.verdeSuave,
      borderRadius: BorderRadius.circular(20),
      child: alTocar == null
          ? contenido
          : InkWell(
              onTap: alTocar,
              borderRadius: BorderRadius.circular(20),
              child: contenido,
            ),
    );
  }
}

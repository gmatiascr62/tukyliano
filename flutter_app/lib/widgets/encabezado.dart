import 'package:flutter/material.dart';

import '../tema.dart';

/// La flecha para volver más el nombre de dónde se está.
///
/// Es lo que reemplaza a la barra de botones: adentro de una sección no hace
/// falta ver las otras nueve, hace falta saber cómo salir.
class Encabezado extends StatelessWidget {
  const Encabezado({super.key, required this.titulo, required this.alVolver});

  final String titulo;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Tema.superficie,
          borderRadius: BorderRadius.circular(Tema.radioChico),
          child: InkWell(
            onTap: alVolver,
            borderRadius: BorderRadius.circular(Tema.radioChico),
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.arrow_back, color: Tema.verde),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../tema.dart';

/// Una palabra suelta para tocar y armar la frase.
///
/// Es la misma ficha en los dos lados: abajo, en el banco, se toca para ponerla
/// en la frase; arriba, en la frase, se toca para devolverla al banco. Lo que
/// cambia es el color, para que se vea de una cuál está puesta.
class FichaPalabra extends StatelessWidget {
  const FichaPalabra({
    super.key,
    required this.palabra,
    required this.puesta,
    this.alTocar,
  });

  final String palabra;

  /// True cuando ya forma parte de la frase que se está armando.
  final bool puesta;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      // Generoso a propósito: la ficha se toca con el pulgar y muchas son de
      // dos letras.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Text(
        palabra,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: puesta ? Colors.white : Tema.titulo,
        ),
      ),
    );

    return Material(
      color: puesta ? Tema.verde : Tema.superficie,
      borderRadius: BorderRadius.circular(Tema.radio),
      elevation: puesta ? 0 : 1,
      shadowColor: const Color(0x22000000),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tema.radio),
            border: Border.all(
              color: puesta ? Colors.transparent : Tema.borde,
            ),
          ),
          child: contenido,
        ),
      ),
    );
  }
}

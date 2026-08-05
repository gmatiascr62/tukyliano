import 'package:flutter/material.dart';

import '../tema.dart';
import 'texto_ajustado.dart';

/// Uno de los botones para elegir la respuesta. Lo usan Articoli (il / lo /
/// la / l') y Preposizioni (a / al / nella / per la).
///
/// El texto se achica si no entra: la mayoría son de dos o tres letras, pero
/// "per la" y "con gli" son de dos palabras porque esas preposiciones no se
/// contraen, y no se pueden acortar sin enseñar mal.
class BotonOpcion extends StatelessWidget {
  const BotonOpcion({
    super.key,
    required this.texto,
    required this.elegido,
    required this.correcto,
    required this.habilitado,
    required this.onTocar,
  });

  final String texto;

  /// El que tocó el alumno.
  final bool elegido;

  /// El que en realidad iba. Se marca al verificar, aunque no sea el tocado.
  final bool correcto;
  final bool habilitado;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final fondo = correcto
        ? Tema.correcto
        : elegido
            ? Tema.verde
            : Tema.superficie;
    final colorTexto = correcto || elegido ? Colors.white : Tema.titulo;

    return SizedBox(
      height: 56,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: InkWell(
          onTap: habilitado ? onTocar : null,
          borderRadius: BorderRadius.circular(Tema.radio),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tema.radio),
              border: Border.all(
                color: correcto || elegido ? Colors.transparent : Tema.borde,
              ),
            ),
            child: TextoAjustado(
              texto,
              estilo: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La fila de botones de respuesta, repartida en partes iguales.
class FilaOpciones extends StatelessWidget {
  const FilaOpciones({
    super.key,
    required this.opciones,
    required this.elegido,
    required this.correcta,
    required this.mostrandoResultado,
    required this.onTocar,
  });

  final List<String> opciones;
  final String elegido;
  final String correcta;
  final bool mostrandoResultado;
  final ValueChanged<String> onTocar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final opcion in opciones) ...[
          Expanded(
            child: BotonOpcion(
              texto: opcion,
              elegido: elegido == opcion,
              correcto: mostrandoResultado && opcion == correcta,
              habilitado: !mostrandoResultado,
              onTocar: () => onTocar(opcion),
            ),
          ),
          if (opcion != opciones.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

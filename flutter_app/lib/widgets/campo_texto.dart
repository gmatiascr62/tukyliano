import 'package:flutter/material.dart';

import '../tema.dart';

const String placeholder = 'Escribí la conjugación...';

/// Recuadro blanco que muestra lo que se escribió con el teclado propio.
/// No es un campo de texto real a propósito: así nunca aparece el teclado
/// nativo de Android, que en la app Kivy trajo problemas de layout.
class CampoTexto extends StatelessWidget {
  const CampoTexto({super.key, required this.texto, this.placeholderTexto = placeholder});

  final String texto;
  final String placeholderTexto;

  @override
  Widget build(BuildContext context) {
    final vacio = texto.isEmpty;
    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        vacio ? placeholderTexto : texto,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 22,
          color: vacio ? Tema.textoTenue : Tema.texto,
        ),
      ),
    );
  }
}

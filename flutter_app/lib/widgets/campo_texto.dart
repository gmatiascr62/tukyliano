import 'package:flutter/material.dart';

import '../tema.dart';
import 'texto_ajustado.dart';

const String placeholder = 'Escribí la conjugación...';

/// Recuadro que muestra lo que se escribió con el teclado propio.
/// No es un campo de texto real a propósito: así nunca aparece el teclado
/// nativo de Android, que en la app Kivy trajo problemas de layout.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.texto,
    this.placeholderTexto = placeholder,
  });

  final String texto;
  final String placeholderTexto;

  @override
  Widget build(BuildContext context) {
    final vacio = texto.isEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 62,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(
          color: vacio ? Tema.borde : Tema.verde,
          width: vacio ? 1.5 : 2,
        ),
      ),
      // Se achica en vez de cortarse con puntos suspensivos: mientras se
      // escribe hay que poder leer todo lo escrito, aunque quede chico.
      child: TextoAjustado(
        vacio ? placeholderTexto : texto,
        estilo: TextStyle(
          fontSize: 22,
          fontWeight: vacio ? FontWeight.w400 : FontWeight.w600,
          color: vacio ? Tema.textoTenue : Tema.texto,
        ),
      ),
    );
  }
}

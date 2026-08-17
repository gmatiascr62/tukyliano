import 'package:flutter/material.dart';

import '../tema.dart';
import 'texto_ajustado.dart';

const String placeholder = 'Escribí la conjugación...';

/// Alto de un renglón solo, el de los ejercicios.
const double _altoUnaLinea = 62;

/// Hasta dónde crece el campo del chat. Más que esto le come la pantalla a la
/// charla; de ahí en adelante el texto se desliza.
const double _altoMaximoMultilinea = 108;

/// Recuadro que muestra lo que se escribió con el teclado propio.
/// No es un campo de texto real a propósito: así nunca aparece el teclado
/// nativo de Android, que en la app Kivy trajo problemas de layout.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.texto,
    this.placeholderTexto = placeholder,
    this.multilinea = false,
  });

  final String texto;
  final String placeholderTexto;

  /// En los ejercicios se escribe una palabra o una frase corta y el campo la
  /// achica para que entre en un renglón. En el chat se escriben frases enteras
  /// y achicarlas las dejaría ilegibles: con esto el texto corta de renglón y
  /// el recuadro crece.
  final bool multilinea;

  @override
  Widget build(BuildContext context) {
    final vacio = texto.isEmpty;
    final estilo = TextStyle(
      fontSize: multilinea ? 17 : 22,
      fontWeight: vacio ? FontWeight.w400 : FontWeight.w600,
      color: vacio ? Tema.textoTenue : Tema.texto,
      height: multilinea ? 1.3 : null,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      height: multilinea ? null : _altoUnaLinea,
      constraints: multilinea
          ? const BoxConstraints(
              minHeight: _altoUnaLinea,
              maxHeight: _altoMaximoMultilinea,
            )
          : null,
      // Sin alignment cuando crece: el Align que agrega el Container ocupa
      // todo el alto disponible y el recuadro quedaría siempre en su máximo.
      alignment: multilinea ? null : Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: multilinea ? 10 : 0,
      ),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(
          color: vacio ? Tema.borde : Tema.verde,
          width: vacio ? 1.5 : 2,
        ),
      ),
      child: multilinea
          // Al revés para que se vea el final: es donde se está escribiendo.
          ? SingleChildScrollView(
              reverse: true,
              child: Text(vacio ? placeholderTexto : texto, style: estilo),
            )
          // Se achica en vez de cortarse con puntos suspensivos: mientras se
          // escribe hay que poder leer todo lo escrito, aunque quede chico.
          : TextoAjustado(vacio ? placeholderTexto : texto, estilo: estilo),
    );
  }
}

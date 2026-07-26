import 'package:flutter/material.dart';

import '../logica/seleccion_azar.dart';
import '../tema.dart';

/// Filas del teclado propio, iguales a las de la app Kivy.
const List<List<String>> filasTeclado = [
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm', teclaBorrar],
  ['à', 'è', 'é', 'ì', 'ò', 'ù'],
];

/// Teclado italiano propio (letras + acentos + espacio + borrar). Se usa en
/// vez del teclado nativo para tener las vocales acentuadas a mano.
class Teclado extends StatelessWidget {
  const Teclado({super.key, required this.onTecla});

  final ValueChanged<String> onTecla;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fila in filasTeclado) ...[
          _Fila(teclas: fila, onTecla: onTecla),
          const SizedBox(height: 6),
        ],
        SizedBox(
          height: 52,
          child: _Tecla(texto: teclaEspacio, onTecla: onTecla),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.teclas, required this.onTecla});

  final List<String> teclas;
  final ValueChanged<String> onTecla;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          for (int i = 0; i < teclas.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _Tecla(texto: teclas[i], onTecla: onTecla)),
          ],
        ],
      ),
    );
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla({required this.texto, required this.onTecla});

  final String texto;
  final ValueChanged<String> onTecla;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => onTecla(texto),
      style: ElevatedButton.styleFrom(
        backgroundColor: Tema.boton,
        foregroundColor: Tema.textoBoton,
        shape: const RoundedRectangleBorder(),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: texto == teclaBorrar ? 18 : 20),
      ),
    );
  }
}

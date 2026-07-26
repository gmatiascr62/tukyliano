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

/// Alto de cada tecla. Un poco más que los dp(52) de la app Kivy: sobraba
/// espacio arriba del teclado y las teclas se veían chicas.
const double altoTecla = 58;

/// Teclado italiano propio (letras + acentos + espacio + borrar). Se usa en
/// vez del teclado nativo para tener las vocales acentuadas a mano.
class Teclado extends StatelessWidget {
  const Teclado({super.key, required this.onTecla});

  final ValueChanged<String> onTecla;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // Sin esto la barra de espacio queda del ancho de su texto en vez de
        // ocupar toda la fila, porque el Column centra a sus hijos.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final fila in filasTeclado) ...[
            _Fila(teclas: fila, onTecla: onTecla),
            const SizedBox(height: 6),
          ],
          SizedBox(
            height: altoTecla,
            child: _Tecla(texto: teclaEspacio, onTecla: onTecla),
          ),
        ],
      ),
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
      height: altoTecla,
      child: Row(
        children: [
          for (int i = 0; i < teclas.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
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

  bool get _esEspecial => texto == teclaBorrar || texto == teclaEspacio;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => onTecla(texto),
      style: ElevatedButton.styleFrom(
        // Teclas blancas sobre fondo verde claro, como un teclado de verdad;
        // las especiales van en verde para diferenciarlas de las letras.
        backgroundColor: _esEspecial ? Tema.verde : Tema.superficie,
        foregroundColor: _esEspecial ? Colors.white : Tema.texto,
        elevation: 0,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tema.radioChico),
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: texto == teclaBorrar ? 17 : 20,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

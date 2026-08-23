import 'dart:math';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../datos/repositorio_preposizioni.dart';
import '../logica/preposiciones.dart';
import '../modelos/preposicion.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/tarjeta_pregunta.dart';

/// Práctica de preposiciones: se muestra una frase italiana con un hueco y
/// hay que elegir qué va adentro tocando un botón.
///
/// Son dos problemas en uno y por eso confunden tanto: cuál preposición va
/// (a / in / da, que es idiomático y no tiene regla) y si se pega o no con el
/// artículo (a + il = al, que es una tabla sin excepciones). La traducción al
/// español debajo de la frase es la que resuelve el primero, y de paso marca
/// dónde el español miente: "voy a la ciudad" pero "vado in città".
class PantallaPreposizioni extends StatefulWidget {
  const PantallaPreposizioni({super.key, this.repositorio});

  /// Inyectable para los tests.
  final RepositorioPreposizioni? repositorio;

  @override
  State<PantallaPreposizioni> createState() => _PantallaPreposizioniState();
}

class _PantallaPreposizioniState extends State<PantallaPreposizioni> {
  late final RepositorioPreposizioni _repositorio =
      widget.repositorio ?? RepositorioPreposizioni();
  final _azar = Random();

  List<FrasePreposicion> _frases = const [];
  FrasePreposicion? _actual;
  String _elegida = '';
  bool _mostrandoResultado = false;
  int _puntaje = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  Future<void> _empezar() async {
    await _repositorio.cargar();
    if (!mounted) return;
    _frases = _repositorio.datos.frases;
    _nueva();
  }

  void _nueva() {
    setState(() {
      _elegida = '';
      _mostrandoResultado = false;
      if (_frases.isEmpty) {
        _actual = null;
        return;
      }
      // No repetir la misma frase dos veces seguidas.
      FrasePreposicion elegida;
      do {
        elegida = _frases[_azar.nextInt(_frases.length)];
      } while (_frases.length > 1 && elegida.frase == _actual?.frase);
      _actual = elegida;
    });
  }

  void _tocar(String opcion) {
    if (_mostrandoResultado) return;
    setState(() => _elegida = opcion);
  }

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nueva();
      return;
    }
    if (_elegida.isEmpty || _actual == null) return;
    setState(() {
      _total++;
      if (_acerto) _puntaje++;
      _mostrandoResultado = true;
    });
  }

  bool get _acerto => _actual != null && _elegida == _actual!.correcta;

  @override
  Widget build(BuildContext context) {
    final actual = _actual;
    if (actual == null) {
      return const Center(
        child: Text(
          'Todavía no hay frases cargadas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(child: ChipPuntaje(puntaje: _puntaje, total: _total)),
          const SizedBox(height: 12),
          _tarjeta(actual),
          const SizedBox(height: 16),
          FilaOpciones(
            opciones: actual.opciones,
            elegido: _elegida,
            correcta: actual.correcta,
            mostrandoResultado: _mostrandoResultado,
            onTocar: _tocar,
          ),
          const SizedBox(height: 10),
          // Alto mínimo para que el botón no salte al aparecer la explicación,
          // pero que pueda crecer si es larga.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: _explicacion(actual),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _elegida.isEmpty ? null : _accionBoton,
              style: Tema.botonPrincipal,
              child: Text(
                _mostrandoResultado ? 'Siguiente' : 'Verificar',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// La frase con el hueco, y abajo la traducción.
  ///
  /// El hueco se va llenando con lo que se toca, así se lee la frase entera
  /// antes de verificar en vez de imaginarla.
  Widget _tarjeta(FrasePreposicion actual) {
    final (antes, despues) = actual.partes;
    final sinElegir = _elegida.isEmpty;
    final color = !_mostrandoResultado
        ? Tema.verdeOscuro
        : _acerto
            ? Tema.correcto
            : Tema.incorrecto;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        boxShadow: Tema.sombra,
      ),
      child: Column(
        children: [
          const Text(
            'COMPLETÁ LA FRASE',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Tema.verde,
            ),
          ),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 22,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Tema.titulo,
              ),
              children: [
                TextSpan(text: antes),
                TextSpan(
                  text: sinElegir ? hueco : _elegida,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sinElegir ? Tema.borde : color,
                  ),
                ),
                TextSpan(text: despues),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            actual.espanol,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }

  /// Por qué va esa y no otra. Cuando la respuesta es una contracción se
  /// agrega la cuenta ("in + la = nella"), que es la parte mecánica y se
  /// aprende de una.
  Widget _explicacion(FrasePreposicion actual) {
    if (!_mostrandoResultado) return const SizedBox.shrink();

    final cuenta = cuentaDe(actual.correcta);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _acerto ? Icons.check_circle : Icons.cancel,
              color: _acerto ? Tema.correcto : Tema.incorrecto,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _acerto ? '¡Correcto!' : 'Va: ${actual.resuelta}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _acerto ? Tema.correcto : Tema.incorrecto,
                ),
              ),
            ),
          ],
        ),
        if (cuenta != null) ...[
          const SizedBox(height: 6),
          Text(
            cuenta,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Tema.verdeOscuro,
            ),
          ),
        ],
        if (actual.explicacion.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            actual.explicacion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.3,
              color: Tema.textoTenue,
            ),
          ),
        ],
      ],
    );
  }
}

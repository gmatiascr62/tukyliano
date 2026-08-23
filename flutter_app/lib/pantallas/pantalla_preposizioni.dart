import 'dart:math';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../datos/repositorio_preposizioni.dart';
import '../logica/preposiciones.dart';
import '../modelos/preposicion.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/hoja_ayuda.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';

/// Práctica de preposiciones: se muestra una frase italiana con un hueco y
/// hay que elegir qué va adentro tocando un botón.
///
/// Son dos problemas en uno y por eso confunden tanto: cuál preposición va
/// (a / in / da, que es idiomático y no tiene regla) y si se pega o no con el
/// artículo (a + il = al, que es una tabla sin excepciones). La traducción al
/// español debajo de la frase es la que resuelve el primero, y de paso marca
/// dónde el español miente: "voy a la ciudad" pero "vado in città".
///
/// Arriba se elige con cuáles practicar: se pueden dejar dos prendidas y el
/// resto apagadas, para machacar justo las que no salen.
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

  /// Con cuáles se está practicando. Arranca con todas prendidas.
  final Set<String> _elegidas = {...preposicionesSimples};

  /// Todas las frases del JSON, y las que entran en la práctica según lo que
  /// esté prendido arriba.
  List<FrasePreposicion> _todas = const [];
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
    _todas = _repositorio.datos.frases;
    _filtrar();
  }

  void _filtrar() {
    _frases = [
      for (final f in _todas)
        if (_elegidas.contains(preposicionDe(f.correcta))) f,
    ];
    _nueva();
  }

  /// Prende o apaga una preposición. La última prendida no se puede apagar:
  /// sin ninguna no quedaría nada para practicar.
  void _alternar(String preposicion) {
    if (_elegidas.contains(preposicion) && _elegidas.length == 1) return;
    setState(() {
      if (!_elegidas.remove(preposicion)) _elegidas.add(preposicion);
      _filtrar();
    });
  }

  void _todasPrendidas() {
    if (_elegidas.length == preposicionesSimples.length) return;
    setState(() {
      _elegidas.addAll(preposicionesSimples);
      _filtrar();
    });
  }

  void _abrirAyuda() {
    mostrarAyuda(
      context,
      titulo: 'Cómo funcionan las preposiciones',
      secciones: ayudaDeLasPreposizioni,
    );
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
      return Column(
        children: [
          const SizedBox(height: 10),
          _encabezado(),
          Expanded(
            child: Center(
              child: Text(
                // Con frases cargadas, el hueco es de la selección de arriba
                // y no de los datos: decirlo evita buscar el problema donde
                // no está.
                _todas.isEmpty
                    ? 'Todavía no hay frases cargadas.'
                    : 'No hay frases para lo que elegiste arriba.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _encabezado(),
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

  /// Puntaje, las preposiciones que se están practicando y la explicación.
  Widget _encabezado() {
    return Column(
      children: [
        ChipPuntaje(puntaje: _puntaje, total: _total),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pasan a dos renglones cuando no entran: son siete y en un
            // celular angosto no van en una fila sola.
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pastilla(
                    texto: 'Todas',
                    activa: _elegidas.length == preposicionesSimples.length,
                    alTocar: _todasPrendidas,
                  ),
                  for (final p in preposicionesSimples)
                    Pastilla(
                      texto: p,
                      activa: _elegidas.contains(p),
                      alTocar: () => _alternar(p),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                onPressed: _abrirAyuda,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.info_outline),
                color: Tema.verde,
                tooltip: 'Cómo funcionan las preposiciones',
              ),
            ),
          ],
        ),
      ],
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

/// Lo que explica el botón de info: la tabla de las contracciones y los
/// lugares donde el español empuja a poner otra cosa.
const List<SeccionAyuda> ayudaDeLasPreposizioni = [
  SeccionAyuda(
    titulo: 'Las siete',
    ejemplos: [
      'di = de (di Marco, di legno)',
      'a = a, en (a Roma, alle otto)',
      'da = de, desde, a lo de (da Milano, dal medico)',
      'in = en, a (in Italia, in macchina)',
      'su = sobre, en (sul tavolo)',
      'per = para, por (per te)',
      'con = con (con Anna)',
    ],
  ),
  SeccionAyuda(
    titulo: 'Cinco se pegan con el artículo',
    cuerpo: 'di, a, da, in y su se juntan con el determinado y forman una sola '
        'palabra. La tabla no tiene ninguna excepción.',
    ejemplos: [
      'di: del, dello, della, dell\', dei, degli, delle',
      "a: al, allo, alla, all', ai, agli, alle",
      "da: dal, dallo, dalla, dall', dai, dagli, dalle",
      "in: nel, nello, nella, nell', nei, negli, nelle",
      "su: sul, sullo, sulla, sull', sui, sugli, sulle",
    ],
  ),
  SeccionAyuda(
    titulo: 'per y con no se pegan nunca',
    cuerpo: 'Van siempre en dos palabras. "Perla" existe en italiano, pero es '
        'una perla.',
    ejemplos: [
      'per la nonna (no "perla nonna")',
      'con il treno, con gli amici',
    ],
  ),
  SeccionAyuda(
    titulo: 'Ciudades con a, países con in',
    ejemplos: [
      'vado a Roma, a Milano, a Napoli',
      'vado in Italia, in Francia, in Argentina',
      'sono a casa, vado a casa (casa va con a y sin artículo)',
    ],
  ),
  SeccionAyuda(
    titulo: 'Las que el español dice al revés',
    cuerpo: 'Acá es donde se pierde el tiempo si no se sabe de memoria.',
    ejemplos: [
      'vado in città (voy a la ciudad)',
      'sono in banca, in ufficio, in centro',
      'vado in macchina, in treno, in bici (voy en auto, en tren)',
      'a scuola, a teatro, a letto (sin artículo)',
      'vado dal medico, da Marco (a lo del médico, a lo de Marco)',
      'la penna è sul tavolo (está sobre la mesa)',
    ],
  ),
];

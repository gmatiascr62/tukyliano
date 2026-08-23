import 'dart:math';

import 'package:flutter/material.dart';

import '../constantes.dart';
import '../datos/repositorio_particelle.dart';
import '../logica/correccion.dart';
import '../logica/modo_respuesta.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/particella.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/campo_texto.dart';
import '../widgets/hoja_ayuda.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';

/// Práctica del «via» pegado al verbo.
///
/// El «via» es el «away» del inglés: no se conjuga y no cambia, pero convierte
/// andare en irse, portare en llevarse y buttare en tirar a la basura. En
/// español no hay nada parecido —se dice todo con el mismo verbo reflexivo—,
/// así que el error típico no es escribir mal el «via» sino no ponerlo.
class PantallaVia extends StatefulWidget {
  const PantallaVia({super.key, this.repositorio});

  /// Inyectable para los tests.
  final RepositorioParticelle? repositorio;

  @override
  State<PantallaVia> createState() => _PantallaViaState();
}

class _PantallaViaState extends State<PantallaVia> {
  late final RepositorioParticelle _repositorio =
      widget.repositorio ?? RepositorioParticelle.via();
  final _azar = Random();

  List<FraseParticella> _frases = const [];
  FraseParticella? _actual;
  ModoRespuesta _modo = ModoRespuesta.elegir;

  String _elegida = '';
  String _texto = '';
  List<PalabraCorregida> _correccion = const [];
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
      _limpiar();
      if (_frases.isEmpty) {
        _actual = null;
        return;
      }
      // No repetir la misma frase dos veces seguidas.
      FraseParticella elegida;
      do {
        elegida = _frases[_azar.nextInt(_frases.length)];
      } while (_frases.length > 1 && elegida.frase == _actual?.frase);
      _actual = elegida;
    });
  }

  void _limpiar() {
    _elegida = '';
    _texto = '';
    _correccion = const [];
    _mostrandoResultado = false;
  }

  /// Cambiar de modo deja la misma frase pero borra lo contestado: si no, se
  /// pasaría a escribir con la respuesta ya elegida a la vista.
  void _cambiarModo(ModoRespuesta modo) {
    if (modo == _modo) return;
    setState(() {
      _modo = modo;
      _limpiar();
    });
  }

  void _tocar(String opcion) {
    if (_mostrandoResultado) return;
    setState(() => _elegida = opcion);
  }

  void _onTecla(String tecla) {
    if (_mostrandoResultado) return;
    setState(() => _texto = aplicarTecla(_texto, tecla));
  }

  bool get _hayRespuesta => switch (_modo) {
        ModoRespuesta.elegir => _elegida.isNotEmpty,
        ModoRespuesta.escribir => _texto.trim().isNotEmpty,
      };

  bool get _acerto => switch (_modo) {
        ModoRespuesta.elegir => _actual != null && _elegida == _actual!.correcta,
        ModoRespuesta.escribir => todoAcertado(_correccion),
      };

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nueva();
      return;
    }
    final actual = _actual;
    if (actual == null || !_hayRespuesta) return;

    setState(() {
      if (_modo == ModoRespuesta.escribir) {
        _correccion = corregir(correcta: actual.resuelta, respuesta: _texto);
      }
      _total++;
      if (_acerto) _puntaje++;
      _mostrandoResultado = true;
    });
  }

  void _abrirAyuda() {
    mostrarAyuda(
      context,
      titulo: 'Cómo se usa el «via»',
      secciones: ayudaDelVia,
    );
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                _encabezado(),
                const SizedBox(height: 12),
                if (_modo == ModoRespuesta.elegir) ...[
                  _tarjetaConHueco(actual),
                  const SizedBox(height: 16),
                  FilaOpciones(
                    opciones: actual.opciones,
                    elegido: _elegida,
                    correcta: actual.correcta,
                    mostrandoResultado: _mostrandoResultado,
                    onTocar: _tocar,
                  ),
                ] else ...[
                  TarjetaPregunta(
                    etiqueta: 'Escribí en italiano, con el via',
                    texto: "'${actual.espanol}'",
                    alto: 130,
                  ),
                  const SizedBox(height: 12),
                  CampoTexto(
                    texto: _texto,
                    placeholderTexto: 'Escribí la frase...',
                  ),
                ],
                const SizedBox(height: 10),
                // Alto mínimo para que el botón no salte al aparecer la
                // explicación, pero que pueda crecer si es larga.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 92),
                  child: _resultado(actual),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _hayRespuesta || _mostrandoResultado
                        ? _accionBoton
                        : null,
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
          ),
        ),
        if (_modo == ModoRespuesta.escribir)
          // El apóstrofo hace falta acá y no en las otras pantallas: la mitad
          // de las frases lo llevan (l'ho buttato via, vent'anni).
          Teclado(onTecla: _onTecla, teclasExtra: const ["'"]),
      ],
    );
  }

  /// Puntaje, los dos modos y el botón de la explicación.
  Widget _encabezado() {
    // El puntaje va en su propio renglón, como en las otras prácticas. Las
    // pastillas y la info van abajo y no al lado: los tres juntos no entran en
    // un celular angosto, y lo que se caía del borde era justo el botón de
    // cambiar de modo.
    return Column(
      children: [
        ChipPuntaje(puntaje: _puntaje, total: _total),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final modo in ModoRespuesta.values) ...[
              Pastilla(
                texto: modo.etiqueta,
                activa: _modo == modo,
                alTocar: () => _cambiarModo(modo),
              ),
              const SizedBox(width: 6),
            ],
            const Spacer(),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                onPressed: _abrirAyuda,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.info_outline),
                color: Tema.verde,
                tooltip: 'Cómo se usa el via',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// La frase con el hueco, y abajo la traducción. El hueco se va llenando con
  /// lo que se toca, así se lee la frase entera antes de verificar.
  Widget _tarjetaConHueco(FraseParticella actual) {
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
                fontSize: 21,
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

  /// Si acertó o no, la frase completa y por qué va ese verbo.
  Widget _resultado(FraseParticella actual) {
    if (!_mostrandoResultado) return const SizedBox.shrink();

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
            Flexible(child: _frasePintada(actual)),
          ],
        ),
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

  /// En el modo de escribir la frase correcta sale palabra por palabra, en
  /// verde lo que escribió y en rojo lo que le faltó. En el de elegir alcanza
  /// con mostrarla entera.
  Widget _frasePintada(FraseParticella actual) {
    if (_modo == ModoRespuesta.elegir) {
      return Text(
        _acerto ? '¡Correcto!' : 'Va: ${actual.resuelta}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: _acerto ? Tema.correcto : Tema.incorrecto,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        children: [
          for (var i = 0; i < _correccion.length; i++)
            TextSpan(
              text: i == 0
                  ? _correccion[i].palabra
                  : ' ${_correccion[i].palabra}',
              style: TextStyle(
                color: _correccion[i].acertada
                    ? Tema.correcto
                    : Tema.incorrecto,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Lo que explica el botón de info. Está acá y no en el JSON a propósito: no
/// es contenido que se agregue seguido, y así se puede escribir con ejemplos
/// que acompañan a los ejercicios.
const List<SeccionAyuda> ayudaDelVia = [
  SeccionAyuda(
    titulo: 'Qué le hace al verbo',
    cuerpo: 'Pegado a un verbo, «via» funciona como el «away» del inglés: no '
        'se conjuga ni cambia nunca, pero le da al verbo el sentido de sacar '
        'o alejar algo.',
    ejemplos: [
      'andare = ir · andare via = irse',
      'portare = llevar · portare via = llevarse',
      'buttare = tirar · buttare via = tirar a la basura',
      'mandare = mandar · mandare via = echar',
    ],
  ),
  SeccionAyuda(
    titulo: 'Andare via en todas las personas',
    cuerpo: 'Se conjuga el verbo de adelante; el «via» queda igual.',
    ejemplos: [
      'io vado via',
      'tu vai via',
      'lui, lei va via',
      'noi andiamo via',
      'voi andate via',
      'loro vanno via',
    ],
  ),
  SeccionAyuda(
    titulo: 'En pasado',
    cuerpo: 'El «via» va después del participio. Andare, scappare y volare '
        'van con essere, así que el participio concuerda; buttare, portare y '
        'mandare van con avere.',
    ejemplos: [
      'sono andato via, siamo andati via',
      'sono scappati via di corsa',
      "l'ho buttato via senza volere",
      'hanno portato via le sedie',
    ],
  ),
  SeccionAyuda(
    titulo: 'Dónde se pone',
    cuerpo: 'Siempre después del verbo. Si hay pronombre, el pronombre se '
        'pega al verbo y el «via» queda al final.',
    ejemplos: [
      'buttalo via (tiralo)',
      'mandateli via (échenlos)',
      'non buttare via il pane (no tires el pan)',
      'il capo lo manda via (el jefe lo echa)',
    ],
  ),
  SeccionAyuda(
    titulo: 'Los que más se usan',
    ejemplos: [
      'andare via = irse',
      'portare via = llevarse',
      'buttare via = tirar',
      'mandare via = echar a alguien',
      'scappare via = escaparse',
      'volare via = volarse',
      'dare via = regalar, desprenderse',
      'gettare via = tirar (más formal)',
      'cacciare via = espantar, echar',
      'spazzare via = barrer, llevarse todo por delante',
    ],
  ),
  SeccionAyuda(
    titulo: 'Cuando va solo, sin verbo',
    ejemplos: [
      'Via da qui! = ¡fuera de acá!',
      'Pronti, partenza, via! = ¡en sus marcas, listos, ya!',
      'e via dicendo = y así sucesivamente',
      'via via che = a medida que',
    ],
  ),
];

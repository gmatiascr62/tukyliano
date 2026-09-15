import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../constantes.dart';
import '../datos/repositorio_frases.dart';
import '../logica/armar_frase.dart';
import '../logica/correccion.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
import '../widgets/ficha_palabra.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';
import '../widgets/texto_ajustado.dart';

/// Las dos formas de contestar una frase.
///
/// No usa [ModoRespuesta] —el de «via» y el quiz— porque ahí las opciones son
/// elegir una palabra entre cuatro, y acá se arma la frase entera.
enum ModoFrase {
  /// Se toca palabra por palabra hasta armar la frase. Es el que viene puesto:
  /// no aparece el teclado y se practica el orden y la conjugación sin pelear
  /// con cómo se escribe cada palabra.
  armar,

  /// Se escribe la frase entera con el teclado de la app. Más difícil, porque
  /// las palabras no están a la vista.
  escribir,
}

extension EtiquetaModoFrase on ModoFrase {
  String get etiqueta => switch (this) {
        ModoFrase.armar => 'Armar',
        ModoFrase.escribir => 'Escribir',
      };
}

/// Práctica de frases: se muestra una oración en español y el alumno la arma
/// en italiano tocando palabras (o la escribe, si se cambia de modo). Las
/// frases vienen de frases.json, y al verificar se muestra la respuesta
/// correcta con cada palabra en verde o en rojo.
class PantallaFrases extends StatefulWidget {
  const PantallaFrases({
    super.key,
    required this.verbos,
    required this.tiempos,
    this.frasesLocales,
    this.progreso,
    this.azar,
  });

  final List<Verbo> verbos;
  final List<String> tiempos;

  /// Inyectable para los tests.
  final RepositorioFrases? frasesLocales;

  /// Para sumar los aciertos al progreso general. Null en los tests que no lo
  /// miran.
  final Progreso? progreso;

  /// Inyectable para que los tests sepan qué fichas van a salir.
  final Random? azar;

  @override
  State<PantallaFrases> createState() => _PantallaFrasesState();
}

class _PantallaFrasesState extends State<PantallaFrases> {
  late final RepositorioFrases _frases =
      widget.frasesLocales ?? RepositorioFrases();
  late final Random _azar = widget.azar ?? Random();

  String _fraseEs = '';
  String _italianoReferencia = '';
  String _pista = '';
  bool _mostrandoPista = false;
  String _textoActual = '';
  String _mensajePantalla = 'Buscando una frase...';

  ModoFrase _modo = ModoFrase.armar;

  /// Todas las fichas del ejercicio, en el orden mezclado en que se muestran.
  List<String> _fichas = const [];

  /// Los índices de [_fichas] que ya están puestos, en el orden en que se
  /// tocaron. Se guarda el índice y no la palabra para que las repetidas (dos
  /// «la» en la misma frase) sean cada una la suya.
  List<int> _puestas = [];

  /// Vacío mientras no se verificó. Después trae la respuesta correcta con
  /// cada palabra marcada.
  List<PalabraCorregida> _correccion = [];

  /// Las fichas que se pusieron de más. Solo se llena al verificar.
  List<String> _sobraron = const [];

  bool _ocupado = true;
  bool _mostrandoResultado = false;

  @override
  void initState() {
    super.initState();
    _nuevaFrase();
  }

  Future<void> _nuevaFrase() async {
    setState(() {
      _mensajePantalla = 'Buscando una frase...';
      _fraseEs = '';
      _pista = '';
      _mostrandoPista = false;
      _limpiarRespuesta();
      _fichas = const [];
      _ocupado = true;
    });

    await _frases.cargar();
    if (!mounted) return;

    // Solo se sortean las formas que tienen frase guardada. Se descarta la
    // frase cuyo italiano no traiga la conjugación esperada, que es la red de
    // contención para el JSON remoto.
    bool conFrase(Combo combo) => _frases.tieneFrase(
          verbo: combo.verbo.nombre,
          tiempo: combo.tiempo,
          persona: combo.persona,
          conjugacionItaliana: combo.conjugacion.italiano,
        );

    var combo = elegirComboFiltrado(widget.verbos, widget.tiempos, conFrase);
    combo ??= elegirComboFiltrado(widget.verbos, tiemposDisponibles, conFrase);
    if (combo == null) {
      setState(() {
        _mensajePantalla = 'Todavía no hay frases para estos verbos.';
        _ocupado = false;
      });
      return;
    }

    final frase = _frases.elegir(
      verbo: combo.verbo.nombre,
      tiempo: combo.tiempo,
      persona: combo.persona,
      conjugacionItaliana: combo.conjugacion.italiano,
    )!;

    setState(() {
      _fraseEs = frase.espanol;
      _italianoReferencia = frase.italiano;
      _pista = frase.pista;
      _fichas = fichasPara(
        frase.italiano,
        extras: _otrasFormas(combo!),
        azar: _azar,
      );
      _ocupado = false;
    });
  }

  /// Las otras personas del mismo verbo y tiempo, para que las fichas de más
  /// sean las que de verdad se confunden (ho / hai / ha) y no palabras
  /// cualquiera.
  List<String> _otrasFormas(Combo combo) => [
        for (final entrada in (combo.verbo.tiempos[combo.tiempo] ?? {}).entries)
          if (entrada.key != combo.persona)
            ...entrada.value.italiano.split(RegExp(r'\s+')),
      ];

  void _limpiarRespuesta() {
    _textoActual = '';
    _puestas = [];
    _correccion = [];
    _sobraron = const [];
    _mostrandoResultado = false;
  }

  /// Cambiar de modo deja la misma frase pero borra lo contestado: si no, se
  /// pasaría a escribir con la respuesta ya armada a la vista.
  void _cambiarModo(ModoFrase modo) {
    if (modo == _modo) return;
    setState(() {
      _modo = modo;
      _limpiarRespuesta();
    });
  }

  void _onTecla(String tecla) {
    if (_mostrandoResultado) return;
    setState(() => _textoActual = aplicarTecla(_textoActual, tecla));
  }

  void _ponerFicha(int cual) {
    if (_mostrandoResultado) return;
    setState(() => _puestas = [..._puestas, cual]);
  }

  void _sacarFicha(int cual) {
    if (_mostrandoResultado) return;
    setState(() => _puestas = [..._puestas]..remove(cual));
  }

  /// Lo contestado, venga de las fichas o del teclado.
  String get _respuesta => switch (_modo) {
        ModoFrase.armar => _puestas.map((i) => _fichas[i]).join(' '),
        ModoFrase.escribir => _textoActual,
      };

  bool get _acerto => todoAcertado(_correccion) && _sobraron.isEmpty;

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nuevaFrase();
    } else {
      _verificar();
    }
  }

  void _verificar() {
    if (_respuesta.trim().isEmpty || _fraseEs.isEmpty) return;

    setState(() {
      _correccion = corregir(
        correcta: _italianoReferencia,
        respuesta: _respuesta,
      );
      // Poner todas las fichas, incluidas las de más, pintaría la frase entera
      // de verde: las que sobran hay que mirarlas aparte.
      _sobraron = _modo == ModoFrase.armar
          ? fichasQueSobran(
              correcta: _italianoReferencia,
              puestas: _puestas.map((i) => _fichas[i]),
            )
          : const [];
      _mostrandoResultado = true;
    });
    if (_acerto) widget.progreso?.acerto();
  }

  /// La pista viene con la frase, así que mostrarla no cuesta nada: solo se
  /// revela si el alumno la pide.
  Widget _pistaWidget() {
    if (_pista.isEmpty || _fraseEs.isEmpty) return const SizedBox.shrink();
    if (_mostrandoPista) {
      return Text(
        _pista,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Tema.verdeOscuro,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => setState(() => _mostrandoPista = true),
      icon: const Icon(Icons.lightbulb_outline, size: 18),
      label: const Text('Pista'),
      style: TextButton.styleFrom(foregroundColor: Tema.verde),
    );
  }

  /// La respuesta correcta, con cada palabra en verde si la puso y en rojo
  /// si no. La letra se achica si no entra, así nunca queda cortada.
  Widget _respuestaWidget() {
    if (_correccion.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
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
            Expanded(
              child: TextoAjustado(
                _correccion.map((p) => p.palabra).join(' '),
                // Mismo criterio que el campo de arriba: antes letra chica que
                // texto cortado.
                estilo:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                trozos: [
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
            ),
          ],
        ),
        // Si puso todas las de la frase pero además alguna de más, arriba está
        // todo verde y sin esto no se entendería por qué está mal.
        if (_sobraron.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _sobraron.length == 1
                  ? 'Te sobró: ${_sobraron.first}'
                  : 'Te sobraron: ${_sobraron.join(', ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Tema.incorrecto),
            ),
          ),
      ],
    );
  }

  /// La frase que se va armando. Cada palabra puesta se puede tocar para
  /// devolverla al banco: equivocarse no obliga a empezar de nuevo.
  Widget _fraseArmada() {
    if (_puestas.isEmpty) {
      return Container(
        width: double.infinity,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Tema.superficie,
          borderRadius: BorderRadius.circular(Tema.radio),
          border: Border.all(color: Tema.borde, width: 1.5),
        ),
        child: const Text(
          'Tocá las palabras de abajo',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(color: Tema.verde, width: 2),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final cual in _puestas)
            FichaPalabra(
              palabra: _fichas[cual],
              puesta: true,
              alTocar: () => _sacarFicha(cual),
            ),
        ],
      ),
    );
  }

  /// Las fichas que todavía no se usaron. Las puestas dejan el lugar vacío en
  /// vez de desaparecer, así el banco no se reacomoda entero a cada toque.
  Widget _banco() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _fichas.length; i++)
          Opacity(
            opacity: _puestas.contains(i) ? 0.25 : 1,
            child: FichaPalabra(
              palabra: _fichas[i],
              puesta: false,
              alTocar: _puestas.contains(i) ? null : () => _ponerFicha(i),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final armando = _modo == ModoFrase.armar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final modo in ModoFrase.values) ...[
                      Pastilla(
                        texto: modo.etiqueta,
                        activa: _modo == modo,
                        alTocar: () => _cambiarModo(modo),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TarjetaPregunta(
                  etiqueta: _fraseEs.isEmpty
                      ? ''
                      : armando
                          ? 'Armá la frase en italiano'
                          : 'Escribí en italiano',
                  texto: _fraseEs.isEmpty ? _mensajePantalla : "'$_fraseEs'",
                  // Abajo van la respuesta, la pista, la corrección, el botón
                  // y las fichas: con el alto de siempre no entraba todo.
                  alto: 124,
                ),
                const SizedBox(height: 14),
                if (armando)
                  _fraseArmada()
                else
                  CampoTexto(
                    texto: _textoActual,
                    placeholderTexto: 'Escribí la traducción...',
                  ),
                // Alto fijo, igual que la respuesta, para que mostrar la pista
                // no mueva el resto de la pantalla.
                SizedBox(height: 36, child: Center(child: _pistaWidget())),
                // Alto mínimo siempre, para que el layout no salte al aparecer
                // el texto (el bug que tuvo la versión Kivy).
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Center(child: _respuestaWidget()),
                ),
              ],
            ),
          ),
        ),
        // El banco va afuera del scroll, en el lugar del teclado: queda
        // siempre abajo, donde llega el pulgar, y no se mueve al poner fichas.
        if (armando) ...[
          _banco(),
          const SizedBox(height: 12),
        ],
        // Afuera del scroll: siempre a la vista, aunque el teclado ocupe media
        // pantalla.
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: _ocupado ? null : _accionBoton,
            style: Tema.botonPrincipal,
            child: Text(
              _mostrandoResultado ? 'Siguiente' : 'Verificar',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!armando) Teclado(onTecla: _onTecla),
      ],
    );
  }
}

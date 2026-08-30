import 'package:flutter/material.dart';

import '../datos/escucha.dart';
import '../datos/palabras_habladas.dart';
import '../datos/voz.dart';
import '../logica/pronunciacion.dart';
import '../modelos/palabra_hablada.dart';
import '../tema.dart';
import '../widgets/hoja_ayuda.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';

/// Práctica de pronunciación: aparece una palabra, se la dice en voz alta y el
/// celular contesta si entendió.
///
/// Dos tandas: los sonidos que el castellano hace pronunciar mal, y los
/// números del 0 al 30. Las palabras están escritas en Dart y no en un JSON
/// porque el contenido todavía se está armando; cuando se asiente, pasan al
/// JSON como el resto y ahí se agregan sin sacar un APK nuevo.
class PantallaPronunciacion extends StatefulWidget {
  const PantallaPronunciacion({
    super.key,
    required this.voz,
    this.escucha,
    this.palabras,
  });

  final Voz voz;

  /// Inyectable para los tests, donde no hay micrófono.
  final Escucha? escucha;

  /// Con qué se practica. Inyectable para los tests; en la app son todas.
  final List<PalabraHablada>? palabras;

  @override
  State<PantallaPronunciacion> createState() => _PantallaPronunciacionState();
}

/// En qué anda la pantalla.
enum _Momento { quieta, escuchando, contestada }

class _PantallaPronunciacionState extends State<PantallaPronunciacion> {
  late final Escucha _escucha = widget.escucha ?? EscuchaDelCelular();
  late final List<PalabraHablada> _palabras =
      widget.palabras ?? palabrasParaDecir;

  late GrupoHabla _grupo =
      _grupos.isEmpty ? GrupoHabla.sonidos : _grupos.first;
  int _cual = 0;
  _Momento _momento = _Momento.quieta;
  LoEscuchado? _oido;

  /// Lo que se va entendiendo mientras se habla, y cuánto ruido entra por el
  /// micrófono. Los dos son solo para mostrar que el micrófono está vivo: sin
  /// esto, un intento fallido y un micrófono muerto se ven igual.
  String _parcial = '';
  double _volumen = 0;
  ComoSalio _como = ComoSalio.nada;
  int _puntaje = 0;
  int _total = 0;

  /// False cuando el celular no tiene la voz italiana: ahí no se puede
  /// escuchar cómo suena la palabra antes de decirla.
  bool _puedeHablar = false;

  @override
  void initState() {
    super.initState();
    _prepararVoz();
  }

  @override
  void dispose() {
    _escucha.cortar();
    super.dispose();
  }

  Future<void> _prepararVoz() async {
    final listo = await widget.voz.preparar();
    if (!mounted) return;
    setState(() => _puedeHablar = listo);
  }

  /// Los grupos que hay para elegir. Si hay uno solo no se muestran las
  /// pastillas: no habría nada que elegir.
  List<GrupoHabla> get _grupos => [
        for (final grupo in GrupoHabla.values)
          if (_palabras.any((palabra) => palabra.grupo == grupo)) grupo,
      ];

  List<PalabraHablada> get _lista =>
      [for (final p in _palabras) if (p.grupo == _grupo) p];

  PalabraHablada get _palabra => _lista[_cual];

  /// Cambiar de grupo arranca de nuevo desde la primera palabra. El puntaje se
  /// mantiene: es el de toda la vuelta, no el del grupo.
  void _cambiarGrupo(GrupoHabla grupo) {
    if (grupo == _grupo) return;
    setState(() {
      _grupo = grupo;
      _cual = 0;
      _momento = _Momento.quieta;
      _oido = null;
      _parcial = '';
      _volumen = 0;
      _como = ComoSalio.nada;
    });
  }

  Future<void> _decir() async {
    if (!_puedeHablar) return;
    await widget.voz.decir(_palabra.italiano);
  }

  Future<void> _escuchar() async {
    if (_momento == _Momento.escuchando) {
      await _escucha.cortar();
      return;
    }

    // Callar primero: si el celular está diciendo la palabra, el micrófono se
    // escucha a sí mismo y da bien sin que nadie haya hablado.
    await widget.voz.callar();
    if (!mounted) return;
    setState(() {
      _momento = _Momento.escuchando;
      _oido = null;
      _parcial = '';
      _volumen = 0;
    });

    final oido = await _escucha.escuchar(
      alOir: (parcial) {
        if (!mounted) return;
        setState(() => _parcial = parcial);
        // Apenas se entiende la palabra no hay nada más que esperar. Cortar
        // acá ahorra los segundos que Android se toma para decidir que
        // terminaste de hablar, que es la espera que se hacía larga.
        if (_esLaPalabra(parcial)) _escucha.cortar();
      },
      alSonido: (volumen) {
        if (mounted) setState(() => _volumen = volumen);
      },
    );
    if (!mounted) return;

    final como = comparar(esperada: _palabra.italiano, oido: oido);
    setState(() {
      _oido = oido;
      _como = como;
      _momento = _Momento.contestada;
      // Solo se cuenta cuando se llegó a escuchar algo: un intento en el que
      // no se oyó nada no es un error de pronunciación.
      if (como != ComoSalio.nada) {
        _total++;
        if (como == ComoSalio.bien) _puntaje++;
      }
    });
  }

  /// Si lo que se entendió a medio camino ya es la palabra buscada.
  bool _esLaPalabra(String parcial) =>
      comparar(
        esperada: _palabra.italiano,
        oido: LoEscuchado(mejor: parcial),
      ) ==
      ComoSalio.bien;

  void _siguiente() {
    setState(() {
      _cual = (_cual + 1) % _lista.length;
      _momento = _Momento.quieta;
      _oido = null;
      _parcial = '';
      _volumen = 0;
      _como = ComoSalio.nada;
    });
  }

  void _abrirAyuda() {
    mostrarAyuda(
      context,
      titulo: 'Cómo funciona esto',
      secciones: ayudaDeLaPronunciacion,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lista.isEmpty) {
      return const Center(
        child: Text(
          'Todavía no hay palabras cargadas.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        _encabezado(),
        const SizedBox(height: 12),
        _tarjeta(),
        // El micrófono va en el medio de lo que sobra, y no pegado a la
        // tarjeta: es el botón que más se toca y así queda cerca del pulgar.
        // El alto mínimo del resultado deja el bloque siempre del mismo
        // tamaño, para que el micrófono no salte al contestar.
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _microfono(),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 96),
                    child: _resultado(),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: _momento == _Momento.escuchando ? null : _siguiente,
            style: Tema.botonPrincipal,
            child: const Text(
              'Otra palabra',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _encabezado() {
    return Column(
      children: [
        ChipPuntaje(puntaje: _puntaje, total: _total),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_grupos.length > 1)
                    for (final grupo in _grupos)
                      Pastilla(
                        texto: grupo.etiqueta,
                        activa: grupo == _grupo,
                        alTocar: () => _cambiarGrupo(grupo),
                      ),
                  Pastilla(
                    texto: 'Escuchar',
                    icono: Icons.volume_up,
                    alTocar: _puedeHablar ? _decir : null,
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
                tooltip: 'Cómo funciona esto',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// La palabra grande, con la traducción y cómo suena.
  Widget _tarjeta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        boxShadow: Tema.sombra,
      ),
      child: Column(
        children: [
          const Text(
            'DECILA EN VOZ ALTA',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: Tema.verde,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _palabra.italiano,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _palabra.espanol,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
          const SizedBox(height: 6),
          Text(
            'suena ${_palabra.pista}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Tema.verdeOscuro,
            ),
          ),
          const SizedBox(height: 10),
          // Qué mirar de esta palabra: el sonido que se practica, o la cifra
          // cuando es un número.
          Pastilla(texto: _palabra.sonido),
        ],
      ),
    );
  }

  /// El botón grande de hablar. Mientras escucha cambia de color y de texto,
  /// que es lo único que avisa que el micrófono está abierto.
  Widget _microfono() {
    final escuchando = _momento == _Momento.escuchando;
    return Column(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: ElevatedButton(
            onPressed: _escuchar,
            style: ElevatedButton.styleFrom(
              backgroundColor: escuchando ? Tema.incorrecto : Tema.verde,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            child: Icon(escuchando ? Icons.stop : Icons.mic, size: 42),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          escuchando ? 'Escuchando... (tocá para cortar)' : 'Tocá y decila',
          style: const TextStyle(fontSize: 14, color: Tema.textoTenue),
        ),
        if (escuchando) ...[
          const SizedBox(height: 8),
          _barraDeSonido(),
          if (_parcial.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _parcial,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: Tema.verdeOscuro,
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// Cuánto ruido está entrando por el micrófono.
  ///
  /// Es lo que separa "el micrófono no anda" de "te escuchó pero no te
  /// entendió": si la barra no se mueve mientras se habla, el problema es el
  /// micrófono y no la pronunciación.
  Widget _barraDeSonido() {
    return Container(
      width: 140,
      height: 6,
      decoration: BoxDecoration(
        color: Tema.borde,
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _volumen.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Tema.verde,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _resultado() {
    if (_momento != _Momento.contestada) {
      // El aviso del micrófono (sin permiso, sin internet) se muestra igual
      // aunque no haya resultado: es lo que explica por qué no pasa nada.
      return _aviso();
    }

    final (icono, color, titulo) = switch (_como) {
      ComoSalio.bien => (Icons.check_circle, Tema.correcto, '¡Bien dicho!'),
      ComoSalio.casi => (
          Icons.check_circle_outline,
          Tema.verdeOscuro,
          'Casi: te entendió, pero dudó.',
        ),
      ComoSalio.mal => (Icons.cancel, Tema.incorrecto, 'Entendió otra cosa.'),
      ComoSalio.nada => (
          Icons.hearing_disabled,
          Tema.textoTenue,
          'No te escuché. Probá de nuevo.',
        ),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        if (_oido != null && !_oido!.vacio) ...[
          const SizedBox(height: 6),
          Text(
            'Escuché: "${_oido!.mejor}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.3,
              color: Tema.textoTenue,
            ),
          ),
        ],
        _aviso(),
      ],
    );
  }

  Widget _aviso() {
    final problema = _escucha.problema;
    final detalle = _escucha.diagnostico;
    if (problema.isEmpty && detalle.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          if (problema.isNotEmpty)
            Text(
              problema,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.3,
                color: Tema.incorrecto,
              ),
            ),
          // El detalle técnico no es para el alumno: está mientras esto sea
          // una prueba, para poder averiguar por qué un celular no escucha.
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Tema.textoTenue),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que explica el botón de info.
const List<SeccionAyuda> ayudaDeLaPronunciacion = [
  SeccionAyuda(
    titulo: 'Quién te corrige',
    cuerpo: 'Te escucha el mismo reconocedor de voz que usa el teclado del '
        'celular, puesto en italiano. No te pone una nota: te dice qué palabra '
        'entendió. Si entendió la que había que decir, un italiano también te '
        'va a entender.',
  ),
  SeccionAyuda(
    titulo: 'Para que ande',
    ejemplos: [
      'Hay que darle permiso al micrófono la primera vez.',
      'Casi siempre necesita internet.',
      'Hablá cerca y sin ruido atrás.',
      'Decí la palabra sola, sin agregar nada.',
      'Apenas te entiende corta solo: no hay que esperar.',
    ],
  ),
  SeccionAyuda(
    titulo: 'Los sonidos que cambian',
    cuerpo: 'Estos son los que el castellano hace pronunciar mal, y por eso '
        'son los de esta lista.',
    ejemplos: [
      'ci, ce = ch: cinque, ciao, dolce',
      'chi, che = qui, que: chiesa, perché',
      'gn = ñ: gnocchi, signora',
      'gli = como la ll, con la lengua en el paladar: famiglia',
      'sce, sci = sh: pesce, sciare',
      'z = ts: grazie, pizza',
      'La doble consonante se apoya: nonna no es nona.',
    ],
  ),
  SeccionAyuda(
    titulo: 'Los números',
    cuerpo: 'Del 0 al 30. Ojo con estos, que son los que más se traban:',
    ejemplos: [
      'zero arranca con la z italiana: dzé-ro',
      'dieci y todos los de la familia llevan "chi": dié-chi, ún-di-chi',
      'quattro, sette y otto apoyan la doble consonante',
      'ventuno y ventotto se comen la i de venti',
      'due son dos golpes: dú-e, no "due" como en castellano',
    ],
  ),
];

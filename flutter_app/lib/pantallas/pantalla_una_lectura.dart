import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../datos/buscador_de_palabras.dart';
import '../datos/reproductor.dart';
import '../modelos/diccionario.dart';
import '../modelos/lectura.dart';
import '../tema.dart';

/// Una fábula: el audio y el texto, juntos.
///
/// Es la primera pantalla de la app donde se escucha italiano de verdad —no
/// simplificado, no grabado para alumnos— con el texto delante. Escuchar sin
/// texto es ejercicio de oído; escuchar con texto es lo que de verdad enseña
/// palabras, porque se ve dónde termina una y empieza la otra.
///
/// **El renglón que suena se ilumina, si alguien marcó los tiempos.**
/// Marcarlos es trabajo a mano: hay que escuchar la fábula anotando en qué
/// segundo arranca cada verso. Las que todavía no están marcadas muestran el
/// texto quieto, que ya sirve para seguirlo con la vista.
///
/// El texto está en verso, porque la traducción que leen es la de Emilio de
/// Marchi y es poesía rimada. Por eso las palabras que se tocan importan
/// tanto: sin eso, un verso del siglo XIX es una pared.
class PantallaUnaLectura extends StatefulWidget {
  const PantallaUnaLectura({
    super.key,
    required this.lectura,
    required this.ruta,
    required this.reproductor,
    required this.diccionario,
    required this.alVolver,
    this.deQuien = '',
    this.buscador,
  });

  final Lectura lectura;

  /// Dónde quedó guardado el audio en el celular.
  final String ruta;

  final Reproductor reproductor;
  final Diccionario diccionario;
  final VoidCallback alVolver;

  /// Quién firma lo que suena. Lo pone la pantalla bloqueada.
  final String deQuien;

  /// Quién busca las palabras que el diccionario no tiene. Se puede pasar
  /// uno de mentira para probar sin salir a internet.
  final BuscadorDePalabras? buscador;

  @override
  State<PantallaUnaLectura> createState() => _PantallaUnaLecturaState();
}

class _PantallaUnaLecturaState extends State<PantallaUnaLectura> {
  late final BuscadorDePalabras _buscador =
      widget.buscador ?? BuscadorDePalabras();

  bool _sonando = false;
  bool _lenta = false;
  bool _abrio = false;
  String? _porQueNoSuena;

  /// Qué renglón se está diciendo. -1 es ninguno: antes del primer verso va
  /// la presentación de LibriVox, y al final el cierre.
  int _enElRenglon = -1;

  /// True mientras el lector lee el título, que en Pinocchio lo lee antes de
  /// empezar el cuento. Se ilumina como cualquier renglón: es la primera
  /// línea del capítulo, nada más que vive en el encabezado.
  bool _enElTitulo = false;

  StreamSubscription<Duration>? _siguiendo;
  StreamSubscription<void>? _esperandoElFinal;

  final ScrollController _scroll = ScrollController();

  /// Una clave por renglón, para poder preguntarle a cada uno dónde quedó
  /// dibujado. Calcularlo no sirve: un verso largo ocupa dos líneas y el
  /// error se va sumando.
  late final List<GlobalKey> _claves = [
    for (var i = 0; i < widget.lectura.renglones.length; i++) GlobalKey(),
  ];

  @override
  void initState() {
    super.initState();
    _prepararYArrancar();
  }

  @override
  void dispose() {
    _siguiendo?.cancel();
    _esperandoElFinal?.cancel();
    _scroll.dispose();
    // Pausar y no soltar: el reproductor es uno solo para toda la app.
    widget.reproductor.pausar();
    super.dispose();
  }

  /// Se entra a esta pantalla desde el play de la lista, así que arranca
  /// sonando: hacer tocar play otra vez sería pedir dos veces lo mismo.
  Future<void> _prepararYArrancar() async {
    final abrio = await widget.reproductor.cargarGuardado(
      widget.ruta,
      titulo: widget.lectura.titulo,
      deQuien: widget.deQuien,
    );
    if (!mounted) return;
    if (!abrio) {
      setState(() {
        _porQueNoSuena =
            widget.reproductor.porQueFallo ?? 'no se pudo abrir el audio';
      });
      return;
    }
    if (widget.lectura.sigueElAudio) {
      _siguiendo = widget.reproductor.porDonde.listen(_vaPor);
      _esperandoElFinal =
          widget.reproductor.termino.listen((_) => _seAcabo());
    }

    setState(() {
      _abrio = true;
      _sonando = true;
    });

    // Se empieza donde empieza la fábula, no donde empieza el archivo: antes
    // va la presentación de LibriVox, y en una fábula de minuto y medio son
    // dieciséis segundos de espera antes de lo que se vino a escuchar. Quien
    // quiera oírla puede volver con el botón de reiniciar.
    final empieza = widget.lectura.dondeEmpiezaDeVerdad;
    if (empieza != null) await widget.reproductor.irA(empieza);

    await widget.reproductor.reproducir();
  }

  void _vaPor(Duration donde) {
    if (!mounted) return;
    final enElTitulo = widget.lectura.tituloSuenaEn(donde);
    final cual = widget.lectura.cualSuena(donde);
    if (cual == _enElRenglon && enElTitulo == _enElTitulo) return;
    setState(() {
      _enElRenglon = cual;
      _enElTitulo = enElTitulo;
    });
    if (cual >= 0 && _sonando) _acercarA(cual);
  }

  void _seAcabo() {
    if (!mounted) return;
    setState(() {
      _sonando = false;
      _enElRenglon = -1;
      _enElTitulo = false;
    });
  }

  /// Deja a la vista el renglón que suena, a un tercio de la pantalla desde
  /// arriba: así se ve lo que ya se dijo y lo que viene.
  void _acercarA(int i) {
    final donde = _claves[i].currentContext;
    if (donde == null) return;
    Scrollable.ensureVisible(
      donde,
      alignment: 0.35,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _playOPausa() async {
    if (!_abrio) return;
    if (_sonando) {
      await widget.reproductor.pausar();
    } else {
      await widget.reproductor.reproducir();
    }
    if (mounted) setState(() => _sonando = !_sonando);
  }

  Future<void> _desdeElPrincipio() async {
    if (!_abrio) return;
    await widget.reproductor.irA(
      widget.lectura.dondeEmpiezaDeVerdad ?? Duration.zero,
    );
    if (!_sonando) {
      await widget.reproductor.reproducir();
      if (mounted) setState(() => _sonando = true);
    }
  }

  Future<void> _cambiarVelocidad() async {
    final lenta = !_lenta;
    await widget.reproductor.usarVelocidadLenta(lenta);
    if (!mounted) return;
    setState(() => _lenta = lenta);
  }

  /// Qué quiere decir una palabra.
  ///
  /// Casi siempre la sabe el diccionario que viaja en la app: sin internet y
  /// sin gastar nada. Cuando no, se la pregunta al servidor, que la guarda
  /// para que el próximo que la toque no tenga que preguntarla de nuevo.
  ///
  /// En un texto en verso del siglo XIX esto es lo que separa leerlo de
  /// mirarlo.
  Future<void> _queQuiereDecir(String palabra, String renglon) async {
    // Sin signos y en minúscula: el diccionario guarda las palabras así, y
    // en un verso la primera de cada renglón va en mayúscula.
    // El apóstrofo curvo se conserva: es el que usan los textos de
    // Wikisource, y si se cae acá "d’un" llega como "dun" y no hay cómo
    // partirlo después.
    final limpia = palabra
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}'’]", unicode: true), '');
    if (limpia.isEmpty) return;

    // Si hay que salir a internet se avisa. Si no, no se muestra nada: ese
    // parpadeo de "buscando…" cuando la respuesta ya estaba acá se nota.
    final alInstante = _buscador.laSabeSinInternet(widget.diccionario, limpia);
    if (!alInstante) _mostrar('$limpia…');

    final traduccion =
        await _buscador.buscar(widget.diccionario, limpia, donde: renglon);
    if (!mounted) return;

    _mostrar(
      traduccion == null
          ? '$limpia no está en el diccionario'
          // Cuando lo que se tocó era una forma conjugada, se dice de qué
          // palabra viene: "avean → avere: haber, tener". Enseña algo que la
          // traducción sola no enseña, y si la forma está mal resuelta se
          // nota en vez de parecer una traducción rara.
          : traduccion.vieneDe.isEmpty
              ? '$limpia: ${traduccion.comoSeDice}'
              : '$limpia → ${traduccion.vieneDe}: ${traduccion.comoSeDice}',
    );
  }

  void _mostrar(String texto) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final lectura = widget.lectura;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(lectura: lectura, alVolver: widget.alVolver),
        if (_porQueNoSuena != null)
          _NoAbre(porQue: _porQueNoSuena!)
        else
          _Controles(
            sonando: _sonando,
            lenta: _lenta,
            alPlay: _playOPausa,
            alPrincipio: _desdeElPrincipio,
            alCambiarVelocidad: _cambiarVelocidad,
          ),
        const Divider(height: 1),
        Expanded(
          child: lectura.tieneTexto
              ? _ElTexto(
                  lectura: lectura,
                  renglones: lectura.renglones,
                  enElRenglon: _enElRenglon,
                  leyendoElTitulo: _enElTitulo,
                  claves: _claves,
                  scroll: _scroll,
                  alTocarPalabra: _queQuiereDecir,
                )
              : const _SinTexto(),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.lectura, required this.alVolver});

  final Lectura lectura;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    // Sin el título: el título es la primera línea del texto y se va para
    // arriba con el resto. Acá queda lo que tiene que estar siempre a mano,
    // que es la salida y cuánto dura.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: alVolver,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a la lista',
          ),
          Text(
            lectura.cuantoDura,
            style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.sonando,
    required this.lenta,
    required this.alPlay,
    required this.alPrincipio,
    required this.alCambiarVelocidad,
  });

  final bool sonando;
  final bool lenta;
  final VoidCallback alPlay;
  final VoidCallback alPrincipio;
  final VoidCallback alCambiarVelocidad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: alPlay,
            icon: Icon(sonando ? Icons.pause : Icons.play_arrow),
            label: Text(sonando ? 'Pausar' : 'Escuchar'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: alPrincipio,
            icon: const Icon(Icons.replay),
            tooltip: 'Desde el principio',
          ),
          const SizedBox(width: 4),
          // Para quien aprende, bajar la velocidad vale más que cualquier
          // otra cosa de esta pantalla.
          ChoiceChip(
            selected: lenta,
            onSelected: (_) => alCambiarVelocidad(),
            label: const Text('Lento'),
          ),
        ],
      ),
    );
  }
}

class _NoAbre extends StatelessWidget {
  const _NoAbre({required this.porQue});

  final String porQue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        'No se pudo abrir el audio, así que esta fábula se puede leer pero no '
        'escuchar. Motivo: $porQue',
        style: const TextStyle(fontSize: 12.5, color: Tema.textoTenue),
      ),
    );
  }
}

class _SinTexto extends StatelessWidget {
  const _SinTexto();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'De esta fábula no tenemos el texto.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Tema.textoTenue),
        ),
      ),
    );
  }
}

/// El texto, con cada palabra tocable.
/// El título del capítulo, como primera línea del texto.
///
/// Se pinta igual que un renglón mientras el lector lo lee, porque es eso:
/// la primera línea, no un rótulo. En Pinocchio el lector dice "Capitolo
/// primo" y después el título entero, y recién ahí empieza el cuento.
class _ElTitulo extends StatelessWidget {
  const _ElTitulo({required this.lectura, required this.leyendolo});

  final Lectura lectura;
  final bool leyendolo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: leyendolo ? Tema.verdeSuave : null,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      margin: const EdgeInsets.only(bottom: 14),
      child: Text(
        lectura.titulo,
        style: const TextStyle(
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Tema.titulo,
        ),
      ),
    );
  }
}

class _ElTexto extends StatefulWidget {
  const _ElTexto({
    required this.lectura,
    required this.renglones,
    required this.enElRenglon,
    required this.leyendoElTitulo,
    required this.claves,
    required this.scroll,
    required this.alTocarPalabra,
  });

  /// Para el título, que va como primer renglón del texto.
  final Lectura lectura;
  final List<RenglonDeLectura> renglones;
  final int enElRenglon;

  /// True mientras el lector lee el título en voz alta.
  final bool leyendoElTitulo;
  final List<GlobalKey> claves;
  final ScrollController scroll;
  /// Se le pasa la palabra y el renglón entero. El renglón es lo que
  /// desambigua cuando hay que preguntarle al servidor: "lumicino" solo es
  /// "lucecita", y en "ridotto al lumicino" es "en las últimas".
  final void Function(String, String) alTocarPalabra;

  @override
  State<_ElTexto> createState() => _ElTextoState();
}

class _ElTextoState extends State<_ElTexto> {
  /// Un reconocedor por palabra.
  ///
  /// Se guardan y se liberan a mano: uno creado en cada dibujado queda
  /// colgado, y esta pantalla se redibuja cada vez que se toca play.
  final List<TapGestureRecognizer> _gestos = [];

  @override
  void dispose() {
    for (final gesto in _gestos) {
      gesto.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var cual = 0;

    return ListView.builder(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      // El título adelante y el pie atrás, con el texto en el medio.
      itemCount: widget.renglones.length + 2,
      itemBuilder: (context, puesto) {
        // El título va adentro del texto y no en una barra fija arriba
        // porque es la primera línea del capítulo, no un rótulo: en un libro
        // está arriba de la página y se va cuando uno avanza. Clavado arriba
        // se quedaba a la vista todo el capítulo, ocupando lugar y
        // repitiendo algo que ya pasó.
        if (puesto == 0) {
          return _ElTitulo(
            lectura: widget.lectura,
            leyendolo: widget.leyendoElTitulo,
          );
        }

        final i = puesto - 1;
        if (i == widget.renglones.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'Tocá una palabra para ver qué quiere decir.',
              style: TextStyle(fontSize: 12, color: Tema.textoTenue),
            ),
          );
        }

        final suena = i == widget.enElRenglon;
        final partes = <InlineSpan>[];
        // Se parte dejando los espacios adentro, así el renglón se vuelve a
        // armar exactamente como estaba.
        for (final pedazo
            in widget.renglones[i].texto.split(RegExp(r'(?<= )'))) {
          if (pedazo.trim().isEmpty) {
            partes.add(TextSpan(text: pedazo));
            continue;
          }
          if (cual >= _gestos.length) _gestos.add(TapGestureRecognizer());
          final gesto = _gestos[cual++];
          gesto.onTap =
              () => widget.alTocarPalabra(pedazo, widget.renglones[i].texto);
          partes.add(TextSpan(text: pedazo, recognizer: gesto));
        }

        return Container(
          key: widget.claves[i],
          // El que suena se pinta entero, de borde a borde: en un texto en
          // verso los renglones son cortos y desparejos, y subrayar solo las
          // palabras se pierde de vista.
          color: suena ? Tema.verdeSuave : null,
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          margin: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(children: partes),
            style: TextStyle(
              fontSize: 17,
              height: 1.4,
              fontWeight: suena ? FontWeight.w600 : FontWeight.w400,
              color: Tema.texto,
            ),
          ),
        );
      },
    );
  }
}

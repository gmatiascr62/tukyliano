import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../datos/reproductor.dart';
import '../logica/diccionario_buscar.dart';
import '../modelos/diccionario.dart';
import '../modelos/favola.dart';
import '../tema.dart';

/// Una fábula: el audio y el texto, juntos.
///
/// Es la primera pantalla de la app donde se escucha italiano de verdad —no
/// simplificado, no grabado para alumnos— con el texto delante. Escuchar sin
/// texto es ejercicio de oído; escuchar con texto es lo que de verdad enseña
/// palabras, porque se ve dónde termina una y empieza la otra.
///
/// **El renglón que suena no se ilumina**, y conviene decirlo en vez de
/// disimularlo: para eso haría falta saber en qué segundo arranca cada
/// renglón, y eso hay que marcarlo a mano, fábula por fábula. Acá el texto
/// está entero y quieto, y uno lo sigue con la vista.
///
/// El texto está en verso, porque la traducción que leen es la de Emilio de
/// Marchi y es poesía rimada. Por eso las palabras que se tocan importan
/// tanto: sin eso, un verso del siglo XIX es una pared.
class PantallaUnaFavola extends StatefulWidget {
  const PantallaUnaFavola({
    super.key,
    required this.favola,
    required this.ruta,
    required this.reproductor,
    required this.diccionario,
    required this.alVolver,
  });

  final Favola favola;

  /// Dónde quedó guardado el audio en el celular.
  final String ruta;

  final Reproductor reproductor;
  final Diccionario diccionario;
  final VoidCallback alVolver;

  @override
  State<PantallaUnaFavola> createState() => _PantallaUnaFavolaState();
}

class _PantallaUnaFavolaState extends State<PantallaUnaFavola> {
  bool _sonando = false;
  bool _lenta = false;
  bool _abrio = false;
  String? _porQueNoSuena;

  @override
  void initState() {
    super.initState();
    _prepararYArrancar();
  }

  @override
  void dispose() {
    // Pausar y no soltar: el reproductor es uno solo para toda la app.
    widget.reproductor.pausar();
    super.dispose();
  }

  /// Se entra a esta pantalla desde el play de la lista, así que arranca
  /// sonando: hacer tocar play otra vez sería pedir dos veces lo mismo.
  Future<void> _prepararYArrancar() async {
    final abrio = await widget.reproductor.cargarGuardado(
      widget.ruta,
      titulo: widget.favola.titulo,
      deQuien: 'Favole di La Fontaine',
    );
    if (!mounted) return;
    if (!abrio) {
      setState(() {
        _porQueNoSuena =
            widget.reproductor.porQueFallo ?? 'no se pudo abrir el audio';
      });
      return;
    }
    setState(() {
      _abrio = true;
      _sonando = true;
    });
    await widget.reproductor.reproducir();
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
    await widget.reproductor.irA(Duration.zero);
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

  /// Qué quiere decir una palabra, del diccionario que viaja en la app.
  ///
  /// Sin internet y sin gastar nada. En un texto en verso es lo que separa
  /// leerlo de mirarlo.
  void _queQuiereDecir(String palabra) {
    // Sin signos y en minúscula: el diccionario guarda las palabras así, y
    // en un verso la primera de cada renglón va en mayúscula.
    final limpia = palabra
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}']", unicode: true), '');
    if (limpia.isEmpty) return;

    final traduccion = traducir(widget.diccionario, limpia);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
          traduccion == null
              ? '$limpia no está en el diccionario'
              : '$limpia: ${traduccion.comoSeDice}',
        ),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final favola = widget.favola;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(favola: favola, alVolver: widget.alVolver),
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
          child: favola.tieneTexto
              ? _ElTexto(
                  renglones: favola.renglones,
                  alTocarPalabra: _queQuiereDecir,
                )
              : const _SinTexto(),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.favola, required this.alVolver});

  final Favola favola;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: alVolver,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a las fábulas',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  favola.titulo,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Tema.titulo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  favola.cuantoDura,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Tema.textoTenue,
                  ),
                ),
              ],
            ),
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
class _ElTexto extends StatefulWidget {
  const _ElTexto({required this.renglones, required this.alTocarPalabra});

  final List<String> renglones;
  final void Function(String) alTocarPalabra;

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
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      itemCount: widget.renglones.length + 1,
      itemBuilder: (context, i) {
        if (i == widget.renglones.length) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              'Tocá una palabra para ver qué quiere decir.',
              style: TextStyle(fontSize: 12, color: Tema.textoTenue),
            ),
          );
        }

        final partes = <InlineSpan>[];
        // Se parte dejando los espacios adentro, así el renglón se vuelve a
        // armar exactamente como estaba.
        for (final pedazo in widget.renglones[i].split(RegExp(r'(?<= )'))) {
          if (pedazo.trim().isEmpty) {
            partes.add(TextSpan(text: pedazo));
            continue;
          }
          if (cual >= _gestos.length) _gestos.add(TapGestureRecognizer());
          final gesto = _gestos[cual++];
          gesto.onTap = () => widget.alTocarPalabra(pedazo);
          partes.add(TextSpan(text: pedazo, recognizer: gesto));
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text.rich(
            TextSpan(children: partes),
            style: const TextStyle(
              fontSize: 17,
              height: 1.4,
              color: Tema.texto,
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../datos/repositorio_podcast.dart';
import '../datos/voz.dart';
import '../modelos/episodio.dart';
import '../tema.dart';

/// El podcast: episodios hablados por el celular.
///
/// No hay audio grabado. La pantalla recorre las líneas una por una, cambia de
/// voz según quién habla, y espera a que termine cada una antes de pasar a la
/// siguiente. De ahí sale gratis lo de ir pintando la línea que suena: el
/// recorrido ya existe.
///
/// Lo que no se puede hacer así, y hay que decirlo: con la pantalla bloqueada
/// el motor de voz del celular se calla. Para escuchar con el teléfono en el
/// bolsillo habría que generar el audio a archivos y reproducirlos con un
/// reproductor de verdad, que es otra cosa y bastante más trabajo.
class PantallaPodcast extends StatefulWidget {
  const PantallaPodcast({super.key, this.repositorio, this.voz});

  final RepositorioPodcast? repositorio;
  final Voz? voz;

  @override
  State<PantallaPodcast> createState() => _PantallaPodcastState();
}

class _PantallaPodcastState extends State<PantallaPodcast> {
  late final RepositorioPodcast _repositorio =
      widget.repositorio ?? RepositorioPodcast();
  late final Voz _voz = widget.voz ?? VozDelSistema();

  Podcast _podcast = const Podcast(episodios: []);
  bool _cargando = true;
  Episodio? _escuchando;

  /// False cuando el celular no tiene la voz italiana instalada. Sin ella no
  /// hay podcast, y hay que decirlo en vez de leer italiano con sonidos de
  /// otro idioma.
  bool _puedeHablar = true;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    final podcast = await _repositorio.cargar();
    final puedeHablar = await _voz.preparar();
    if (!mounted) return;
    setState(() {
      _podcast = podcast;
      _puedeHablar = puedeHablar;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _voz.callar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_podcast.episodios.isEmpty) {
      return const _Cartel('Todavía no hay episodios.');
    }

    final escuchando = _escuchando;
    if (escuchando != null) {
      return _Reproductor(
        // La clave hace que cambiar de episodio arranque un reproductor
        // nuevo: si no, se quedaría con la línea y la posición del anterior.
        key: ValueKey(escuchando.titulo),
        episodio: escuchando,
        voz: _voz,
        puedeHablar: _puedeHablar,
        alVolver: () async {
          await _voz.callar();
          if (mounted) setState(() => _escuchando = null);
        },
      );
    }

    return _Lista(
      episodios: _podcast.episodios,
      alElegir: (episodio) => setState(() => _escuchando = episodio),
    );
  }
}

class _Cartel extends StatelessWidget {
  const _Cartel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Tema.textoTenue),
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({required this.episodios, required this.alElegir});

  final List<Episodio> episodios;
  final void Function(Episodio) alElegir;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: episodios.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final episodio = episodios[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: const Icon(Icons.headphones, color: Tema.verde),
          title: Text(
            episodio.titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episodio.deQueVa,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${episodio.cuantosTurnos} frases · ${episodio.quienLoCuenta}',
                  style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
                ),
              ],
            ),
          ),
          onTap: () => alElegir(episodio),
        );
      },
    );
  }
}

class _Reproductor extends StatefulWidget {
  const _Reproductor({
    super.key,
    required this.episodio,
    required this.voz,
    required this.puedeHablar,
    required this.alVolver,
  });

  final Episodio episodio;
  final Voz voz;
  final bool puedeHablar;
  final VoidCallback alVolver;

  @override
  State<_Reproductor> createState() => _ReproductorState();
}

class _ReproductorState extends State<_Reproductor> {
  /// Qué línea está sonando. -1 es "ninguna".
  int _sonando = -1;

  /// Por dónde retomar cuando se vuelva a dar play.
  ///
  /// Parar y arrancar de nuevo desde el principio obliga a volver a escuchar
  /// todo lo que ya se escuchó, que en un episodio de tres minutos es
  /// insoportable. Se guarda la línea en la que se paró.
  int _porDonde = 0;

  /// Cuáles tienen la traducción a la vista.
  final Set<int> _traducidas = {};

  bool _andando = false;
  bool _lenta = false;

  /// Sube de a uno cada vez que se para o se arranca. Una corrida que quedó
  /// vieja lo nota y se va sola, en vez de seguir hablando por abajo de la
  /// nueva: sin esto, dar play dos veces seguidas deja dos diálogos
  /// superpuestos.
  int _corrida = 0;

  final ScrollController _scroll = ScrollController();

  /// Una clave por renglón, para poder preguntarle a cada uno dónde quedó
  /// dibujado.
  ///
  /// Antes esto era una cuenta: tantos píxeles por renglón, por el número de
  /// renglón. Pero los renglones no miden todos igual —una frase ocupa una,
  /// dos o tres líneas de texto— así que el error se iba sumando y después de
  /// cien frases la que sonaba quedaba arriba, fuera de la pantalla.
  late final List<GlobalKey> _claves = [
    for (var i = 0; i < widget.episodio.lineas.length; i++) GlobalKey(),
  ];

  @override
  void dispose() {
    _corrida++;
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _playOPausa() async {
    if (_andando) {
      _corrida++;
      await widget.voz.callar();
      if (!mounted) return;
      setState(() {
        _andando = false;
        // Queda parado en la que estaba sonando: al volver, se repite esa
        // entera en vez de arrancar por la mitad.
        if (_sonando >= 0) _porDonde = _sonando;
        _sonando = -1;
      });
      return;
    }

    final mia = ++_corrida;
    setState(() => _andando = true);
    await _reproducir(mia, desde: _porDonde);
  }

  Future<void> _desdeElPrincipio() async {
    _corrida++;
    await widget.voz.callar();
    if (!mounted) return;
    setState(() {
      _porDonde = 0;
      _sonando = -1;
      _andando = false;
    });
  }

  Future<void> _reproducir(int mia, {required int desde}) async {
    final lineas = widget.episodio.lineas;

    for (var i = desde; i < lineas.length; i++) {
      if (mia != _corrida || !mounted) return;

      setState(() {
        _sonando = i;
        _porDonde = i;
      });
      _acercarA(i);

      await _ponerLaVozDe(lineas[i].quien);
      if (mia != _corrida || !mounted) return;

      await widget.voz.decirYEsperar(lineas[i].italiano);
      if (mia != _corrida || !mounted) return;

      // Un respiro entre turnos. Sin esto se atropellan y no parece una
      // conversación.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (mia != _corrida || !mounted) return;
    setState(() {
      _andando = false;
      _sonando = -1;
      // Terminado, el play siguiente arranca de cero: no hay nada que retomar.
      _porDonde = 0;
    });
  }

  /// La voz que le toca a cada uno, si el celular las tiene.
  ///
  /// Las dos que ofrece voz.dart están elegidas a oído y vienen en orden:
  /// Giulia primero, Lorenzo después. Si el celular tiene menos, se habla todo
  /// con la que haya: se pierde el ida y vuelta pero el episodio se escucha.
  Future<void> _ponerLaVozDe(QuienHabla quien) async {
    final voces = widget.voz.voces;
    if (voces.isEmpty) return;
    final cual = quien == QuienHabla.giulia ? 0 : 1;
    await widget.voz.usarVoz(voces[cual.clamp(0, voces.length - 1)]);
  }

  /// Deja a la vista el renglón que está sonando.
  ///
  /// Se le pregunta al renglón dónde está en vez de calcularlo. Si todavía no
  /// está dibujado —la lista solo dibuja lo que se ve y un poco más— se hace
  /// un salto aproximado y se vuelve a intentar en el cuadro siguiente, que
  /// para entonces ya lo dibujó. Reproduciendo de corrido casi nunca hace
  /// falta: el que sigue ya está construido.
  void _acercarA(int i) {
    if (!_scroll.hasClients) return;
    if (_mostrar(i)) return;

    const altoAproximado = 86.0;
    _scroll.jumpTo((i * altoAproximado - 160).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mostrar(i);
    });
  }

  /// True si el renglón estaba dibujado y se lo pudo acercar.
  ///
  /// Queda a poco más de un tercio de la pantalla desde arriba: así se ve lo
  /// que ya se dijo y lo que viene, y la vista no salta en cada frase.
  bool _mostrar(int i) {
    final donde = _claves[i].currentContext;
    if (donde == null) return false;
    Scrollable.ensureVisible(
      donde,
      alignment: 0.35,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    return true;
  }

  Future<void> _cambiarVelocidad() async {
    final lenta = !_lenta;
    await widget.voz.usarVelocidadLenta(lenta);
    if (!mounted) return;
    setState(() => _lenta = lenta);
  }

  /// Un toque en el renglón repite esa línea y deja el episodio parado ahí:
  /// el play siguiente sigue desde esa, que es lo que uno espera después de
  /// volver atrás a escuchar algo que no entendió.
  Future<void> _repetir(int i) async {
    _corrida++;
    await widget.voz.callar();
    if (!mounted) return;
    setState(() {
      _andando = false;
      _sonando = i;
      _porDonde = i;
    });
    final linea = widget.episodio.lineas[i];
    await _ponerLaVozDe(linea.quien);
    await widget.voz.decir(linea.italiano);
  }

  void _mostrarQueQuiereDecir(String palabra, String significado) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('$palabra: $significado'),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final episodio = widget.episodio;

    return Column(
      children: [
        _Cabecera(episodio: episodio, alVolver: widget.alVolver),
        if (!widget.puedeHablar) const _SinVoz(),
        if (widget.puedeHablar)
          _Controles(
            andando: _andando,
            lenta: _lenta,
            retomando: !_andando && _porDonde > 0,
            alPlay: _playOPausa,
            alCambiarVelocidad: _cambiarVelocidad,
            alVolverAlPrincipio: _desdeElPrincipio,
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: episodio.lineas.length,
            itemBuilder: (context, i) => _Turno(
              key: _claves[i],
              linea: episodio.lineas[i],
              episodio: episodio,
              sonando: i == _sonando,
              traducida: _traducidas.contains(i),
              alTocar: widget.puedeHablar ? () => _repetir(i) : null,
              alMantener: () => setState(() {
                if (!_traducidas.remove(i)) _traducidas.add(i);
              }),
              alTocarPalabra: _mostrarQueQuiereDecir,
            ),
          ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.episodio, required this.alVolver});

  final Episodio episodio;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: alVolver,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a los episodios',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  episodio.titulo,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${episodio.cuantosTurnos} frases · ${episodio.quienLoCuenta}',
                  style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SinVoz extends StatelessWidget {
  const _SinVoz();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Text(
        'Este celular no tiene la voz italiana instalada, así que el episodio '
        'no se puede escuchar. Se puede leer igual, y tocar las palabras '
        'subrayadas para ver qué dicen. Para escucharlo, instalá la voz '
        'italiana en Ajustes → Idiomas → Texto a voz.',
        style: TextStyle(fontSize: 13, color: Tema.textoTenue),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.andando,
    required this.lenta,
    required this.retomando,
    required this.alPlay,
    required this.alCambiarVelocidad,
    required this.alVolverAlPrincipio,
  });

  final bool andando;
  final bool lenta;

  /// True cuando está parado en el medio: ahí el botón dice "Seguir" y
  /// aparece el de volver al principio.
  final bool retomando;

  final VoidCallback alPlay;
  final VoidCallback alCambiarVelocidad;
  final VoidCallback alVolverAlPrincipio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: alPlay,
            icon: Icon(andando ? Icons.stop : Icons.play_arrow),
            label: Text(andando
                ? 'Parar'
                : retomando
                    ? 'Seguir'
                    : 'Escuchar'),
          ),
          if (retomando) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: alVolverAlPrincipio,
              icon: const Icon(Icons.replay),
              tooltip: 'Desde el principio',
            ),
          ],
          const SizedBox(width: 8),
          // Para quien aprende, poder bajar la velocidad vale más que
          // cualquier otra cosa de esta pantalla.
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

class _Turno extends StatelessWidget {
  const _Turno({
    super.key,
    required this.linea,
    required this.episodio,
    required this.sonando,
    required this.traducida,
    required this.alTocar,
    required this.alMantener,
    required this.alTocarPalabra,
  });

  final LineaDelEpisodio linea;
  final Episodio episodio;
  final bool sonando;
  final bool traducida;
  final VoidCallback? alTocar;
  final VoidCallback alMantener;
  final void Function(String palabra, String significado) alTocarPalabra;

  @override
  Widget build(BuildContext context) {
    final deGiulia = linea.quien == QuienHabla.giulia;
    // Con un solo narrador la columna del nombre sobra: repetir "Lorenzo"
    // treinta veces no dice nada y come ancho.
    final hayVarios = episodio.quienesHablan.length > 1;

    return InkWell(
      onTap: alTocar,
      onLongPress: alMantener,
      child: Container(
        color: sonando ? Tema.verdeSuave.withValues(alpha: 0.28) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quién habla, en una columna angosta: de un vistazo se ve el ida
            // y vuelta sin leer los nombres uno por uno.
            if (hayVarios)
              SizedBox(
                width: 62,
                child: Text(
                  linea.quien.nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: deGiulia ? Tema.verde : Tema.textoTenue,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FraseConPalabras(
                    frase: linea.italiano,
                    episodio: episodio,
                    sonando: sonando,
                    alTocarPalabra: alTocarPalabra,
                  ),
                  if (traducida) ...[
                    const SizedBox(height: 4),
                    Text(
                      linea.castellano,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La frase, con las palabras del glosario subrayadas y tocables.
///
/// Solo esas: no hay diccionario detrás, hay una lista elegida a mano por
/// episodio. Marcarlas es parte del trato —tocar una palabra y que no pase
/// nada es peor que ver de entrada cuáles tienen algo para mostrar.
class _FraseConPalabras extends StatefulWidget {
  const _FraseConPalabras({
    required this.frase,
    required this.episodio,
    required this.sonando,
    required this.alTocarPalabra,
  });

  final String frase;
  final Episodio episodio;
  final bool sonando;
  final void Function(String palabra, String significado) alTocarPalabra;

  @override
  State<_FraseConPalabras> createState() => _FraseConPalabrasState();
}

class _FraseConPalabrasState extends State<_FraseConPalabras> {
  /// Un reconocedor por palabra tocable.
  ///
  /// Se guardan acá y no se crean en build() porque hay que liberarlos: uno
  /// creado en cada dibujado queda colgado, y la pantalla se redibuja en cada
  /// frase que suena.
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
    final estilo = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: Tema.texto,
      fontWeight: widget.sonando ? FontWeight.w600 : FontWeight.w400,
    );

    // Se parte dejando los espacios adentro de los pedazos, así al volver a
    // juntarlos la frase queda exactamente como estaba.
    final pedazos = widget.frase.split(RegExp(r'(?<= )'));

    final partes = <InlineSpan>[];
    var cual = 0;

    for (final pedazo in pedazos) {
      final significado = widget.episodio.queQuiereDecir(pedazo);
      if (significado == null) {
        partes.add(TextSpan(text: pedazo, style: estilo));
        continue;
      }

      // Se reusa el de la vez anterior si ya existe: las frases no cambian,
      // así que la lista es siempre la misma.
      if (cual >= _gestos.length) _gestos.add(TapGestureRecognizer());
      final gesto = _gestos[cual++];
      gesto.onTap = () => widget.alTocarPalabra(pedazo.trim(), significado);

      partes.add(TextSpan(
        text: pedazo,
        style: estilo.copyWith(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: Tema.verde,
        ),
        recognizer: gesto,
      ));
    }

    return Text.rich(TextSpan(children: partes), style: estilo);
  }
}

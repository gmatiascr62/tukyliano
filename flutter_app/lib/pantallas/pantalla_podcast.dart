import 'package:flutter/material.dart';

import '../datos/repositorio_podcast.dart';
import '../datos/voz.dart';
import '../modelos/episodio.dart';
import '../tema.dart';

/// El podcast: una conversación entre Giulia y Lorenzo, hablada por el celular.
///
/// No hay audio grabado. La pantalla recorre las líneas una por una, cambia de
/// voz según quién habla, y espera a que termine cada una antes de pasar a la
/// siguiente. De ahí sale gratis lo de ir pintando la línea que suena: el
/// recorrido ya existe.
///
/// Es una prueba. Lo que hay que escuchar es si dos minutos de voz sintética
/// se aguantan; si no, el plan B es grabar el audio una vez con una voz de la
/// nube, que suena mucho mejor pero pesa y hay que bajarlo.
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

    // Con un solo episodio no tiene sentido una lista: se entra directo.
    return _Reproductor(
      episodio: _podcast.episodios.first,
      voz: _voz,
      puedeHablar: _puedeHablar,
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

class _Reproductor extends StatefulWidget {
  const _Reproductor({
    required this.episodio,
    required this.voz,
    required this.puedeHablar,
  });

  final Episodio episodio;
  final Voz voz;
  final bool puedeHablar;

  @override
  State<_Reproductor> createState() => _ReproductorState();
}

class _ReproductorState extends State<_Reproductor> {
  /// Qué línea está sonando. -1 es "ninguna".
  int _sonando = -1;

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
        _sonando = -1;
      });
      return;
    }

    final mia = ++_corrida;
    setState(() => _andando = true);
    await _reproducir(mia, desde: 0);
  }

  Future<void> _reproducir(int mia, {required int desde}) async {
    final lineas = widget.episodio.lineas;

    for (var i = desde; i < lineas.length; i++) {
      if (mia != _corrida || !mounted) return;

      setState(() => _sonando = i);
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
    });
  }

  /// La voz que le toca a cada uno, si el celular las tiene.
  ///
  /// Las dos que ofrece voz.dart están elegidas a oído y vienen en orden:
  /// Giulia primero, Lorenzo después. Si el celular tiene menos, se habla todo
  /// con la que haya: se pierde el ida y vuelta pero el episodio se escucha.
  Future<void> _ponerLaVozDe(QuienHabla quien) async {
    final voces = widget.voz.voces;
    // Sin voces para elegir se habla con la de fábrica del celular: se pierde
    // el ida y vuelta, pero el episodio se escucha igual.
    if (voces.isEmpty) return;
    final cual = quien == QuienHabla.giulia ? 0 : 1;
    await widget.voz.usarVoz(voces[cual.clamp(0, voces.length - 1)]);
  }

  void _acercarA(int i) {
    if (!_scroll.hasClients) return;
    // Cada renglón mide distinto, así que esto es una aproximación: alcanza
    // para que la línea que suena quede a la vista.
    const altoAproximado = 86.0;
    final hasta = (i * altoAproximado - 160).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      hasta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _cambiarVelocidad() async {
    final lenta = !_lenta;
    await widget.voz.usarVelocidadLenta(lenta);
    if (!mounted) return;
    setState(() => _lenta = lenta);
  }

  /// Un toque repite esa línea; si el episodio estaba andando, lo para.
  Future<void> _repetir(int i) async {
    _corrida++;
    await widget.voz.callar();
    if (!mounted) return;
    setState(() {
      _andando = false;
      _sonando = i;
    });
    final linea = widget.episodio.lineas[i];
    await _ponerLaVozDe(linea.quien);
    await widget.voz.decir(linea.italiano);
  }

  @override
  Widget build(BuildContext context) {
    final episodio = widget.episodio;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episodio.titulo,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                episodio.deQueVa,
                style: const TextStyle(fontSize: 14, color: Tema.textoTenue),
              ),
              const SizedBox(height: 4),
              Text(
                '${episodio.cuantosTurnos} frases · Giulia y Lorenzo',
                style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
              ),
            ],
          ),
        ),
        if (!widget.puedeHablar) const _SinVoz(),
        if (widget.puedeHablar) _Controles(
          andando: _andando,
          lenta: _lenta,
          alPlay: _playOPausa,
          alCambiarVelocidad: _cambiarVelocidad,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: episodio.lineas.length,
            itemBuilder: (context, i) => _Turno(
              linea: episodio.lineas[i],
              sonando: i == _sonando,
              traducida: _traducidas.contains(i),
              alTocar: widget.puedeHablar ? () => _repetir(i) : null,
              alMantener: () => setState(() {
                if (!_traducidas.remove(i)) _traducidas.add(i);
              }),
            ),
          ),
        ),
      ],
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
        'no se puede escuchar. Se puede leer igual, y mantener apretado un '
        'renglón para ver qué dice. Para escucharlo, instalá la voz italiana '
        'en Ajustes → Idiomas → Texto a voz.',
        style: TextStyle(fontSize: 13, color: Tema.textoTenue),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.andando,
    required this.lenta,
    required this.alPlay,
    required this.alCambiarVelocidad,
  });

  final bool andando;
  final bool lenta;
  final VoidCallback alPlay;
  final VoidCallback alCambiarVelocidad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: alPlay,
            icon: Icon(andando ? Icons.stop : Icons.play_arrow),
            label: Text(andando ? 'Parar' : 'Escuchar'),
          ),
          const SizedBox(width: 12),
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
    required this.linea,
    required this.sonando,
    required this.traducida,
    required this.alTocar,
    required this.alMantener,
  });

  final LineaDelEpisodio linea;
  final bool sonando;
  final bool traducida;
  final VoidCallback? alTocar;
  final VoidCallback alMantener;

  @override
  Widget build(BuildContext context) {
    final deGiulia = linea.quien == QuienHabla.giulia;

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
                  Text(
                    linea.italiano,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: sonando ? FontWeight.w600 : FontWeight.w400,
                    ),
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

import 'package:flutter/material.dart';

import '../datos/repositorio_racconti.dart';
import '../datos/voz.dart';
import '../modelos/racconto.dart';
import '../tema.dart';
import '../widgets/pastilla.dart';
import '../widgets/portada_racconto.dart';
import '../widgets/selector_de_voz.dart';

/// Cuentos para leer en italiano.
///
/// A diferencia de las otras secciones acá no hay puntaje ni respuestas: es
/// leer. El cuento se muestra entero, como cuento, y se toca el renglón que
/// no se entiende para ver la traducción y escucharla. Frase por frase con un
/// botón de "Siguiente" volvería a ser un ejercicio, y de esos ya hay tres.
class PantallaRacconti extends StatefulWidget {
  const PantallaRacconti({super.key, this.repositorio, this.voz});

  /// Inyectables para los tests.
  final RepositorioRacconti? repositorio;
  final Voz? voz;

  @override
  State<PantallaRacconti> createState() => _PantallaRaccontiState();
}

class _PantallaRaccontiState extends State<PantallaRacconti> {
  late final RepositorioRacconti _repositorio =
      widget.repositorio ?? RepositorioRacconti();
  late final Voz _voz = widget.voz ?? VozDelSistema();

  List<Obra> _obras = const [];

  /// La obra elegida, cuando tiene capítulos y hay que elegir uno.
  Obra? _abierta;

  /// El capítulo (o el cuento suelto) que se está leyendo.
  Racconto? _abierto;

  bool _cargando = true;

  /// False cuando el celular no tiene la voz italiana instalada. Ahí no se
  /// habla: leer italiano con los sonidos de otro idioma enseña mal.
  bool _puedeHablar = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _voz.callar();
    super.dispose();
  }

  Future<void> _cargar() async {
    await _repositorio.cargar();
    final puedeHablar = await _voz.preparar();
    if (!mounted) return;
    setState(() {
      _obras = _repositorio.datos.obras;
      _puedeHablar = puedeHablar;
      _cargando = false;
    });
  }

  /// Tocar una obra: si es un cuento suelto se abre para leer, y si tiene
  /// capítulos primero hay que elegir cuál.
  void _abrirObra(Obra obra) {
    setState(() {
      if (obra.tieneCapitulos) {
        _abierta = obra;
      } else {
        _abierto = obra.capitulos.first;
      }
    });
  }

  /// Volver desde la lectura: a los capítulos si venía de una obra, y a la
  /// lista si era un cuento suelto.
  void _cerrarLectura() {
    _voz.callar();
    setState(() => _abierto = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: Text(
          'Cargando cuentos...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    final abierto = _abierto;
    if (abierto != null) {
      return _VistaRacconto(
        racconto: abierto,
        voz: _voz,
        puedeHablar: _puedeHablar,
        alVolver: _cerrarLectura,
      );
    }

    final abierta = _abierta;
    if (abierta != null) {
      return _VistaObra(
        obra: abierta,
        alVolver: () => setState(() => _abierta = null),
        alElegir: (capitulo) => setState(() => _abierto = capitulo),
      );
    }

    if (_obras.isEmpty) {
      return const Center(
        child: Text(
          'Todavía no hay cuentos cargados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _obras.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TarjetaObra(
        obra: _obras[i],
        alTocar: () => _abrirObra(_obras[i]),
      ),
    );
  }
}

/// La tarjeta de la lista. Una novela entera es una sola: dice cuántos
/// capítulos tiene en vez de cuántas frases.
class _TarjetaObra extends StatelessWidget {
  const _TarjetaObra({required this.obra, required this.alTocar});

  final Obra obra;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return _Tarjeta(
      imagen: obra.imagen,
      titulo: obra.titulo,
      subtitulo: obra.tituloEspanol,
      pastilla: 'Nivel ${obra.nivel}',
      detalle: obra.tieneCapitulos
          ? '${obra.capitulos.length} capítulos'
          : '${obra.cuantasLineas} frases',
      alTocar: alTocar,
    );
  }
}

/// Los capítulos de una obra, para elegir por dónde seguir.
class _VistaObra extends StatelessWidget {
  const _VistaObra({
    required this.obra,
    required this.alVolver,
    required this.alElegir,
  });

  final Obra obra;
  final VoidCallback alVolver;
  final ValueChanged<Racconto> alElegir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            _BotonVolver(alVolver: alVolver, tooltip: 'Volver a los cuentos'),
            Expanded(
              child: BandaPortada(
                imagen: obra.imagen,
                titulo: obra.titulo,
                subtitulo: obra.tituloEspanol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${obra.capitulos.length} capítulos · '
          '${obra.cuantasLineas} frases en total',
          style: const TextStyle(fontSize: 12.5, color: Tema.textoTenue),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: obra.capitulos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final capitulo = obra.capitulos[i];
              return _Tarjeta(
                imagen: capitulo.imagen,
                titulo: capitulo.titulo,
                subtitulo: capitulo.tituloEspanol,
                pastilla: '${i + 1}',
                detalle: '${capitulo.lineas.length} frases',
                alTocar: () => alElegir(capitulo),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// El título de arriba con la flecha para volver. Lo comparten la lista de
/// capítulos y el cuento abierto.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.imagen,
    required this.titulo,
    required this.subtitulo,
    required this.alVolver,
    required this.tooltipVolver,
  });

  final String imagen;
  final String titulo;
  final String subtitulo;
  final VoidCallback alVolver;
  final String tooltipVolver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BotonVolver(alVolver: alVolver, tooltip: tooltipVolver),
        PortadaRacconto(imagen: imagen, lado: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Tema.titulo,
                ),
              ),
              Text(
                subtitulo,
                style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// La flecha de atrás, igual en las tres pantallas.
class _BotonVolver extends StatelessWidget {
  const _BotonVolver({required this.alVolver, required this.tooltip});

  final VoidCallback alVolver;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: alVolver,
      icon: const Icon(Icons.arrow_back, color: Tema.verdeOscuro),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.imagen,
    required this.titulo,
    required this.subtitulo,
    required this.pastilla,
    required this.detalle,
    required this.alTocar,
  });

  final String imagen;
  final String titulo;
  final String subtitulo;
  final String pastilla;
  final String detalle;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tema.superficie,
      borderRadius: BorderRadius.circular(Tema.radio),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tema.radio),
            border: Border.all(color: Tema.borde),
          ),
          child: Row(
            children: [
              PortadaRacconto(imagen: imagen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Tema.titulo,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Pastilla(texto: pastilla),
                  const SizedBox(height: 5),
                  Text(
                    detalle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Tema.textoTenue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El cuento abierto.
class _VistaRacconto extends StatefulWidget {
  const _VistaRacconto({
    required this.racconto,
    required this.voz,
    required this.puedeHablar,
    required this.alVolver,
  });

  final Racconto racconto;
  final Voz voz;
  final bool puedeHablar;
  final VoidCallback alVolver;

  @override
  State<_VistaRacconto> createState() => _VistaRaccontoState();
}

class _VistaRaccontoState extends State<_VistaRacconto> {
  /// Los renglones que están mostrando la traducción.
  final _reveladas = <int>{};
  bool _vocabularioAbierto = false;
  bool _lenta = false;

  /// Tocar un renglón lo revela y lo pronuncia. Volver a tocarlo lo esconde,
  /// esta vez callado: si hablara al esconderlo no habría forma de tapar la
  /// traducción sin escuchar la frase de nuevo.
  void _tocarLinea(int i) {
    final revelando = !_reveladas.contains(i);
    setState(() {
      if (revelando) {
        _reveladas.add(i);
      } else {
        _reveladas.remove(i);
      }
    });
    if (!widget.puedeHablar) return;
    if (revelando) {
      widget.voz.decir(widget.racconto.lineas[i].italiano);
    } else {
      widget.voz.callar();
    }
  }

  Future<void> _cambiarVelocidad() async {
    final lenta = !_lenta;
    await widget.voz.usarVelocidadLenta(lenta);
    if (!mounted) return;
    setState(() => _lenta = lenta);
  }

  Future<void> _cambiarVoz(VozItaliana voz) async {
    await widget.voz.usarVoz(voz);
    if (!mounted) return;
    // Se dice el nombre para escuchar en el acto cómo suena la elegida.
    await widget.voz.decir(voz.nombre);
    if (!mounted) return;
    setState(() {});
  }

  bool get _todasReveladas =>
      _reveladas.length == widget.racconto.lineas.length;

  void _mostrarTodo() {
    setState(() {
      if (_todasReveladas) {
        _reveladas.clear();
      } else {
        _reveladas.addAll(
          List.generate(widget.racconto.lineas.length, (i) => i),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final racconto = widget.racconto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _Encabezado(
          imagen: racconto.imagen,
          titulo: racconto.titulo,
          subtitulo: racconto.tituloEspanol,
          alVolver: widget.alVolver,
          tooltipVolver: racconto.esCapitulo
              ? 'Volver a los capítulos'
              : 'Volver a los cuentos',
        ),
        const SizedBox(height: 6),
        _ayuda(),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < racconto.lineas.length; i++)
                  _Linea(
                    linea: racconto.lineas[i],
                    revelada: _reveladas.contains(i),
                    alTocar: () => _tocarLinea(i),
                    // El altavoz solo aparece en el renglón revelado, para
                    // poder repetirlo sin tener que taparlo y destaparlo.
                    alRepetir: widget.puedeHablar
                        ? () => widget.voz.decir(racconto.lineas[i].italiano)
                        : null,
                  ),
                if (racconto.vocabulario.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _vocabulario(racconto),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _mostrarTodo,
            style: OutlinedButton.styleFrom(
              foregroundColor: Tema.verdeOscuro,
              side: const BorderSide(color: Tema.borde),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tema.radio),
              ),
            ),
            child: Text(
              _todasReveladas ? 'Ocultar todo' : 'Mostrar todo',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// La línea de abajo del título. Dice qué hacer, y si el celular no tiene
  /// la voz italiana lo avisa en vez de dejar que la app hable mal.
  Widget _ayuda() {
    if (!widget.puedeHablar) {
      return const Text(
        'Tocá el renglón que no entiendas. Para escucharlo, instalá la voz '
        'italiana en Ajustes → Idiomas → Texto a voz.',
        style: TextStyle(fontSize: 12.5, height: 1.3, color: Tema.textoTenue),
      );
    }

    final voces = widget.voz.voces;
    final elegida = widget.voz.vozElegida ?? (voces.isEmpty ? null : voces.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tocá el renglón para verlo y escucharlo',
          style: TextStyle(fontSize: 12.5, color: Tema.textoTenue),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            // Con una sola voz instalada no hay nada que elegir.
            if (voces.length > 1 && elegida != null) ...[
              SelectorDeVoz(
                voces: voces,
                elegida: elegida,
                alElegir: _cambiarVoz,
              ),
              const SizedBox(width: 6),
            ],
            Pastilla(
              texto: 'Lento',
              icono: Icons.slow_motion_video,
              activa: _lenta,
              alTocar: _cambiarVelocidad,
            ),
          ],
        ),
      ],
    );
  }

  /// Las palabras nuevas, plegadas. Son las que frenan de verdad: una frase
  /// entera se adivina por contexto, una palabra suelta no.
  Widget _vocabulario(Racconto racconto) {
    return Container(
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _vocabularioAbierto = !_vocabularioAbierto),
            borderRadius: BorderRadius.circular(Tema.radio),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vocabulario (${racconto.vocabulario.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Tema.verdeOscuro,
                      ),
                    ),
                  ),
                  Icon(
                    _vocabularioAbierto
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Tema.verdeOscuro,
                  ),
                ],
              ),
            ),
          ),
          if (_vocabularioAbierto)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (final palabra in racconto.vocabulario)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              palabra.italiano,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Tema.titulo,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              palabra.espanol,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Tema.textoTenue,
                              ),
                            ),
                          ),
                        ],
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

class _Linea extends StatelessWidget {
  const _Linea({
    required this.linea,
    required this.revelada,
    required this.alTocar,
    this.alRepetir,
  });

  final LineaRacconto linea;
  final bool revelada;
  final VoidCallback alTocar;

  /// Null cuando no se puede hablar; entonces no se dibuja el altavoz.
  final VoidCallback? alRepetir;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(Tema.radioChico),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              linea.italiano,
              style: TextStyle(
                fontSize: 18,
                height: 1.45,
                color: Tema.texto,
                // La revelada se marca en verde: al volver a leer de corrido
                // se ve de un vistazo cuáles costaron.
                fontWeight: revelada ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (revelada) ...[
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      linea.espanol,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: Tema.verdeOscuro,
                      ),
                    ),
                  ),
                  if (alRepetir != null)
                    InkWell(
                      onTap: alRepetir,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 19,
                          color: Tema.verde,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

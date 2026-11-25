import 'package:flutter/material.dart';
import 'constantes.dart';
import 'datos/actualizacion.dart';
import 'datos/android.dart';
import 'datos/audio_de_fondo.dart';
import 'datos/escucha.dart';
import 'datos/repositorio_articoli.dart';
import 'datos/repositorio_frases.dart';
import 'datos/repositorio_particelle.dart';
import 'datos/repositorio_preposizioni.dart';
import 'datos/repositorio_racconti.dart';
import 'datos/progreso.dart';
import 'datos/repositorio_percorso.dart';
import 'datos/reproductor.dart';
import 'datos/repositorio_verbos.dart';
import 'datos/voz.dart';
import 'ia/servidor.dart';
import 'modelos/destino.dart';
import 'modelos/percorso.dart';
import 'modelos/seccion.dart';
import 'modelos/verbo.dart';
import 'pantallas/pantalla_articoli.dart';
import 'pantallas/pantalla_ciudad.dart';
import 'pantallas/pantalla_mapa.dart';
import 'pantallas/pantalla_conversacion.dart';
import 'pantallas/pantalla_frases.dart';
import 'pantallas/pantalla_gramatica.dart';
import 'pantallas/pantalla_preposizioni.dart';
import 'pantallas/pantalla_escuchar.dart';
import 'pantallas/pantalla_radio.dart';
import 'pantallas/pantalla_pronunciacion.dart';
import 'pantallas/pantalla_proximamente.dart';
import 'pantallas/pantalla_quiz.dart';
import 'pantallas/pantalla_racconti.dart';
import 'pantallas/pantalla_seleccion.dart';
import 'pantallas/pantalla_via.dart';
import 'tema.dart';
import 'widgets/aviso_actualizacion.dart';
import 'widgets/encabezado.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lo que hace que el podcast y la radio sigan sonando con la pantalla
  // bloqueada. Si falla, la app arranca igual y lo avisa adentro.
  await AudioDeFondo.prender();
  await Android.preguntarSiPuedeNotificar();

  runApp(const TukylianoApp());
}

class TukylianoApp extends StatelessWidget {
  const TukylianoApp({
    super.key,
    this.servidor,
    this.repositorio,
    this.frasesLocales,
    this.articoli,
    this.preposizioni,
    this.racconti,
    this.camino,
    this.via,
    this.voz,
    this.escucha,
    this.progreso,
    this.actualizacion,
    this.reproductor,
  });

  /// Inyectables para los tests; en la app real se usan los de verdad.
  final Servidor? servidor;
  final RepositorioVerbos? repositorio;
  final RepositorioFrases? frasesLocales;
  final RepositorioArticoli? articoli;
  final RepositorioPreposizioni? preposizioni;
  final RepositorioRacconti? racconti;
  final RepositorioPercorso? camino;
  final RepositorioParticelle? via;
  final Voz? voz;
  final Escucha? escucha;
  final Progreso? progreso;
  final Actualizacion? actualizacion;
  final Reproductor? reproductor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: nombreDeLaApp,
      debugShowCheckedModeBanner: false,
      theme: Tema.datos,
      home: PantallaPrincipal(
        servidor: servidor,
        repositorio: repositorio,
        frasesLocales: frasesLocales,
        articoli: articoli,
        preposizioni: preposizioni,
        racconti: racconti,
        camino: camino,
        via: via,
        voz: voz,
        escucha: escucha,
        progreso: progreso,
        actualizacion: actualizacion,
        reproductor: reproductor,
      ),
    );
  }
}

/// Contenedor con la barra de navegación fija arriba y la sección elegida
/// debajo. Equivale al ScreenManager de la app Kivy.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    this.reproductor,
    this.servidor,
    this.repositorio,
    this.frasesLocales,
    this.articoli,
    this.preposizioni,
    this.racconti,
    this.camino,
    this.via,
    this.voz,
    this.escucha,
    this.progreso,
    this.actualizacion,
  });

  final Servidor? servidor;
  final RepositorioVerbos? repositorio;
  final RepositorioFrases? frasesLocales;
  final RepositorioArticoli? articoli;
  final RepositorioPreposizioni? preposizioni;
  final RepositorioRacconti? racconti;
  final RepositorioPercorso? camino;
  final RepositorioParticelle? via;
  final Voz? voz;
  final Escucha? escucha;
  final Progreso? progreso;
  final Actualizacion? actualizacion;
  final Reproductor? reproductor;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  late final RepositorioVerbos _repositorio =
      widget.repositorio ?? RepositorioVerbos();
  late final RepositorioFrases _frasesLocales =
      widget.frasesLocales ?? RepositorioFrases();
  late final RepositorioArticoli _articoli =
      widget.articoli ?? RepositorioArticoli();
  late final RepositorioPreposizioni _preposizioni =
      widget.preposizioni ?? RepositorioPreposizioni();
  late final RepositorioPercorso _camino =
      widget.camino ?? RepositorioPercorso();

  /// La ciudad del camino que está abierta, por id. Null = se ve el mapa.
  String? _ciudad;

  Ciudad? get _ciudadAbierta {
    final cual = _ciudad;
    if (cual == null) return null;
    for (final ciudad in _camino.camino.ciudades) {
      if (ciudad.id == cual) return ciudad;
    }
    return null;
  }

  late final RepositorioRacconti _racconti =
      widget.racconti ?? RepositorioRacconti();
  late final RepositorioParticelle _via =
      widget.via ?? RepositorioParticelle.via();

  /// La voz vive acá y no en la pantalla de cuentos: así la que se elige
  /// sigue elegida al pasar por otra sección y volver.
  late final Voz _voz = widget.voz ?? VozDelSistema();
  late final Servidor _servidor = widget.servidor ?? Servidor();

  /// Lo que se lleva hecho. Vive acá porque lo alimentan casi todas las
  /// secciones y lo muestra el inicio.
  late final Progreso _progreso = widget.progreso ?? Progreso();

  /// El reproductor, uno solo para toda la app.
  ///
  /// Lo usan el podcast y la radio, nunca las dos a la vez. Vive acá y no
  /// adentro de cada pantalla porque el servicio de Android que hace sonar el
  /// audio con la pantalla bloqueada sirve para un solo reproductor: con dos,
  /// la notificación y los botones del auricular no saben a cuál le hablan.
  ///
  /// Las pantallas lo pausan al salir; soltarlo es trabajo de acá.
  late final Reproductor _reproductor =
      widget.reproductor ?? ReproductorDeVerdad();

  /// Dónde se está parado. Null es el inicio, con los cuatro botones.
  Seccion? _seccion;

  /// True cuando se entró a gramática pero todavía no se eligió cuál.
  bool _eligiendoTema = false;

  DatosVerbos? _datos;

  /// Solo se llena si los verbos no se pudieron cargar: ahí no hay nada que
  /// practicar y hay que decirlo. El chequeo de verbos nuevos, en cambio, es
  /// silencioso.
  String _error = '';

  /// La sección Verbos alterna entre el quiz y la pantalla de selección.
  bool _eligiendoVerbos = false;

  /// La sección Frases alterna igual: primero se elige, después se practica.
  bool _eligiendoFrases = true;
  List<String>? _verbosFrases;
  List<String>? _tiemposFrases;
  int _generacionFrases = 0;

  /// Null mientras el usuario no eligió nada: en ese caso se practica con
  /// todos los verbos, así los que llegan por actualización entran solos.
  List<String>? _verbosElegidos;
  List<String>? _tiemposElegidos;

  /// Cambia en cada "Empezar" para que el quiz arranque de cero (puntaje
  /// incluido), igual que en Kivy, que recreaba el widget.
  int _generacionQuiz = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarFrases();
    _cargarArticoli();
    _cargarPreposizioni();
    _cargarRacconti();
    _cargarVia();
    _cargarProgreso();
    _cargarCamino();
  }

  /// Lee el camino y redibuja cuando está. Mientras tanto el mapa se ve
  /// sin ciudades, que es menos de un parpadeo.
  Future<void> _cargarCamino() async {
    await _camino.cargar();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reproductor.soltar();
    super.dispose();
  }

  Future<void> _cargarProgreso() async {
    await _progreso.cargar();
    if (!mounted) return;
    setState(() {});
  }

  /// Las frases se leen al arrancar y, si hay internet, se chequea si GitHub
  /// tiene una tanda nueva. No bloquea nada: si falla, se sigue con las que
  /// ya están.
  Future<void> _cargarFrases() async {
    await _frasesLocales.cargar();
    await _frasesLocales.verificarActualizacion();
  }

  /// Igual que las frases: se leen las guardadas y se chequea GitHub por si
  /// hay palabras nuevas.
  Future<void> _cargarArticoli() async {
    await _articoli.cargar();
    await _articoli.verificarActualizacion();
  }

  /// Igual que los artículos.
  Future<void> _cargarPreposizioni() async {
    await _preposizioni.cargar();
    await _preposizioni.verificarActualizacion();
  }

  /// Igual que el resto.
  Future<void> _cargarRacconti() async {
    await _racconti.cargar();
    await _racconti.verificarActualizacion();
  }

  /// Igual que el resto.
  Future<void> _cargarVia() async {
    await _via.cargar();
    await _via.verificarActualizacion();
  }

  Future<void> _cargarDatos() async {
    try {
      final datos = await _repositorio.cargar();
      if (!mounted) return;
      setState(() => _datos = datos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudieron cargar los verbos: $e');
      return;
    }

    // El chequeo va después de mostrar los verbos guardados, para que la app
    // sea usable aunque no haya internet. Si llegan verbos nuevos aparecen
    // solos, sin avisar nada.
    final resultado = await _repositorio.verificarActualizacion(
      _datos!.version,
    );
    if (!mounted || resultado.datos == null) return;
    setState(() => _datos = resultado.datos);
  }

  void _irA(Seccion seccion) {
    setState(() {
      _seccion = seccion;
      _eligiendoTema = false;
      // Tocar "Verbos" o "Frases" lleva a elegir qué practicar, como en la app
      // Kivy. Si se conservara el paso, al volver desde otra sección caía
      // directo en la práctica y no se podía cambiar la selección.
      if (seccion == Seccion.verbos) _eligiendoVerbos = true;
      if (seccion == Seccion.frases) _eligiendoFrases = true;
      // Al entrar a una sección se cierra la ciudad: al volver se
      // vuelve al mapa, que ahora es el inicio.
      _ciudad = null;
    });
    // Entrar a practicar ya cuenta como haber practicado hoy, aunque después
    // no se acierte nada.
    _progreso.practico();
  }

  void _irAlDestino(Destino destino) {
    switch (destino) {
      case Destino.racconti:
        _irA(Seccion.racconti);
      case Destino.hablar:
        _irA(Seccion.hablar);
      case Destino.chat:
        _irA(Seccion.chat);
      case Destino.podcast:
        _irA(Seccion.podcast);
      case Destino.radio:
        _irA(Seccion.radio);
      case Destino.gramatica:
        setState(() {
          _seccion = null;
          _eligiendoTema = true;
        });
    }
  }

  /// Un paso para atrás. Desde una sección de gramática se vuelve a la lista
  /// de temas, no al inicio: es de donde se entró.
  void _volver() {
    setState(() {
      if (_seccion != null && _esDeGramatica(_seccion!)) {
        _seccion = null;
        _eligiendoTema = true;
      } else {
        _seccion = null;
        _eligiendoTema = false;
      }
    });
  }

  static bool _esDeGramatica(Seccion seccion) => const {
    Seccion.frases,
    Seccion.verbos,
    Seccion.articoli,
    Seccion.preposizioni,
    Seccion.via,
    Seccion.ci,
    Seccion.ne,
  }.contains(seccion);

  bool get _enElInicio => _seccion == null && !_eligiendoTema;

  void _empezarFrases(List<String> verbos, List<String> tiempos) {
    setState(() {
      _verbosFrases = _recordar(verbos, _datos?.verbos.keys);
      _tiemposFrases = _recordar(tiempos, tiemposDisponibles);
      _eligiendoFrases = false;
      _generacionFrases++;
    });
  }

  void _empezarQuiz(List<String> verbos, List<String> tiempos) {
    setState(() {
      _verbosElegidos = _recordar(verbos, _datos?.verbos.keys);
      _tiemposElegidos = _recordar(tiempos, tiemposDisponibles);
      _eligiendoVerbos = false;
      _generacionQuiz++;
    });
  }

  /// Guarda la selección para volver a mostrarla tildada la próxima vez.
  ///
  /// Si el usuario tildó todo, se guarda null en vez de la lista completa:
  /// "todos" sigue significando todos, así los verbos que lleguen después por
  /// actualización entran solos en vez de aparecer destildados.
  List<String>? _recordar(List<String> elegidos, Iterable<String>? universo) {
    if (universo != null && elegidos.toSet().containsAll(universo)) return null;
    return elegidos;
  }

  /// Los verbos con los que se practica: la selección del usuario, o todos si
  /// todavía no eligió nada (así los que llegan por actualización entran solos).
  List<Verbo> _resolverVerbos(List<String>? elegidos) {
    final todos = _datos?.verbos ?? {};
    if (elegidos == null) return todos.values.toList();
    return elegidos
        .where(todos.containsKey)
        .map((nombre) => todos[nombre]!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón de atrás del celular hace lo mismo que la flecha; desde el
      // inicio sí cierra la app, que es lo que se espera.
      canPop: _enElInicio,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _volver();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (!_enElInicio) ...[
                  Encabezado(titulo: _titulo(), alVolver: _volver),
                  const SizedBox(height: 6),
                ],
                // Arriba de todo y sin ocupar nada cuando no hay novedades.
                AvisoActualizacion(actualizacion: widget.actualizacion),
                Expanded(child: _cuerpo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _titulo() =>
      _seccion?.etiqueta ?? (_eligiendoTema ? 'Gramática' : nombreDeLaApp);

  Widget _cuerpo() {
    final seccion = _seccion;
    if (seccion == null) {
      if (_eligiendoTema) return PantallaGramatica(alElegir: _irA);

      final abierta = _ciudadAbierta;
      if (abierta != null) {
        return PantallaCiudad(
          ciudad: abierta,
          progreso: _progreso,
          alVolver: () => setState(() => _ciudad = null),
          alIrA: _irAlDestino,
        );
      }

      // El mapa es la primera pantalla de la app.
      //
      // Sin cartel de "cargando" en el medio: el mapa se dibuja de una y
      // las ciudades aparecen cuando el archivo terminó de leerse, que es
      // un parpadeo. Un cartel que gira acá sería lo primero que se ve al
      // abrir la app, y además no deja nunca quieta a la pantalla.
      return PantallaMapa(
        ciudades: _camino.camino.ciudades,
        progreso: _progreso,
        alElegir: (ciudad) => setState(() => _ciudad = ciudad.id),
        alIrA: _irAlDestino,
      );
    }

    switch (seccion) {
      case Seccion.podcast:
        return PantallaEscuchar(reproductor: _reproductor);
      case Seccion.radio:
        return PantallaRadio(reproductor: _reproductor);
      case Seccion.articoli:
        return PantallaArticoli(repositorio: _articoli, progreso: _progreso);
      case Seccion.frases:
        return _seccionFrases();
      case Seccion.verbos:
        return _seccionVerbos();
      case Seccion.preposizioni:
        return PantallaPreposizioni(
          repositorio: _preposizioni,
          progreso: _progreso,
        );
      case Seccion.hablar:
        return PantallaPronunciacion(
          voz: _voz,
          escucha: widget.escucha,
          progreso: _progreso,
        );
      case Seccion.via:
        return PantallaVia(repositorio: _via, progreso: _progreso);
      case Seccion.ci:
        return const PantallaProximamente(
          adelanto:
              'El ci que reemplaza un lugar (vado a Roma: ci vado) y el '
              "de c'è, ci sono.",
        );
      case Seccion.ne:
        return const PantallaProximamente(
          adelanto:
              'El ne de la cantidad y del "de eso": ne ho due, ne '
              'parliamo domani.',
        );
      case Seccion.racconti:
        return PantallaRacconti(repositorio: _racconti, voz: _voz);
      case Seccion.chat:
        // Sin key ni nada que guarde el estado: al cambiar de sección esta
        // pantalla se destruye y la charla se olvida, que es lo que se pidió.
        return PantallaConversacion(servidor: _servidor, voz: _voz);
    }
  }

  Widget _seccionFrases() {
    final datos = _datos;
    if (datos == null) {
      return const Center(
        child: Text(
          'Cargando verbos...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_eligiendoFrases) {
      return PantallaSeleccion(
        // La clave separa esta pantalla de la de Verbos: sin ella Flutter
        // reutiliza el State entre secciones y una se lleva los tildes de la
        // otra.
        key: const ValueKey('seleccion-frases'),
        verbos: datos.verbos,
        alConfirmar: _empezarFrases,
        verbosMarcados: _verbosFrases,
        tiemposMarcados: _tiemposFrases,
      );
    }

    return PantallaFrases(
      key: ValueKey(_generacionFrases),
      verbos: _resolverVerbos(_verbosFrases),
      tiempos: _tiemposFrases ?? tiemposDisponibles,
      frasesLocales: _frasesLocales,
      progreso: _progreso,
    );
  }

  Widget _seccionVerbos() {
    final datos = _datos;
    if (datos == null) {
      return Center(
        child: Text(
          _error.isEmpty ? 'Cargando verbos...' : _error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_eligiendoVerbos) {
      return PantallaSeleccion(
        key: const ValueKey('seleccion-verbos'),
        verbos: datos.verbos,
        alConfirmar: _empezarQuiz,
        verbosMarcados: _verbosElegidos,
        tiemposMarcados: _tiemposElegidos,
      );
    }

    return PantallaQuiz(
      key: ValueKey(_generacionQuiz),
      verbos: _resolverVerbos(_verbosElegidos),
      tiempos: _tiemposElegidos ?? tiemposDisponibles,
      progreso: _progreso,
    );
  }
}

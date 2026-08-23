import 'package:flutter/material.dart';

import 'constantes.dart';
import 'datos/actualizacion.dart';
import 'datos/almacenamiento_clave.dart';
import 'datos/repositorio_articoli.dart';
import 'datos/repositorio_frases.dart';
import 'datos/repositorio_preposizioni.dart';
import 'datos/repositorio_racconti.dart';
import 'datos/repositorio_verbos.dart';
import 'datos/voz.dart';
import 'ia/gemini.dart';
import 'modelos/verbo.dart';
import 'pantallas/pantalla_articoli.dart';
import 'pantallas/pantalla_chat.dart';
import 'pantallas/pantalla_frases.dart';
import 'pantallas/pantalla_preposizioni.dart';
import 'pantallas/pantalla_proximamente.dart';
import 'pantallas/pantalla_quiz.dart';
import 'pantallas/pantalla_racconti.dart';
import 'pantallas/pantalla_seleccion.dart';
import 'tema.dart';
import 'widgets/aviso_actualizacion.dart';
import 'widgets/barra_superior.dart';

void main() {
  runApp(const TukylianoApp());
}

class TukylianoApp extends StatelessWidget {
  const TukylianoApp({
    super.key,
    this.almacenClave,
    this.repositorio,
    this.frasesLocales,
    this.articoli,
    this.preposizioni,
    this.racconti,
    this.voz,
    this.gemini,
    this.actualizacion,
  });

  /// Inyectables para los tests; en la app real se usan los de verdad.
  final AlmacenamientoClave? almacenClave;
  final RepositorioVerbos? repositorio;
  final RepositorioFrases? frasesLocales;
  final RepositorioArticoli? articoli;
  final RepositorioPreposizioni? preposizioni;
  final RepositorioRacconti? racconti;
  final Voz? voz;
  final Gemini? gemini;
  final Actualizacion? actualizacion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tukyliano',
      debugShowCheckedModeBanner: false,
      theme: Tema.datos,
      home: PantallaPrincipal(
        almacenClave: almacenClave,
        repositorio: repositorio,
        frasesLocales: frasesLocales,
        articoli: articoli,
        preposizioni: preposizioni,
        racconti: racconti,
        voz: voz,
        gemini: gemini,
        actualizacion: actualizacion,
      ),
    );
  }
}

/// Contenedor con la barra de navegación fija arriba y la sección elegida
/// debajo. Equivale al ScreenManager de la app Kivy.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({
    super.key,
    this.almacenClave,
    this.repositorio,
    this.frasesLocales,
    this.articoli,
    this.preposizioni,
    this.racconti,
    this.voz,
    this.gemini,
    this.actualizacion,
  });

  final AlmacenamientoClave? almacenClave;
  final RepositorioVerbos? repositorio;
  final RepositorioFrases? frasesLocales;
  final RepositorioArticoli? articoli;
  final RepositorioPreposizioni? preposizioni;
  final RepositorioRacconti? racconti;
  final Voz? voz;
  final Gemini? gemini;
  final Actualizacion? actualizacion;

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
  late final RepositorioRacconti _racconti =
      widget.racconti ?? RepositorioRacconti();

  /// La voz vive acá y no en la pantalla de cuentos: así la que se elige
  /// sigue elegida al pasar por otra sección y volver.
  late final Voz _voz = widget.voz ?? VozDelSistema();
  late final AlmacenamientoClave _almacenClave =
      widget.almacenClave ?? AlmacenamientoClave();

  /// Se abre en Racconti: es lo que se hace cuando se agarra la app sin un
  /// plan, y las otras secciones piden elegir verbos y tiempos antes de
  /// empezar.
  Seccion _seccion = Seccion.racconti;
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
    final resultado = await _repositorio.verificarActualizacion(_datos!.version);
    if (!mounted || resultado.datos == null) return;
    setState(() => _datos = resultado.datos);
  }

  void _irA(Seccion seccion) {
    setState(() {
      _seccion = seccion;
      // Tocar "Verbos" o "Frases" lleva a elegir qué practicar, como en la app
      // Kivy. Si se conservara el paso, al volver desde otra sección caía
      // directo en la práctica y no se podía cambiar la selección.
      if (seccion == Seccion.verbos) _eligiendoVerbos = true;
      if (seccion == Seccion.frases) _eligiendoFrases = true;
    });
  }

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              BarraSuperior(onSeccion: _irA, actual: _seccion),
              // Arriba de todo y sin ocupar nada cuando no hay novedades.
              AvisoActualizacion(actualizacion: widget.actualizacion),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    switch (_seccion) {
      case Seccion.articoli:
        return PantallaArticoli(repositorio: _articoli);
      case Seccion.frases:
        return _seccionFrases();
      case Seccion.verbos:
        return _seccionVerbos();
      case Seccion.preposizioni:
        return PantallaPreposizioni(repositorio: _preposizioni);
      case Seccion.via:
        return const PantallaProximamente(
          adelanto: 'El via que se le pega al verbo y le cambia el sentido: '
              'andare via, portare via, buttare via.',
        );
      case Seccion.ci:
        return const PantallaProximamente(
          adelanto: 'El ci que reemplaza un lugar (vado a Roma: ci vado) y el '
              "de c'è, ci sono.",
        );
      case Seccion.ne:
        return const PantallaProximamente(
          adelanto: 'El ne de la cantidad y del "de eso": ne ho due, ne '
              'parliamo domani.',
        );
      case Seccion.racconti:
        return PantallaRacconti(repositorio: _racconti, voz: _voz);
      case Seccion.chat:
        // Sin key ni nada que guarde el estado: al cambiar de sección esta
        // pantalla se destruye y la charla se olvida, que es lo que se pidió.
        return PantallaChat(
          almacenClave: _almacenClave,
          voz: _voz,
          gemini: widget.gemini,
        );
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
    );
  }
}

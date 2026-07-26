import 'package:flutter/material.dart';

import 'constantes.dart';
import 'datos/almacenamiento_clave.dart';
import 'datos/repositorio_verbos.dart';
import 'ia/gemini.dart';
import 'modelos/verbo.dart';
import 'pantallas/pantalla_articoli.dart';
import 'pantallas/pantalla_clave_ia.dart';
import 'pantallas/pantalla_frases.dart';
import 'pantallas/pantalla_quiz.dart';
import 'pantallas/pantalla_seleccion.dart';
import 'tema.dart';
import 'widgets/barra_superior.dart';

void main() {
  runApp(const TukylianoApp());
}

class TukylianoApp extends StatelessWidget {
  const TukylianoApp({
    super.key,
    this.almacenClave,
    this.gemini,
    this.repositorio,
  });

  /// Inyectables para los tests; en la app real se usan los de verdad.
  final AlmacenamientoClave? almacenClave;
  final Gemini? gemini;
  final RepositorioVerbos? repositorio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tukyliano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Tema.fondo),
      home: PantallaPrincipal(
        almacenClave: almacenClave,
        gemini: gemini,
        repositorio: repositorio,
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
    this.gemini,
    this.repositorio,
  });

  final AlmacenamientoClave? almacenClave;
  final Gemini? gemini;
  final RepositorioVerbos? repositorio;

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

/// Dentro de la sección Frases: primero la clave (si falta), después elegir
/// qué practicar, después la práctica en sí.
enum _PasoFrases { clave, seleccion, practica }

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  late final RepositorioVerbos _repositorio =
      widget.repositorio ?? RepositorioVerbos();
  late final AlmacenamientoClave _almacenClave =
      widget.almacenClave ?? AlmacenamientoClave();

  Seccion _seccion = Seccion.verbos;
  DatosVerbos? _datos;
  String _estado = '';

  /// La sección Verbos alterna entre el quiz y la pantalla de selección.
  bool _eligiendoVerbos = false;

  _PasoFrases _pasoFrases = _PasoFrases.seleccion;
  String? _claveGemini;
  String _errorClave = '';
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
    _cargarClave();
  }

  /// Se lee una sola vez al arrancar, así navegar a Frases no tiene que
  /// esperar una lectura de disco.
  Future<void> _cargarClave() async {
    final clave = await _almacenClave.cargar();
    if (!mounted || clave == null) return;
    setState(() => _claveGemini = clave);
  }

  Future<void> _cargarDatos() async {
    try {
      final datos = await _repositorio.cargar();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _estado = 'Buscando verbos nuevos...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _estado = 'No se pudieron cargar los verbos: $e');
      return;
    }

    // El chequeo va después de mostrar los verbos guardados, para que la app
    // sea usable aunque no haya internet.
    final resultado = await _repositorio.verificarActualizacion(_datos!.version);
    if (!mounted) return;
    setState(() {
      if (resultado.datos != null) _datos = resultado.datos;
      _estado = resultado.estado.mensaje;
    });
  }

  void _irA(Seccion seccion) {
    setState(() {
      _seccion = seccion;
      // Tocar "Verbos" lleva a elegir qué practicar, como en la app Kivy.
      if (seccion == Seccion.verbos) _eligiendoVerbos = true;
      // Tocar "Frases" siempre vuelve a elegir qué practicar (o a pedir la
      // clave si todavía no hay). Si se conservara el paso, al volver desde
      // otra sección caía directo en la práctica y no se podía cambiar la
      // selección.
      if (seccion == Seccion.frases) {
        _pasoFrases =
            _claveGemini == null ? _PasoFrases.clave : _PasoFrases.seleccion;
      }
    });
  }

  Future<void> _guardarClave(String clave) async {
    await _almacenClave.guardar(clave);
    if (!mounted) return;
    setState(() {
      _claveGemini = clave;
      _errorClave = '';
      _pasoFrases = _PasoFrases.seleccion;
    });
  }

  /// Gemini rechazó la clave guardada: se borra y se vuelve a pedir.
  Future<void> _claveInvalida() async {
    await _almacenClave.borrar();
    if (!mounted) return;
    setState(() {
      _claveGemini = null;
      _errorClave =
          'La clave guardada ya no funciona (¿fue revocada?). Pegá una nueva.';
      _pasoFrases = _PasoFrases.clave;
    });
  }

  void _empezarFrases(List<String> verbos, List<String> tiempos) {
    setState(() {
      _verbosFrases = verbos;
      _tiemposFrases = tiempos;
      _pasoFrases = _PasoFrases.practica;
      _generacionFrases++;
    });
  }

  void _empezarQuiz(List<String> verbos, List<String> tiempos) {
    setState(() {
      _verbosElegidos = verbos;
      _tiemposElegidos = tiempos;
      _eligiendoVerbos = false;
      _generacionQuiz++;
    });
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
              BarraSuperior(onSeccion: _irA),
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
        return const PantallaArticoli();
      case Seccion.frases:
        return _seccionFrases();
      case Seccion.verbos:
        return _seccionVerbos();
    }
  }

  Widget _seccionFrases() {
    if (_pasoFrases == _PasoFrases.clave || _claveGemini == null) {
      return PantallaClaveIA(onGuardar: _guardarClave, error: _errorClave);
    }

    final datos = _datos;
    if (datos == null) {
      return const Center(
        child: Text(
          'Cargando verbos...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_pasoFrases == _PasoFrases.seleccion) {
      return PantallaSeleccion(
        verbos: datos.verbos,
        alConfirmar: _empezarFrases,
      );
    }

    return PantallaFrases(
      key: ValueKey(_generacionFrases),
      verbos: _resolverVerbos(_verbosFrases),
      tiempos: _tiemposFrases ?? tiemposDisponibles,
      apiKey: _claveGemini!,
      onClaveInvalida: _claveInvalida,
      gemini: widget.gemini,
    );
  }

  Widget _seccionVerbos() {
    final datos = _datos;
    if (datos == null) {
      return Center(
        child: Text(
          _estado.isEmpty ? 'Cargando verbos...' : _estado,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_eligiendoVerbos) {
      return PantallaSeleccion(
        verbos: datos.verbos,
        alConfirmar: _empezarQuiz,
      );
    }

    return PantallaQuiz(
      key: ValueKey(_generacionQuiz),
      verbos: _resolverVerbos(_verbosElegidos),
      tiempos: _tiemposElegidos ?? tiemposDisponibles,
      estado: _estado,
    );
  }
}

import 'package:flutter/material.dart';

import 'constantes.dart';
import 'datos/repositorio_verbos.dart';
import 'modelos/verbo.dart';
import 'pantallas/pantalla_articoli.dart';
import 'pantallas/pantalla_frases.dart';
import 'pantallas/pantalla_quiz.dart';
import 'pantallas/pantalla_seleccion.dart';
import 'tema.dart';
import 'widgets/barra_superior.dart';

void main() {
  runApp(const TukylianoApp());
}

class TukylianoApp extends StatelessWidget {
  const TukylianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tukyliano',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Tema.fondo),
      home: const PantallaPrincipal(),
    );
  }
}

/// Contenedor con la barra de navegación fija arriba y la sección elegida
/// debajo. Equivale al ScreenManager de la app Kivy.
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final RepositorioVerbos _repositorio = RepositorioVerbos();

  Seccion _seccion = Seccion.verbos;
  DatosVerbos? _datos;
  String _estado = '';

  /// La sección Verbos alterna entre el quiz y la pantalla de selección.
  bool _eligiendoVerbos = false;

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

  /// Los verbos con los que se practica: la selección del usuario, o todos.
  List<Verbo> get _verbosParaPracticar {
    final todos = _datos?.verbos ?? {};
    final elegidos = _verbosElegidos;
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
        return const PantallaFrases();
      case Seccion.verbos:
        return _seccionVerbos();
    }
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
      verbos: _verbosParaPracticar,
      tiempos: _tiemposElegidos ?? tiemposDisponibles,
      estado: _estado,
    );
  }
}

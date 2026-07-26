import 'package:flutter/material.dart';

import 'datos/repositorio_verbos.dart';
import 'modelos/verbo.dart';
import 'pantallas/pantalla_articoli.dart';
import 'pantallas/pantalla_frases.dart';
import 'pantallas/pantalla_verbos.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              BarraSuperior(
                onSeccion: (seccion) => setState(() => _seccion = seccion),
              ),
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
        return PantallaVerbos(datos: _datos, estado: _estado);
    }
  }
}

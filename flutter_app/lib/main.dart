import 'package:flutter/material.dart';

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
  Seccion _seccion = Seccion.verbos;

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
        return const PantallaVerbos();
    }
  }
}

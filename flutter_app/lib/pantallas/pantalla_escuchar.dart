import 'package:flutter/material.dart';

import '../datos/reproductor.dart';
import '../widgets/pastilla.dart';
import 'pantalla_favole.dart';
import 'pantalla_podcast.dart';

/// Las dos cosas que se escuchan, una al lado de la otra.
///
/// **Podcast**: episodios escritos y grabados para la app, en italiano fácil
/// y pensados para quien recién empieza.
///
/// **Favole**: las fábulas de La Fontaine leídas por voluntarios de
/// LibriVox. Italiano de verdad, no simplificado, pero en pedazos de uno a
/// tres minutos y con historias que uno ya conoce.
///
/// Van juntas y no en dos secciones del inicio porque son la misma cosa
/// —escuchar italiano— con dos escalones distintos. Y porque el inicio ya
/// tiene cuatro botones y dos barras: una tercera lo convertiría en una
/// lista.
class PantallaEscuchar extends StatefulWidget {
  const PantallaEscuchar({super.key, this.reproductor, this.empezarEnFavole = false});

  final Reproductor? reproductor;

  /// Para los tests, y para cuando haya que entrar derecho a las fábulas.
  final bool empezarEnFavole;

  @override
  State<PantallaEscuchar> createState() => _PantallaEscucharState();
}

class _PantallaEscucharState extends State<PantallaEscuchar> {
  late bool _enFavole = widget.empezarEnFavole;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Pastilla(
              texto: 'Podcast',
              activa: !_enFavole,
              alTocar: () => setState(() => _enFavole = false),
            ),
            const SizedBox(width: 8),
            Pastilla(
              texto: 'Favole',
              activa: _enFavole,
              alTocar: () => setState(() => _enFavole = true),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          // Con key para que al cambiar de pastilla cada pantalla se arme de
          // nuevo en vez de quedarse con el estado de la otra.
          child: _enFavole
              ? PantallaFavole(
                  key: const ValueKey('favole'),
                  reproductor: widget.reproductor,
                )
              : PantallaPodcast(
                  key: const ValueKey('podcast'),
                  reproductor: widget.reproductor,
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../datos/reproductor.dart';
import '../datos/repositorio_lecturas.dart';
import '../widgets/pastilla.dart';
import 'pantalla_lecturas.dart';
import 'pantalla_podcast.dart';

/// Las tres cosas que se escuchan, una al lado de la otra.
///
/// **Podcast**: episodios escritos y grabados para la app, en italiano fácil
/// y pensados para quien recién empieza.
///
/// **Favole**: las fábulas de La Fontaine leídas por voluntarios de
/// LibriVox. Pedazos de uno a tres minutos, con historias que uno ya
/// conoce.
///
/// **Pinocchio**: treinta y seis capítulos de ocho minutos. Es el escalón
/// que sigue, y —aunque suene al revés— es **más fácil** que las fábulas:
/// La Fontaine es verso del siglo XIX, con la palabra cortada para que
/// entre en el metro y el orden dado vuelta. Pinocchio es prosa para
/// chicos.
///
/// Van juntas y no en tres secciones del inicio porque son la misma cosa
/// —escuchar italiano— con tres escalones distintos. Y porque el inicio ya
/// tiene cuatro botones y dos barras: una tercera lo convertiría en una
/// lista.
enum QueSeEscucha {
  podcast('Podcast'),
  favole('Favole', archivo: 'assets/favole.json', clave: 'favole'),
  pinocchio('Pinocchio',
      archivo: 'assets/pinocchio.json', clave: 'capitulos');

  const QueSeEscucha(this.nombre, {this.archivo = '', this.clave = ''});

  /// Lo que dice la pastilla.
  final String nombre;

  /// De qué catálogo sale, para las que son lecturas. El podcast no usa
  /// ninguno: sus episodios vienen de otro lado.
  final String archivo;
  final String clave;

  bool get esLectura => archivo.isNotEmpty;
}

class PantallaEscuchar extends StatefulWidget {
  const PantallaEscuchar({
    super.key,
    this.reproductor,
    this.empezarEn = QueSeEscucha.podcast,
  });

  final Reproductor? reproductor;

  /// Para los tests, y para cuando haya que entrar derecho a una.
  final QueSeEscucha empezarEn;

  @override
  State<PantallaEscuchar> createState() => _PantallaEscucharState();
}

class _PantallaEscucharState extends State<PantallaEscuchar> {
  late QueSeEscucha _cual = widget.empezarEn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        // Las tres entran en el ancho de un celular, pero apenas: con un
        // nombre más largo o una pantalla más angosta se desbordan, y por
        // eso se deja correr de costado en vez de apretarlas.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cual in QueSeEscucha.values) ...[
                Pastilla(
                  texto: cual.nombre,
                  activa: _cual == cual,
                  alTocar: () => setState(() => _cual = cual),
                ),
                if (cual != QueSeEscucha.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          // Con key para que al cambiar de pastilla cada pantalla se arme de
          // nuevo en vez de quedarse con el estado de la otra.
          child: _cual.esLectura
              ? PantallaLecturas(
                  key: ValueKey(_cual.name),
                  repositorio: RepositorioLecturas(
                    archivo: _cual.archivo,
                    clave: _cual.clave,
                  ),
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

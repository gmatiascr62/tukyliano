import 'package:flutter/material.dart';

import '../datos/almacenamiento_clave.dart';
import '../datos/repositorio_charlas.dart';
import '../datos/voz.dart';
import '../ia/gemini.dart';
import '../widgets/pastilla.dart';
import 'pantalla_chat.dart';
import 'pantalla_charla.dart';

/// Las dos formas de charlar, una al lado de la otra.
///
/// **Al bar** es guionada: anda siempre, sin internet y sin clave, y corrige
/// sin equivocarse nunca porque la frase correcta está escrita en el guion. No
/// improvisa: se habla de lo que la escena trae.
///
/// **Libre** es con la IA: se habla de cualquier cosa, pero necesita internet,
/// necesita clave y de vez en cuando corrige mal.
///
/// Están juntas y no en dos secciones distintas porque son la misma cosa
/// —practicar escribiendo— con dos techos distintos. Y porque antes, sin
/// clave, esta sección no existía: se abría, pedía una clave y ahí terminaba.
class PantallaConversacion extends StatefulWidget {
  const PantallaConversacion({
    super.key,
    this.almacenClave,
    this.gemini,
    this.voz,
    this.charlas,
    this.empezarEnLibre = false,
  });

  final AlmacenamientoClave? almacenClave;
  final Gemini? gemini;
  final Voz? voz;
  final RepositorioCharlas? charlas;

  /// Para los tests que quieren la charla con IA sin tener que tocar nada.
  final bool empezarEnLibre;

  @override
  State<PantallaConversacion> createState() => _PantallaConversacionState();
}

class _PantallaConversacionState extends State<PantallaConversacion> {
  late bool _libre = widget.empezarEnLibre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Row(
          children: [
            Pastilla(
              texto: 'Al bar',
              activa: !_libre,
              alTocar: () => setState(() => _libre = false),
            ),
            const SizedBox(width: 8),
            Pastilla(
              texto: 'Libre',
              activa: _libre,
              alTocar: () => setState(() => _libre = true),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          // Con key para que al cambiar de pastilla cada pantalla se arme de
          // nuevo en vez de reusar el estado de la otra.
          child: _libre
              ? PantallaChat(
                  key: const ValueKey('libre'),
                  almacenClave: widget.almacenClave,
                  gemini: widget.gemini,
                  voz: widget.voz,
                )
              : PantallaCharla(
                  key: const ValueKey('bar'),
                  repositorio: widget.charlas,
                  voz: widget.voz,
                ),
        ),
      ],
    );
  }
}

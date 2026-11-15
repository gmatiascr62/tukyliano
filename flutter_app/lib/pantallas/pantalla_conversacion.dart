import 'package:flutter/material.dart';

import '../datos/quien_soy.dart';
import '../datos/repositorio_charlas.dart';
import '../datos/repositorio_diccionario.dart';
import '../datos/voz.dart';
import '../ia/servidor.dart';
import '../widgets/pastilla.dart';
import 'pantalla_chat.dart';
import 'pantalla_charla.dart';

/// Las dos formas de charlar, una al lado de la otra.
///
/// **Al bar** es guionada: anda siempre, sin internet y sin clave, y corrige
/// sin equivocarse nunca porque la frase correcta está escrita en el guion. No
/// improvisa: se habla de lo que la escena trae.
///
/// **Libre** es con la IA: se habla de cualquier cosa, pero necesita internet
/// y de vez en cuando corrige mal. Clave ya no necesita: habla con el
/// servidor propio, que es el que tiene el modelo del otro lado.
///
/// Están juntas y no en dos secciones distintas porque son la misma cosa
/// —practicar escribiendo— con dos techos distintos.
class PantallaConversacion extends StatefulWidget {
  const PantallaConversacion({
    super.key,
    this.servidor,
    this.quienSoy,
    this.voz,
    this.charlas,
    this.diccionario,
    this.empezarEnLibre = false,
  });

  final Servidor? servidor;
  final QuienSoy? quienSoy;
  final Voz? voz;
  final RepositorioCharlas? charlas;
  final RepositorioDiccionario? diccionario;

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
                  servidor: widget.servidor,
                  quienSoy: widget.quienSoy,
                  voz: widget.voz,
                  diccionario: widget.diccionario,
                )
              : PantallaCharla(
                  key: const ValueKey('bar'),
                  repositorio: widget.charlas,
                  voz: widget.voz,
                  diccionario: widget.diccionario,
                ),
        ),
      ],
    );
  }
}

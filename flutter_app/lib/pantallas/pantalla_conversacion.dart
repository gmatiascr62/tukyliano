import 'package:flutter/material.dart';

import '../datos/quien_soy.dart';
import '../datos/repositorio_diccionario.dart';
import '../datos/voz.dart';
import '../ia/chat.dart';
import '../ia/servidor.dart';
import '../widgets/pastilla.dart';
import 'pantalla_chat.dart';

/// Las dos formas de charlar, una al lado de la otra.
///
/// **Al bar** es una escena: estás en un bar en Italia, pedís, te sirven, te
/// cobran y te saludás. Tiene principio y final, y cuando termina se puede
/// empezar otra.
///
/// **Libre** es una charla sin escena: se habla de cualquier cosa y no se
/// termina nunca.
///
/// Las dos las contesta el mismo modelo y la misma pantalla. Lo único que
/// cambia es qué escena se le manda al servidor, que con eso elige las
/// instrucciones. Por eso agregar la farmacia o la estación es agregar un
/// prompt del lado del servidor: acá sería una pastilla más y nada más.
///
/// Antes, "Al bar" era una charla guionada que vivía adentro de la app: un
/// árbol de respuestas escritas a mano. Tenía dos cosas que esto no tiene
/// —andaba sin internet y no podía corregir mal, porque la frase correcta
/// estaba escrita al lado— y una que la mataba: era siempre la misma, y se
/// terminaba la segunda vez que la hacías.
class PantallaConversacion extends StatefulWidget {
  const PantallaConversacion({
    super.key,
    this.servidor,
    this.quienSoy,
    this.voz,
    this.diccionario,
    this.empezarEnLibre = false,
  });

  final Servidor? servidor;
  final QuienSoy? quienSoy;
  final Voz? voz;
  final RepositorioDiccionario? diccionario;

  /// Para los tests que quieren la charla libre sin tener que tocar nada.
  final bool empezarEnLibre;

  @override
  State<PantallaConversacion> createState() => _PantallaConversacionState();
}

class _PantallaConversacionState extends State<PantallaConversacion> {
  late Escena _escena = widget.empezarEnLibre ? Escena.libre : Escena.bar;

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
              activa: _escena == Escena.bar,
              alTocar: () => setState(() => _escena = Escena.bar),
            ),
            const SizedBox(width: 8),
            Pastilla(
              texto: 'Libre',
              activa: _escena == Escena.libre,
              alTocar: () => setState(() => _escena = Escena.libre),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          // Con key para que al cambiar de pastilla la pantalla se arme de
          // nuevo en vez de seguir la charla de la otra escena.
          child: PantallaChat(
            key: ValueKey(_escena),
            escena: _escena,
            servidor: widget.servidor,
            quienSoy: widget.quienSoy,
            voz: widget.voz,
            diccionario: widget.diccionario,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/almacenamiento_clave.dart';
import '../datos/voz.dart';
import '../ia/chat.dart';
import '../ia/gemini.dart';
import '../logica/seleccion_azar.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
import '../widgets/pastilla.dart';
import '../widgets/selector_de_voz.dart';
import '../widgets/teclado.dart';
import 'pantalla_clave_ia.dart';

/// Charla en italiano con la IA.
///
/// Tres cosas la separan de las otras secciones:
///
/// - Se escribe con el teclado propio, igual que en el resto de la app: así
///   están a mano las vocales acentuadas, y se le suman la almohadilla y los
///   signos que hacen falta acá.
/// - Cualquier cosa entre almohadillas es un pedido de traducción, en los dos
///   sentidos: '#manteca#' contesta '#burro#' y '#finestra#' contesta
///   '#ventana#'. Si el mensaje es solo el pedido, la respuesta es solo la
///   traducción; si está en medio de una frase, la charla sigue.
/// - En "Solo escuchar" las respuestas no se leen: se escuchan. Es el modo
///   difícil, y para eso está el ojito por si una no se entendió.
///
/// La memoria dura lo que dura la visita: al cambiar de sección esta pantalla
/// se destruye y con ella la conversación, así que al volver la IA arranca de
/// cero. Es lo pedido, y además evita que la charla crezca sin límite (va toda
/// en cada pedido a la API).
class PantallaChat extends StatefulWidget {
  const PantallaChat({super.key, this.almacenClave, this.gemini, this.voz});

  /// Inyectables para los tests.
  final AlmacenamientoClave? almacenClave;
  final Gemini? gemini;
  final Voz? voz;

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  late final AlmacenamientoClave _almacen =
      widget.almacenClave ?? AlmacenamientoClave();
  late final Gemini _gemini = widget.gemini ?? Gemini();
  late final Voz _voz = widget.voz ?? VozDelSistema();

  final _conversacion = Conversacion();
  final _scroll = ScrollController();

  /// Los mensajes de la IA que están tapados, por su posición en la charla.
  /// Solo se tapan los que llegan con el modo prendido: prenderlo no borra de
  /// la pantalla lo que ya se leyó.
  final _tapados = <int>{};

  String? _clave;
  bool _buscandoClave = true;
  String _errorClave = '';

  String _escrito = '';
  bool _esperando = false;

  bool _puedeHablar = false;
  bool _soloEscuchar = false;
  bool _lenta = false;

  @override
  void initState() {
    super.initState();
    _arrancar();
    // Aparte de la clave: si el motor de voz del celular tarda en contestar, la
    // charla ya se puede usar igual, solo que sin audio hasta que conteste.
    _prepararVoz();
  }

  @override
  void dispose() {
    _voz.callar();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    final clave = await _almacen.cargar();
    if (!mounted) return;
    setState(() {
      _clave = clave;
      _buscandoClave = false;
    });
  }

  Future<void> _prepararVoz() async {
    final puedeHablar = await _voz.preparar();
    if (!mounted) return;
    setState(() => _puedeHablar = puedeHablar);
  }

  Future<void> _guardarClave(String clave) async {
    await _almacen.guardar(clave);
    if (!mounted) return;
    setState(() {
      _clave = clave;
      _errorClave = '';
    });
  }

  void _onTecla(String tecla) {
    setState(() => _escrito = aplicarTecla(_escrito, tecla));
  }

  bool get _puedeEnviar =>
      !_esperando && _escrito.trim().isNotEmpty && _clave != null;

  Future<void> _enviar() async {
    final texto = _escrito.trim();
    final clave = _clave;
    if (_esperando || texto.isEmpty || clave == null) return;

    setState(() {
      _conversacion.agregar(Mensaje.mia(texto));
      _escrito = '';
      _esperando = true;
    });
    _irAlFinal();

    try {
      final contestado = await _gemini.charlar(_conversacion.contenidos(), clave);
      if (!mounted) return;
      // Dos recortes, por si la IA no siguió las instrucciones: cuando el
      // mensaje era solo un pedido de traducción se muestra solo la traducción,
      // y en la charla no se muestra una corrección que repite lo que escribió.
      final respuesta = esSoloTraduccion(texto)
          ? soloLasTraducciones(contestado)
          : sinCorreccionRepetida(contestado, texto);
      setState(() {
        if (_soloEscuchar) _tapados.add(_conversacion.mensajes.length);
        _conversacion.agregar(Mensaje.deLaIa(respuesta));
        _esperando = false;
      });
      _irAlFinal();
      // Tapada hay que decirla sola: es la única forma de saber qué contestó.
      // Destapada se toca la burbuja, igual que un renglón de los cuentos.
      if (_soloEscuchar && _puedeHablar) _voz.decir(sinMarcas(respuesta));
    } on ClaveInvalidaError {
      // Una clave que no sirve no se guarda: se borra y se pide de nuevo.
      await _almacen.borrar();
      if (!mounted) return;
      setState(() {
        _clave = null;
        _esperando = false;
        _errorClave = 'La clave no funcionó. Pegá una nueva.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conversacion.agregar(Mensaje.aviso(_explicar(error)));
        _esperando = false;
      });
      _irAlFinal();
    }
  }

  String _explicar(Object error) {
    if (error is CuotaAgotadaError) {
      return 'Se acabó la cuota gratis de la IA por ahora. Probá más tarde.';
    }
    if (error is TimeoutException) {
      return 'La IA tardó demasiado en contestar. Probá de nuevo.';
    }
    if (error is SinRespuestaError) {
      return 'La IA no contestó nada. Probá escribirlo de otra forma.';
    }
    return 'No se pudo hablar con la IA. Fijate si tenés internet.';
  }

  /// Deja la charla mostrando el último mensaje. Va después del frame porque
  /// hasta que no se dibuja no se sabe cuánto mide la lista.
  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _escuchar(String texto) {
    if (!_puedeHablar) return;
    _voz.decir(sinMarcas(texto));
  }

  Future<void> _cambiarVelocidad() async {
    final lenta = !_lenta;
    await _voz.usarVelocidadLenta(lenta);
    if (!mounted) return;
    setState(() => _lenta = lenta);
  }

  Future<void> _cambiarVoz(VozItaliana voz) async {
    await _voz.usarVoz(voz);
    if (!mounted) return;
    // Se dice el nombre para escuchar en el acto cómo suena la elegida.
    await _voz.decir(voz.nombre);
    if (!mounted) return;
    setState(() {});
  }

  /// Prender el modo tapa lo que venga; apagarlo destapa todo lo anterior, así
  /// se puede leer al final lo que no se entendió de oído.
  void _cambiarSoloEscuchar() {
    final solo = !_soloEscuchar;
    setState(() {
      _soloEscuchar = solo;
      if (!solo) _tapados.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_buscandoClave) {
      return const Center(
        child: Text(
          'Un momento...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_clave == null) {
      return PantallaClaveIA(onGuardar: _guardarClave, error: _errorClave);
    }

    final mensajes = _conversacion.mensajes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        _opciones(),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: mensajes.length + (_esperando ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == mensajes.length) return const _Escribiendo();
              return _Burbuja(
                mensaje: mensajes[i],
                tapada: _tapados.contains(i),
                alEscuchar: _puedeHablar
                    ? () => _escuchar(mensajes[i].texto)
                    : null,
                alDestapar: () => setState(() => _tapados.remove(i)),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          // Abajo: cuando el campo crece de renglones, el botón se queda
          // pegado al último, como en cualquier chat.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CampoTexto(
                texto: _escrito,
                placeholderTexto: 'Escribí en italiano...',
                multilinea: true,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              height: 62,
              child: ElevatedButton(
                onPressed: _puedeEnviar ? _enviar : null,
                style: Tema.botonPrincipal.copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                child: const Icon(Icons.send_rounded, size: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Las teclas extra son las de acá: sin la almohadilla no se podrían
        // pedir traducciones.
        Teclado(onTecla: _onTecla, teclasExtra: teclasDelChat),
      ],
    );
  }

  Widget _opciones() {
    final voces = _voz.voces;
    final elegida = _voz.vozElegida ?? (voces.isEmpty ? null : voces.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Se desliza, igual que la barra de secciones: con la letra grande del
        // celular las tres pastillas no siempre entran en una pantalla.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_puedeHablar) ...[
                Pastilla(
                  texto: 'Solo escuchar',
                  icono: Icons.hearing,
                  activa: _soloEscuchar,
                  alTocar: _cambiarSoloEscuchar,
                ),
                const SizedBox(width: 6),
                Pastilla(
                  texto: 'Lento',
                  icono: Icons.slow_motion_video,
                  activa: _lenta,
                  alTocar: _cambiarVelocidad,
                ),
                if (voces.length > 1 && elegida != null) ...[
                  const SizedBox(width: 6),
                  SelectorDeVoz(
                    voces: voces,
                    elegida: elegida,
                    alElegir: _cambiarVoz,
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _ayuda(),
          style: const TextStyle(
            fontSize: 12.5,
            height: 1.3,
            color: Tema.textoTenue,
          ),
        ),
      ],
    );
  }

  String _ayuda() {
    if (!_puedeHablar) {
      return 'Poné una palabra entre almohadillas y te la traduce: #manteca#. '
          'Para escuchar la charla, instalá la voz italiana en Ajustes → '
          'Idiomas → Texto a voz.';
    }
    if (_soloEscuchar) {
      return 'La IA habla y no muestra lo que dice. Tocá el ojito si no '
          'entendiste.';
    }
    return 'Tocá una respuesta para escucharla. Poné una palabra entre '
        'almohadillas y te la traduce: #manteca#';
  }
}

/// El cartel de que la IA está pensando. Ocupa el lugar de la respuesta que
/// falta, así se ve que el mensaje salió.
class _Escribiendo extends StatelessWidget {
  const _Escribiendo();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Text(
          'Tuky está escribiendo...',
          style: TextStyle(
            fontSize: 13.5,
            color: Tema.textoTenue,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// Un mensaje de la charla. Los míos van a la derecha en verde, los de la IA a
/// la izquierda en blanco, y los avisos de la app en el medio.
class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.mensaje,
    required this.tapada,
    required this.alDestapar,
    this.alEscuchar,
  });

  final Mensaje mensaje;

  /// True en el modo de solo escuchar: la burbuja no muestra el texto.
  final bool tapada;

  final VoidCallback alDestapar;

  /// Null cuando el celular no puede pronunciar italiano.
  final VoidCallback? alEscuchar;

  @override
  Widget build(BuildContext context) {
    if (mensaje.quien == Quien.aviso) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          mensaje.texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.3,
            color: Tema.incorrecto,
          ),
        ),
      );
    }

    final mio = mensaje.quien == Quien.yo;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 300),
        child: Material(
          color: mio ? Tema.verde : Tema.superficie,
          borderRadius: BorderRadius.circular(Tema.radio),
          child: InkWell(
            // Tocar la burbuja de la IA la pronuncia, igual que un renglón de
            // los cuentos. La mía no: ya sé lo que escribí.
            onTap: mio ? null : alEscuchar,
            borderRadius: BorderRadius.circular(Tema.radio),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Tema.radio),
                border: Border.all(color: mio ? Tema.verde : Tema.borde),
              ),
              child: tapada ? _tapada() : _texto(mio),
            ),
          ),
        ),
      ),
    );
  }

  /// La burbuja del modo difícil: se escuchó y no se ve. El ojito la destapa,
  /// para no quedar trabado cuando una frase no se entiende.
  Widget _tapada() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.volume_up_outlined, size: 19, color: Tema.verde),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            'Tocá para repetir',
            style: TextStyle(fontSize: 14, color: Tema.textoTenue),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: alDestapar,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.visibility_outlined,
              size: 19,
              color: Tema.verdeOscuro,
            ),
          ),
        ),
      ],
    );
  }

  /// El texto del mensaje, con lo que está entre almohadillas resaltado: eso es
  /// una traducción y no parte de la charla.
  Widget _texto(bool mio) {
    final trozos = partirPorMarcas(mensaje.texto);
    final base = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: mio ? Colors.white : Tema.texto,
    );

    // Text.rich y no RichText: así el texto sigue siendo un Text común para
    // el resto de la app (y para los tests, que lo buscan por su contenido).
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final trozo in trozos)
            TextSpan(
              text: trozo.texto,
              style: trozo.marcada
                  ? base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mio ? Colors.white : Tema.verdeOscuro,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

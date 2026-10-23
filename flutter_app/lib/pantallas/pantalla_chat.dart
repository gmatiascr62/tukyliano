import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/descarga_modelo.dart';
import '../datos/intento_de_carga.dart';
import '../datos/voz.dart';
import '../ia/chat.dart';
import '../ia/italiano_o_no.dart';
import '../ia/motor_ia.dart';
import '../ia/motor_llama.dart';
import '../logica/capacidad.dart';
import '../logica/reglas_italiano.dart';
import '../tema.dart';
import '../widgets/pastilla.dart';
import '../widgets/selector_de_voz.dart';
import 'pantalla_modelo.dart';

/// Charla en italiano con la IA, que corre adentro del celular.
///
/// Antes esto hablaba con Gemini por internet y hacía falta una clave. Ahora el
/// modelo es un archivo en la carpeta privada de la app y las cuentas las hace
/// el procesador del teléfono: sin clave, sin cuota, sin internet y sin que
/// nada de lo que se escriba salga del aparato.
///
/// Lo que cambia por eso:
///
/// - La primera vez hay que bajar el modelo ([PantallaModelo]).
/// - La respuesta llega de a pedacitos, como la va escribiendo, porque tarda
///   varios segundos y mostrarla al final parecería que se colgó.
/// - Hay un botón para cortarla a la mitad.
/// - Al salir de la sección el modelo se descarga de la memoria: son cientos de
///   megas y Android mata la app si los deja ocupados.
///
/// Lo que no cambia: el diseño, las burbujas, las traducciones entre
/// almohadillas, el modo de solo escuchar y el botón de otro tema.
class PantallaChat extends StatefulWidget {
  const PantallaChat({
    super.key,
    this.descarga,
    this.intento,
    this.motor,
    this.voz,
    this.capacidad,
    this.azar,
  });

  /// Inyectables para los tests.
  final DescargaModelo? descarga;

  /// El que se acuerda de si la app se cerró cargando el modelo.
  final IntentoDeCarga? intento;

  /// El motor de IA. Null = el de verdad, con el modelo que se bajó.
  final MotorIA? motor;

  final Voz? voz;
  final Capacidad? capacidad;

  /// Para que los tests sepan con qué saludo va a arrancar la charla.
  final Random? azar;

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  late final DescargaModelo _descarga = widget.descarga ?? DescargaModelo();
  late final IntentoDeCarga _intento = widget.intento ?? IntentoDeCarga();
  late final Voz _voz = widget.voz ?? VozDelSistema();

  late Conversacion _conversacion = Conversacion(azar: widget.azar);
  final _scroll = ScrollController();
  final _campo = TextEditingController();

  /// Los mensajes de la IA que están tapados, por su posición en la charla.
  final _tapados = <int>{};

  MotorIA? _motor;
  StreamSubscription<String>? _escribiendo;

  /// Lo que la IA lleva escrito de la respuesta que está generando.
  String _parcial = '';

  bool _mirandoElModelo = true;
  bool _cargandoElModelo = false;

  /// True cuando la vez pasada la app se cerró cargando el modelo. No se
  /// vuelve a intentar sin que lo pidan.
  bool _seCerroLaVezPasada = false;
  String _problema = '';
  bool _esperando = false;

  bool _puedeHablar = false;
  bool _soloEscuchar = false;
  bool _lenta = false;

  @override
  void initState() {
    super.initState();
    _arrancar();
    _prepararVoz();
  }

  @override
  void dispose() {
    _voz.callar();
    _escribiendo?.cancel();
    // Lo más importante de esta pantalla: soltar los megas del modelo.
    _motor?.liberar();
    _scroll.dispose();
    _campo.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    // En los tests se inyecta un motor y no hay nada que bajar.
    if (widget.motor != null) {
      await _cargarElMotor(widget.motor!);
      return;
    }

    final ruta = await _descarga.rutaSiEsta();
    if (!mounted) return;
    if (ruta == null) {
      setState(() => _mirandoElModelo = false);
      return;
    }
    await _conElModeloBajado(ruta);
  }

  Future<void> _conElModeloBajado(String ruta) async {
    if (!mounted) return;
    setState(() {
      _mirandoElModelo = false;
      _cargandoElModelo = true;
      _problema = '';
    });
    await _cargarElMotor(MotorLlama(rutaDelModelo: ruta));
  }

  Future<void> _cargarElMotor(MotorIA motor, {bool igual = false}) async {
    // Si la vez pasada el celular se cerró cargando el modelo, no se vuelve a
    // probar solo: se cuenta lo que pasó y se deja decidir.
    if (!igual && await _intento.seCerroLaVezPasada()) {
      if (!mounted) return;
      setState(() {
        _motor = null;
        _seCerroLaVezPasada = true;
        _mirandoElModelo = false;
        _cargandoElModelo = false;
      });
      return;
    }

    await _intento.empiezo();
    final anduvo = await motor.preparar();
    await _intento.salioBien();
    if (!mounted) return;
    setState(() {
      _motor = anduvo ? motor : null;
      _mirandoElModelo = false;
      _cargandoElModelo = false;
      _problema = anduvo ? '' : motor.problema;
    });
  }

  Future<void> _prepararVoz() async {
    final puedeHablar = await _voz.preparar();
    if (!mounted) return;
    setState(() => _puedeHablar = puedeHablar);
  }

  bool get _puedeEnviar =>
      !_esperando && _campo.text.trim().isNotEmpty && _motor != null;

  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    final motor = _motor;
    if (_esperando || texto.isEmpty || motor == null) return;
    _vecesQueContestoEnCastellano = 0;

    final soloTraducir = esSoloTraduccion(texto);
    final pedidos = pedidosDeTraduccion(texto);

    setState(() {
      _conversacion.agregar(Mensaje.mia(texto));
      _campo.clear();
      _esperando = true;
      _parcial = '';
    });
    _irAlFinal();

    // Un pedido de traducción no es una charla: va por su propio prompt, que
    // es corto y con ejemplos. Es lo que hace que un modelo chico conteste la
    // palabra y nada más.
    final prompt = soloTraducir
        ? promptDeLaTraduccion(pedidos.first)
        : _conversacion.prompt();

    _escribiendo = motor.responder(prompt).listen(
      (pedazo) {
        if (!mounted) return;
        setState(() => _parcial += pedazo);
        _irAlFinal();
      },
      onError: (Object error) => _terminar(crudo: '', error: error),
      onDone: () => _terminar(
        crudo: _parcial,
        soloTraducir: soloTraducir,
        pedido: pedidos.isEmpty ? '' : pedidos.first,
        escrito: texto,
      ),
    );
  }

  /// Cierra la respuesta: la limpia, la guarda en la charla y la lee si hace
  /// falta.
  void _terminar({
    required String crudo,
    Object? error,
    bool soloTraducir = false,
    String pedido = '',
    String escrito = '',
  }) {
    if (!mounted) return;
    _escribiendo = null;

    if (error != null) {
      setState(() {
        _conversacion.agregar(Mensaje.aviso(_explicar(error)));
        _esperando = false;
        _parcial = '';
      });
      _irAlFinal();
      return;
    }

    var respuesta = limpiarRespuesta(crudo);
    if (soloTraducir) {
      respuesta = '$marcaTraduccion$pedido$marcaTraduccion = '
          '$marcaTraduccion${_unaPalabra(respuesta)}$marcaTraduccion';
    } else {
      respuesta = sinCorreccionesDelModelo(respuesta);
      respuesta = _conLaCorreccionDeLasReglas(respuesta, escrito);
    }

    // En castellano no sirve: el chat es para practicar italiano. Se le pide
    // otra vez, que es lo que haría cualquiera, y recién si insiste se avisa.
    if (!soloTraducir && contestoEnCastellano(respuesta)) {
      if (_vecesQueContestoEnCastellano < 1) {
        _vecesQueContestoEnCastellano++;
        _pedirDeNuevo(escrito);
        return;
      }
      setState(() {
        _conversacion.agregar(const Mensaje.aviso(
          'Tuky contestó en castellano. Probá de escribirle otra cosa.',
        ));
        _esperando = false;
        _parcial = '';
      });
      _irAlFinal();
      return;
    }

    if (respuesta.isEmpty) {
      setState(() {
        _conversacion.agregar(
          const Mensaje.aviso('La IA no contestó nada. Probá de nuevo.'),
        );
        _esperando = false;
        _parcial = '';
      });
      _irAlFinal();
      return;
    }

    setState(() {
      if (_soloEscuchar) _tapados.add(_conversacion.mensajes.length);
      _conversacion.agregar(Mensaje.deLaIa(respuesta));
      _esperando = false;
      _parcial = '';
    });
    _irAlFinal();
    if (_soloEscuchar && _puedeHablar) _voz.decir(sinMarcas(respuesta));
  }

  /// Vuelve a pedirle la respuesta, sin agregar nada a la charla.
  ///
  /// Lo que ya se escribió se descarta: la charla queda igual que antes de
  /// pedir, así que el modelo no ve su propia respuesta en castellano y no se
  /// agarra de ella para la siguiente.
  void _pedirDeNuevo(String escrito) {
    final motor = _motor;
    if (motor == null) return;
    setState(() => _parcial = '');
    _escribiendo = motor.responder(_conversacion.prompt()).listen(
          (pedazo) {
            if (!mounted) return;
            setState(() => _parcial += pedazo);
            _irAlFinal();
          },
          onError: (Object error) => _terminar(crudo: '', error: error),
          onDone: () => _terminar(crudo: _parcial, escrito: escrito),
        );
  }

  /// La corrección, que sale de las reglas y no del modelo.
  ///
  /// Es la única que se muestra: las del modelo se sacaron un renglón antes,
  /// porque inventa correcciones de frases que están bien.
  String _conLaCorreccionDeLasReglas(String respuesta, String escrito) {
    final errores = revisarItaliano(escrito);
    if (errores.isEmpty) return respuesta;

    return 'Correzione: ${italianoCorregido(escrito)}\n$respuesta';
  }

  /// La primera palabra de lo que contestó.
  ///
  /// Para una traducción alcanza con eso, y evita que un "burro, que significa
  /// manteca en italiano" se muestre entero adentro de las almohadillas.
  String _unaPalabra(String texto) {
    final limpio = texto.replaceAll(RegExp(r'^[\s"“”.:-]+'), '').trim();
    final corte = limpio.indexOf(RegExp(r'[\n.,;!?]'));
    final primera = corte > 0 ? limpio.substring(0, corte) : limpio;
    return primera.trim().isEmpty ? texto.trim() : primera.trim();
  }

  String _explicar(Object error) {
    if (error is ProblemaDelMotor) return error.mensaje;
    if (error is TimeoutException) {
      return 'La IA tardó demasiado. Probá con un mensaje más corto.';
    }
    return 'La IA no pudo contestar. Probá de nuevo.';
  }

  /// Corta la respuesta a mitad de camino y se queda con lo que llegó.
  /// Cuántas veces seguidas contestó en castellano en este pedido.
  int _vecesQueContestoEnCastellano = 0;

  Future<void> _cortar() async {
    final motor = _motor;
    if (motor == null || !_esperando) return;
    await motor.cortar();
    await _escribiendo?.cancel();
    _escribiendo = null;
    _terminar(crudo: _parcial, escrito: '');
  }

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
    await _voz.decir(voz.nombre);
    if (!mounted) return;
    setState(() {});
  }

  void _cambiarSoloEscuchar() {
    final solo = !_soloEscuchar;
    setState(() {
      _soloEscuchar = solo;
      if (!solo) _tapados.clear();
    });
  }

  /// Empieza una charla nueva, con otro saludo y por lo tanto con otro tema.
  void _otroTema() {
    _voz.callar();
    setState(() {
      _conversacion = Conversacion(
        saludo: saludoAlAzar(distintoDe: _conversacion.saludo, azar: widget.azar),
      );
      _tapados.clear();
      _campo.clear();
      _parcial = '';
    });
    _irAlFinal();
  }

  @override
  Widget build(BuildContext context) {
    if (_mirandoElModelo) {
      return const Center(
        child: Text(
          'Un momento...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    if (_seCerroLaVezPasada) return _seCerro();

    if (_motor == null && _problema.isEmpty) {
      return PantallaModelo(
        descarga: _descarga,
        capacidad: widget.capacidad,
        alTerminar: _conElModeloBajado,
      );
    }

    if (_cargandoElModelo) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Tema.verde),
              ),
            ),
            SizedBox(height: 14),
            Text(
              'Preparando la IA...',
              style: TextStyle(fontSize: 15, color: Tema.textoTenue),
            ),
          ],
        ),
      );
    }

    if (_motor == null) return _noSePudo();

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
              if (i == mensajes.length) return _Escribiendo(texto: _parcial);
              return _Burbuja(
                mensaje: mensajes[i],
                tapada: _tapados.contains(i),
                alEscuchar:
                    _puedeHablar ? () => _escuchar(mensajes[i].texto) : null,
                alDestapar: () => setState(() => _tapados.remove(i)),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _campoDeTexto()),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              height: 62,
              child: ElevatedButton(
                // Mientras contesta, el mismo botón corta: es el lugar donde ya
                // está el dedo.
                onPressed: _esperando
                    ? _cortar
                    : _puedeEnviar
                        ? _enviar
                        : null,
                style: Tema.botonPrincipal.copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                child: Icon(
                  _esperando ? Icons.stop_rounded : Icons.send_rounded,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Cuando la vez pasada la app se cerró sola cargando el modelo.
  ///
  /// Lo que se puede hacer es poco, pero es mejor que volver a cerrarse: se
  /// cuenta qué pasó, se deja probar igual por si fue casualidad, y se deja
  /// borrar el modelo para recuperar los megas.
  Widget _seCerro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 48, color: Tema.borde),
            const SizedBox(height: 14),
            const Text(
              'La vez pasada la app se cerró al abrir el chat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Tema.titulo,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'La IA no pudo arrancar en este celular. El resto de la app '
              'funciona igual.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.35, color: Tema.texto),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  await _intento.salioBien();
                  if (!mounted) return;
                  setState(() {
                    _seCerroLaVezPasada = false;
                    _cargandoElModelo = true;
                  });
                  final ruta = await _descarga.rutaSiEsta();
                  if (!mounted || ruta == null) return;
                  await _cargarElMotor(
                    widget.motor ?? MotorLlama(rutaDelModelo: ruta),
                    igual: true,
                  );
                },
                style: Tema.botonPrincipal,
                child: const Text(
                  'Probar igual',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () async {
                await _descarga.borrar();
                await _intento.salioBien();
                if (!mounted) return;
                setState(() {
                  _seCerroLaVezPasada = false;
                  _problema = '';
                });
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Borrar la IA y recuperar los MB'),
              style: TextButton.styleFrom(foregroundColor: Tema.textoTenue),
            ),
          ],
        ),
      ),
    );
  }

  /// Cuando el modelo no se pudo cargar. No es una pantalla de error pelada:
  /// deja borrar lo bajado y probar de nuevo, que es lo único que puede ayudar.
  Widget _noSePudo() {
    // Con scroll: un error largo tapaba el botón de abajo y dejaba a la
    // persona con un cartel que no se podía ni terminar de leer.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied, size: 48, color: Tema.borde),
            const SizedBox(height: 14),
            Text(
              _problema,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.35, color: Tema.texto),
            ),
            const SizedBox(height: 8),
            const Text(
              'El resto de la app funciona igual.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Tema.textoTenue),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () async {
                await _descarga.borrar();
                if (!mounted) return;
                setState(() {
                  _problema = '';
                  _mirandoElModelo = false;
                });
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Borrar la IA y bajarla de nuevo'),
              style: TextButton.styleFrom(foregroundColor: Tema.verde),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoDeTexto() {
    return Container(
      constraints: const BoxConstraints(minHeight: 62, maxHeight: 108),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(color: Tema.borde, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _campo,
        onChanged: (_) => setState(() {}),
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        autocorrect: true,
        enableSuggestions: true,
        style: const TextStyle(
          fontSize: 17,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Tema.texto,
        ),
        cursorColor: Tema.verde,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Escribí en italiano...',
          hintStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Tema.textoTenue,
          ),
        ),
      ),
    );
  }

  Widget _opciones() {
    final voces = _voz.voces;
    final elegida = _voz.vozElegida ?? (voces.isEmpty ? null : voces.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Pastilla(
                texto: 'Otro tema',
                icono: Icons.autorenew,
                alTocar: _esperando ? null : _otroTema,
              ),
              const SizedBox(width: 6),
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

/// El cartel de que la IA está pensando, con lo que lleva escrito.
///
/// Con el modelo adentro del celular esto no es un adorno: tarda varios
/// segundos y ver aparecer las palabras es la diferencia entre "está pensando"
/// y "se colgó".
class _Escribiendo extends StatelessWidget {
  const _Escribiendo({this.texto = ''});

  final String texto;

  @override
  Widget build(BuildContext context) {
    if (texto.trim().isEmpty) {
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Tema.superficie,
          borderRadius: BorderRadius.circular(Tema.radio),
          border: Border.all(color: Tema.borde),
        ),
        child: Text(
          limpiarRespuesta(texto),
          style: const TextStyle(fontSize: 16, height: 1.35, color: Tema.texto),
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
  final bool tapada;
  final VoidCallback alDestapar;
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

  Widget _texto(bool mio) {
    final trozos = partirPorMarcas(mensaje.texto);
    final base = TextStyle(
      fontSize: 16,
      height: 1.35,
      color: mio ? Colors.white : Tema.texto,
    );

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

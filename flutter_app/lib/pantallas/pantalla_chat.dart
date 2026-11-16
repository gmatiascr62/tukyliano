import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/buscador_de_palabras.dart';
import '../datos/quien_soy.dart';
import '../datos/repositorio_diccionario.dart';
import '../datos/voz.dart';
import '../ia/chat.dart';
import '../ia/servidor.dart';
import '../modelos/diccionario.dart';
import '../tema.dart';
import '../widgets/pastilla.dart';
import '../widgets/selector_de_voz.dart';

/// Charla en italiano con la IA.
///
/// Sirve para las dos escenas: la charla libre con Tuky y el bar. Lo único
/// que cambia entre una y otra es con qué saludo arranca, qué se le manda al
/// servidor —que con eso elige el prompt— y que el bar puede terminar. Todo
/// lo demás —el diccionario, el solo escuchar, las voces— es igual, y por eso
/// es una sola pantalla y no dos.
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
  const PantallaChat({
    super.key,
    this.escena = Escena.libre,
    this.servidor,
    this.quienSoy,
    this.buscador,
    this.voz,
    this.diccionario,
    this.azar,
  });

  /// De qué charla se trata.
  final Escena escena;

  /// Inyectables para los tests.
  final Servidor? servidor;
  final QuienSoy? quienSoy;

  /// Quién busca las palabras que el diccionario no tiene. Uno de mentira
  /// deja probar la pantalla sin salir a internet.
  final BuscadorDePalabras? buscador;
  final Voz? voz;
  final RepositorioDiccionario? diccionario;

  /// Para que los tests sepan con qué saludo va a arrancar la charla.
  final Random? azar;

  @override
  State<PantallaChat> createState() => _PantallaChatState();
}

class _PantallaChatState extends State<PantallaChat> {
  late final Servidor _servidor = widget.servidor ?? Servidor();
  late final QuienSoy _quienSoy = widget.quienSoy ?? QuienSoy();

  /// El que busca las palabras: primero el diccionario de la app, después el
  /// servidor. Comparte el mismo cliente que la charla, así una sola falla de
  /// red se ve igual en los dos lados.
  late final BuscadorDePalabras _buscador = widget.buscador ??
      BuscadorDePalabras(servidor: _servidor, quienSoy: _quienSoy);
  late final Voz _voz = widget.voz ?? VozDelSistema();

  late Conversacion _conversacion =
      Conversacion(escena: widget.escena, azar: widget.azar);
  final _scroll = ScrollController();

  /// El chat escribe con el teclado de Android y no con el propio de la app:
  /// acá se escriben frases enteras y el corrector del celular ayuda de
  /// verdad. En los ejercicios sigue el teclado propio, donde corregir
  /// automáticamente arruinaría la consigna.
  final _campo = TextEditingController();

  /// Los mensajes de la IA que están tapados, por su posición en la charla.
  /// Solo se tapan los que llegan con el modo prendido: prenderlo no borra de
  /// la pantalla lo que ya se leyó.
  final _tapados = <int>{};

  late final RepositorioDiccionario _diccionario =
      widget.diccionario ?? RepositorioDiccionario();
  Diccionario _elDiccionario = const Diccionario();

  /// El número de este celular, para que el servidor reparta los topes.
  String _quien = '';

  bool _esperando = false;

  /// True cuando el barista cerró la escena. Ahí no se escribe más: lo que
  /// sigue es empezar otra. Dejar el campo abierto sería dejar seguir una
  /// escena que ya terminó, y el modelo, preguntado después del final,
  /// contesta cualquier cosa —en una prueba contestó en castellano—.
  bool _terminada = false;

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
    _prepararDiccionario();
  }

  @override
  void dispose() {
    _voz.callar();
    _scroll.dispose();
    _campo.dispose();
    super.dispose();
  }

  Future<void> _arrancar() async {
    final quien = await _quienSoy.cual();
    if (!mounted) return;
    setState(() => _quien = quien);
  }

  /// El diccionario se carga aparte y sin frenar nada, igual que la voz.
  ///
  /// Son 770 KB y tardan: si la pantalla esperara a que estén, la charla no
  /// aparecería hasta entonces, y para charlar no hacen falta.
  Future<void> _prepararDiccionario() async {
    final diccionario = await _diccionario.cargar();
    if (!mounted) return;
    setState(() => _elDiccionario = diccionario);
  }

  /// Contesta los pedidos de traducción.
  ///
  /// Casi siempre sin salir del celular: el diccionario viaja adentro. Las
  /// que no están se le preguntan al servidor, que se las pregunta a la IA
  /// una sola vez y las guarda, así el próximo que busque la misma palabra
  /// la recibe de la base sin gastar nada.
  ///
  /// Devuelve los renglones listos para mostrar, o vacío si no había pedidos.
  Future<String> _traducirLoMarcado(String mensaje) async {
    final renglones = <String>[];
    for (final pedido in pedidosDeTraduccion(mensaje)) {
      final traduccion = await _buscador.buscar(_elDiccionario, pedido);
      renglones.add(traduccion == null
          ? noEstaEnElDiccionario(pedido)
          : renglonesDeTraduccion([traduccion]));
    }
    return renglones.join('\n');
  }

  Future<void> _prepararVoz() async {
    final puedeHablar = await _voz.preparar();
    if (!mounted) return;
    setState(() => _puedeHablar = puedeHablar);
  }

  bool get _puedeEnviar => !_esperando && _campo.text.trim().isNotEmpty;

  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    if (_esperando || texto.isEmpty) return;

    final traducido = await _traducirLoMarcado(texto);
    // Ir al diccionario no es charla, así que ese ida y vuelta se ve en
    // pantalla pero no entra en lo que la IA recuerda.
    final soloDiccionario = esSoloTraduccion(texto);

    setState(() {
      _conversacion.agregar(Mensaje.mia(texto, paraLaIa: !soloDiccionario));
      _campo.clear();
      _esperando = !soloDiccionario;
    });
    _irAlFinal();

    // Lo contesta el diccionario de la app: en el acto, sin internet, sin
    // clave y sin gastar cuota. La IA ni se entera.
    if (soloDiccionario) {
      setState(() {
        if (_soloEscuchar) _tapados.add(_conversacion.mensajes.length);
        _conversacion.agregar(Mensaje.delDiccionario(traducido));
      });
      _irAlFinal();
      if (_soloEscuchar && _puedeHablar) _voz.decir(sinMarcas(traducido));
      return;
    }

    try {
      final contestado = await _servidor.charlar(
        quien: _quien,
        escena: widget.escena.paraElServidor,
        saludo: _conversacion.saludo,
        mensajes: _conversacion.paraElServidor(),
      );
      if (!mounted) return;
      // El barista cierra con una marca. Se la saca antes de mostrar nada:
      // no es algo que él diga, es una señal para la app.
      final cerro = widget.escena.termina && cierraLaEscena(contestado);
      final dicho = cerro ? sinLaMarcaDelFinal(contestado) : contestado;
      // No se muestra una corrección que repite lo que escribió.
      // Y la marca de la corrección se lee en castellano: lo que viene
      // después sigue en italiano, que es lo que hay que aprender.
      final deLaIa = conLaMarcaEnCastellano(sinCorreccionRepetida(dicho, texto));
      // Las traducciones van arriba, como antes, pero salen del diccionario.
      final respuesta =
          traducido.isEmpty ? deLaIa : '$traducido\n$deLaIa';
      setState(() {
        if (_soloEscuchar) _tapados.add(_conversacion.mensajes.length);
        _conversacion.agregar(Mensaje.deLaIa(respuesta));
        _esperando = false;
        _terminada = cerro;
      });
      _irAlFinal();
      // Tapada hay que decirla sola: es la única forma de saber qué contestó.
      // Destapada se toca la burbuja, igual que un renglón de los cuentos.
      if (_soloEscuchar && _puedeHablar) {
        _voz.decir(sinMarcas(paraLeerEnVozAlta(respuesta)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _conversacion.agregar(Mensaje.aviso(_explicar(error)));
        _esperando = false;
      });
      _irAlFinal();
    }
  }

  /// Qué mostrar cuando algo sale mal.
  ///
  /// El servidor ya manda el cartel escrito para el alumno, así que se usa
  /// ese: si algún día hay que explicar mejor una falla, se cambia allá y lo
  /// ven todos sin instalar nada.
  String _explicar(Object error) {
    if (error is FallaDelServidor) return error.mensaje;
    if (error is TimeoutException) {
      return 'La IA tardó demasiado en contestar. Probá de nuevo.';
    }
    return 'No se pudo hablar con el servidor. Fijate si tenés internet.';
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
    _voz.decir(sinMarcas(paraLeerEnVozAlta(texto)));
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

  /// Empieza una charla nueva, con otro saludo y por lo tanto con otro tema.
  ///
  /// Antes, para cambiar de tema había que salir de la sección y volver: es lo
  /// único que borraba la conversación. Ahora se hace acá, y el saludo que sale
  /// nunca es el que estaba.
  void _otroTema() {
    _voz.callar();
    setState(() {
      _conversacion = Conversacion(
        escena: widget.escena,
        saludo: saludoAlAzar(
          escena: widget.escena,
          distintoDe: _conversacion.saludo,
          azar: widget.azar,
        ),
      );
      _tapados.clear();
      _campo.clear();
      _terminada = false;
    });
    _irAlFinal();
  }

  @override
  Widget build(BuildContext context) {
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
              if (i == mensajes.length) {
                return _Escribiendo(quien: widget.escena.quienContesta);
              }
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
        if (_terminada)
          _EscenaTerminada(alEmpezarOtra: _otroTema)
        else
          Row(
            // Abajo: cuando el campo crece de renglones, el botón se queda
            // pegado al último, como en cualquier chat.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _campoDeTexto()),
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
      ],
    );
  }

  /// El campo donde se escribe, con el teclado del celular.
  ///
  /// Acá sí conviene el corrector: son frases largas y el idioma lo pone el
  /// teclado, no la app. En el resto de la app el teclado es propio, porque
  /// corregir una conjugación a medio escribir sería resolverle el ejercicio
  /// al alumno.
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
        // Que el botón de enviar se prenda al escribir la primera letra.
        onChanged: (_) => setState(() {}),
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        autocorrect: true,
        enableSuggestions: true,
        // Peso normal, igual que el resto de la app. Estaba en w600 y lo que
        // se escribía salía más gordo que el texto gris de ayuda, así que la
        // letra cambiaba de grosor al escribir la primera letra.
        style: const TextStyle(
          fontSize: 17,
          height: 1.3,
          color: Tema.texto,
        ),
        cursorColor: Tema.verde,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.escena == Escena.bar
              ? 'Contestale al barista...'
              : 'Escribí en italiano...',
          hintStyle: const TextStyle(
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
        // Se desliza, igual que la barra de secciones: con la letra grande del
        // celular las tres pastillas no siempre entran en una pantalla.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Va primero y sin depender de la voz: es lo que cambia de qué
              // se está hablando, y se usa más que las otras.
              Pastilla(
                texto: widget.escena.termina ? 'Otra escena' : 'Otro tema',
                icono: Icons.autorenew,
                // Mientras la IA piensa no: la respuesta llegaría a una charla
                // que ya no existe.
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
    if (widget.escena == Escena.bar) {
      // En el bar lo que hay que explicar es la escena, no los botones: sin
      // esto uno no sabe que tiene que pedir, ni que en algún momento
      // termina.
      return 'Estás en un bar en Italia. Pedí algo, preguntá cuánto es, pagá '
          'y saludá. Si escribís algo raro, te lo dice bien antes de '
          'contestarte.';
    }
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

/// Lo que reemplaza al campo de texto cuando la escena terminó.
///
/// El campo desaparece a propósito. Dejarlo abierto sería dejar seguir una
/// escena que ya cerró, y preguntado después del final el modelo contesta
/// cualquier cosa: en una prueba contestó en castellano "no me hables más, ya
/// terminó la escena".
class _EscenaTerminada extends StatelessWidget {
  const _EscenaTerminada({required this.alEmpezarOtra});

  final VoidCallback alEmpezarOtra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terminaste la escena',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Tema.titulo,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pagaste y te saludaron. La próxima sale distinta.',
                  style: TextStyle(fontSize: 12.5, color: Tema.textoTenue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: alEmpezarOtra,
            icon: const Icon(Icons.autorenew, size: 18),
            label: const Text('Otra'),
          ),
        ],
      ),
    );
  }
}

/// El cartel de que la IA está pensando. Ocupa el lugar de la respuesta que
/// falta, así se ve que el mensaje salió.
class _Escribiendo extends StatelessWidget {
  const _Escribiendo({required this.quien});

  final String quien;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Text(
          '$quien está escribiendo...',
          style: const TextStyle(
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

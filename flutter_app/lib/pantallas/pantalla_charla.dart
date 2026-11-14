import 'package:flutter/material.dart';

import '../datos/repositorio_charlas.dart';
import '../datos/repositorio_diccionario.dart';
import '../datos/voz.dart';
import '../ia/chat.dart'
    show
        esSoloTraduccion,
        noEstaEnElDiccionario,
        pedidosDeTraduccion,
        renglonesDeTraduccion,
        sinMarcas;
import '../logica/charla_guionada.dart';
import '../logica/diccionario_buscar.dart';
import '../modelos/charla.dart';
import '../modelos/diccionario.dart';
import '../tema.dart';

/// Una charla guionada, sin IA y sin internet.
///
/// Tuky dice una frase, se le contesta escribiendo, y la app compara lo
/// escrito contra las respuestas que ese paso espera. De ahí salen tres
/// caminos: se dijo bien y la charla avanza; se entendió qué quiso decir pero
/// lo dijo mal, y entonces se le muestra cómo se dice; o no se entendió nada,
/// y Tuky lo dice y deja ver las opciones.
///
/// La gracia es que la corrección sale del guion. Una IA chica corrigiendo
/// italiano acierta a veces, y una corrección equivocada enseña el error. Acá
/// la frase correcta está escrita de antemano: no puede estar mal.
class PantallaCharla extends StatefulWidget {
  const PantallaCharla({
    super.key,
    this.repositorio,
    this.voz,
    this.diccionario,
    this.cual = 'bar',
  });

  final RepositorioCharlas? repositorio;
  final Voz? voz;
  final RepositorioDiccionario? diccionario;

  /// Qué escena abrir.
  final String cual;

  @override
  State<PantallaCharla> createState() => _PantallaCharlaState();
}

enum _Quien { tuky, yo, aviso, correccion, diccionario }

class _Dicho {
  const _Dicho(this.quien, this.texto, {this.espanol = ''});

  final _Quien quien;
  final String texto;
  final String espanol;
}

class _PantallaCharlaState extends State<PantallaCharla> {
  late final RepositorioCharlas _repositorio =
      widget.repositorio ?? RepositorioCharlas();
  late final Voz _voz = widget.voz ?? VozDelSistema();
  late final RepositorioDiccionario _diccionario =
      widget.diccionario ?? RepositorioDiccionario();
  Diccionario _elDiccionario = const Diccionario();

  final TextEditingController _campo = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Charla? _charla;
  Paso? _paso;
  final List<_Dicho> _dichos = [];

  /// Las opciones se muestran cuando se pide ayuda o cuando no se entendió lo
  /// que se escribió. No desde el principio: la gracia es intentar primero.
  bool _mostrandoOpciones = false;

  bool _cargando = true;
  bool _puedeHablar = false;

  @override
  void initState() {
    super.initState();
    _arrancar();
    _prepararDiccionario();
  }

  @override
  void dispose() {
    _voz.callar();
    _campo.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// El diccionario se carga aparte y sin frenar la charla: son 770 KB y
  /// para empezar a hablar no hacen falta.
  Future<void> _prepararDiccionario() async {
    final diccionario = await _diccionario.cargar();
    if (!mounted) return;
    setState(() => _elDiccionario = diccionario);
  }

  Future<void> _arrancar() async {
    final charlas = await _repositorio.cargar();
    final puede = await _voz.preparar();
    if (!mounted) return;

    Charla? cual;
    for (final charla in charlas) {
      if (charla.id == widget.cual) cual = charla;
    }

    setState(() {
      _puedeHablar = puede;
      _charla = cual;
      _cargando = false;
      if (cual != null) {
        _dichos.add(_Dicho(_Quien.aviso, cual.donde));
        _irAlPaso(cual.primero);
      }
    });
  }

  /// Mueve la charla a un paso y agrega lo que Tuky dice ahí.
  void _irAlPaso(String id) {
    final paso = _charla?.paso(id);
    if (paso == null) return;
    _paso = paso;
    _mostrandoOpciones = false;
    _dichos.add(_Dicho(_Quien.tuky, paso.dice, espanol: paso.espanol));
    if (paso.esElFinal) {
      _dichos.add(const _Dicho(_Quien.aviso, 'Terminó la charla.'));
    }
  }

  /// Contesta lo que venga entre almohadillas, con el diccionario de la app.
  ///
  /// Anda igual que en la charla libre. No tiene nada que ver con la IA —es
  /// un archivo adentro del celular—, así que no hay ningún motivo para que
  /// funcione en una pantalla y en la otra no. Y acá hace más falta todavía:
  /// mientras se busca cómo contestar es justo cuando falta una palabra.
  String _traducirLoMarcado(String mensaje) {
    final renglones = <String>[];
    for (final pedido in pedidosDeTraduccion(mensaje)) {
      final traduccion = traducir(_elDiccionario, pedido);
      renglones.add(traduccion == null
          ? noEstaEnElDiccionario(pedido)
          : renglonesDeTraduccion([traduccion]));
    }
    return renglones.join('\n');
  }

  void _enviar() {
    final escrito = _campo.text.trim();
    final paso = _paso;
    if (escrito.isEmpty || paso == null || paso.esElFinal) return;

    final traducido = _traducirLoMarcado(escrito);
    if (traducido.isNotEmpty) {
      setState(() {
        _dichos
          ..add(_Dicho(_Quien.yo, escrito))
          ..add(_Dicho(_Quien.diccionario, traducido));
        _campo.clear();
      });
      _irAlFinal();
      // Buscar una palabra no es contestarle a Tuky: la charla se queda donde
      // estaba, esperando la respuesta de verdad.
      if (esSoloTraduccion(escrito)) return;
    }

    // Lo que se compara va sin almohadillas: son una marca para el
    // diccionario, no parte de lo que se dijo.
    final contestacion = queContesto(paso, sinMarcas(escrito));

    setState(() {
      if (traducido.isEmpty) _dichos.add(_Dicho(_Quien.yo, escrito));
      _campo.clear();

      switch (contestacion.como) {
        case ComoContesto.bien:
          _irAlPaso(contestacion.respuesta!.sigue);
        case ComoContesto.casi:
          // Primero cómo se dice, y después la charla sigue igual: entendió, y
          // frenarla acá sería castigar un error que ya quedó mostrado.
          _dichos.add(_Dicho(_Quien.correccion, contestacion.comoSeDice!));
          _irAlPaso(contestacion.respuesta!.sigue);
        case ComoContesto.noSeEntiende:
          _dichos.add(_Dicho(
            _Quien.tuky,
            'Non ho capito. Puoi ripetere?',
            espanol: 'No entendí. ¿Podés repetir?',
          ));
          _mostrandoOpciones = true;
      }
    });
    _irAlFinal();
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _empezarDeNuevo() {
    final charla = _charla;
    if (charla == null) return;
    _voz.callar();
    setState(() {
      _dichos
        ..clear()
        ..add(_Dicho(_Quien.aviso, charla.donde));
      _campo.clear();
      _irAlPaso(charla.primero);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: Text(
          'Un momento...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    final charla = _charla;
    if (charla == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se pudo abrir la charla.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Tema.textoTenue),
          ),
        ),
      );
    }

    final paso = _paso;
    final termino = paso == null || paso.esElFinal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _dichos.length,
            itemBuilder: (_, i) => _Burbuja(
              dicho: _dichos[i],
              alEscuchar: _puedeHablar && _dichos[i].quien == _Quien.tuky
                  ? () => _voz.decir(_dichos[i].texto)
                  : null,
            ),
          ),
        ),
        if (_mostrandoOpciones && !termino) _opciones(paso),
        const SizedBox(height: 6),
        if (termino) _botonDeNuevo() else _abajo(paso),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _botonDeNuevo() => ElevatedButton(
        onPressed: _empezarDeNuevo,
        style: Tema.botonPrincipal,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Empezar de nuevo', style: TextStyle(fontSize: 16)),
        ),
      );

  /// Lo que se puede contestar. Tocar una la escribe en el campo en vez de
  /// mandarla: la idea sigue siendo escribirla.
  Widget _opciones(Paso paso) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Podés decir:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Tema.verdeOscuro,
            ),
          ),
          const SizedBox(height: 6),
          for (final respuesta in paso.respuestas)
            InkWell(
              onTap: () => setState(() {
                _campo
                  ..text = respuesta.texto
                  ..selection = TextSelection.collapsed(
                    offset: respuesta.texto.length,
                  );
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· ', style: TextStyle(color: Tema.verdeOscuro)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            respuesta.texto,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Tema.titulo,
                            ),
                          ),
                          Text(
                            respuesta.espanol,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Tema.textoTenue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _abajo(Paso paso) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!_mostrandoOpciones) ...[
          SizedBox(
            width: 52,
            height: 56,
            child: OutlinedButton(
              onPressed: () => setState(() => _mostrandoOpciones = true),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Tema.borde, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tema.radio),
                ),
              ),
              child: const Icon(
                Icons.help_outline,
                size: 22,
                color: Tema.verdeOscuro,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: _campoDeTexto()),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: ElevatedButton(
            onPressed: _campo.text.trim().isEmpty ? null : _enviar,
            style: Tema.botonPrincipal.copyWith(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            child: const Icon(Icons.send_rounded, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _campoDeTexto() {
    return Container(
      constraints: const BoxConstraints(minHeight: 56, maxHeight: 100),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(color: Tema.borde, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: _campo,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _enviar(),
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.send,
        style: const TextStyle(fontSize: 16, color: Tema.texto),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Contestale en italiano...',
          hintStyle: TextStyle(fontSize: 15, color: Tema.textoTenue),
        ),
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.dicho, this.alEscuchar});

  final _Dicho dicho;
  final VoidCallback? alEscuchar;

  @override
  Widget build(BuildContext context) {
    if (dicho.quien == _Quien.aviso) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          dicho.texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
        ),
      );
    }

    if (dicho.quien == _Quien.diccionario) {
      return _Recuadro(titulo: 'Diccionario', texto: dicho.texto);
    }

    if (dicho.quien == _Quien.correccion) {
      return _Recuadro(titulo: 'Se dice así:', texto: dicho.texto);
    }

    final mio = dicho.quien == _Quien.yo;

    return Padding(
      padding: EdgeInsets.fromLTRB(mio ? 48 : 12, 4, mio ? 12 : 48, 4),
      child: Align(
        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: alEscuchar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mio ? Tema.verde : Tema.superficie,
              borderRadius: BorderRadius.circular(Tema.radio),
              border: mio ? null : Border.all(color: Tema.borde),
            ),
            child: Column(
              crossAxisAlignment:
                  mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  dicho.texto,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color: mio ? Colors.white : Tema.texto,
                  ),
                ),
                if (dicho.espanol.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    dicho.espanol,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: Tema.textoTenue,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un recuadro verde al costado: lo que no es la charla sino una ayuda sobre
/// la charla. La corrección y el diccionario.
class _Recuadro extends StatelessWidget {
  const _Recuadro({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 40, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Tema.verdeSuave,
          borderRadius: BorderRadius.circular(Tema.radio),
          border: const Border(left: BorderSide(color: Tema.verde, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Tema.verdeOscuro,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              texto,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: Tema.titulo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/voz.dart';
import '../logica/armar_frase.dart';
import '../logica/leccion.dart';
import '../modelos/percorso.dart';
import '../tema.dart';
import '../widgets/ficha_palabra.dart';

/// Una lección, de principio a fin.
///
/// Es lo que faltaba atrás del botón "Empezar": hasta ahora el camino
/// mostraba la fila de lecciones y cada escalón no llevaba a ningún lado.
///
/// Adentro no hay menú ni opciones: hay un paso a la vez y un solo botón
/// abajo. El que recién empieza no tiene que decidir nada más que la
/// respuesta. Los pasos los arma [pasosDe], que vive aparte y con su test:
/// el orden —mostrar antes de preguntar— es lo que hace que la lección
/// enseñe en vez de tomar examen.
class PantallaLeccion extends StatefulWidget {
  const PantallaLeccion({
    super.key,
    required this.leccion,
    required this.voz,
    this.antes = const [],
    this.alTerminar,
    this.alSalir,
    this.azar,
  });

  final Leccion leccion;

  /// Las lecciones ya hechas de la misma ciudad. De ahí sale el repaso
  /// del final, y, si esta lección es la prueba, todas sus preguntas.
  final List<Leccion> antes;

  final Voz voz;

  /// La lección se dio por hecha. Lo llama el botón del final.
  final VoidCallback? alTerminar;

  /// La flecha de atrás: se sale sin darla por hecha.
  final VoidCallback? alSalir;

  /// Para los tests, que necesitan siempre los mismos pasos.
  final Random? azar;

  @override
  State<PantallaLeccion> createState() => _PantallaLeccionState();
}

class _PantallaLeccionState extends State<PantallaLeccion> {
  late List<Paso> _pasos = _armarLosPasos();

  List<Paso> _armarLosPasos() => pasosDe(
    widget.leccion,
    antes: widget.antes,
    // La prueba se puede repetir, y repetida tiene que traer otras
    // preguntas: con la misma semilla saldrían las ocho de antes y se
    // aprobaría de memoria. Fuera de la prueba, la semilla es la que
    // viene, que es lo que deja a los tests mirar siempre lo mismo.
    azar: widget.leccion.esPrueba && _intentos > 0 ? null : widget.azar,
  );

  /// Cuántas veces se empezó la prueba.
  int _intentos = 0;

  int _cual = 0;

  /// Lo elegido en el paso de las cuatro opciones.
  String? _elegida;

  /// Las fichas puestas, por su lugar en el banco.
  List<int> _puestas = [];

  /// La palabra italiana tocada en el relacionar, esperando su pareja.
  String? _esperandoPareja;

  /// Las parejas ya resueltas: italiano a español.
  Map<String, String> _parejas = {};

  /// El último intento fallido del relacionar, para pintarlo en rojo
  /// hasta el toque siguiente. Sin reloj: un rojo que se apaga solo
  /// necesitaría un timer, y en los tests el reloj es falso.
  (String, String)? _parejaMal;

  /// Cuántas veces se erró en el relacionar de este paso.
  int _erroresDeRelacion = 0;

  /// Ya se apretó Comprobar: la respuesta queda a la vista, pintada.
  bool _comprobado = false;

  /// Cuántas se contestaron bien. Va en el cartel del final.
  int _bien = 0;

  /// Cuántas se contestaron, bien o mal.
  int _contestadas = 0;

  bool _puedeHablar = false;

  @override
  void initState() {
    super.initState();
    _prepararLaVoz();
  }

  Future<void> _prepararLaVoz() async {
    final puede = await widget.voz.preparar();
    if (!mounted) return;
    setState(() => _puedeHablar = puede);
    _decirLoDeAhora();
  }

  @override
  void dispose() {
    widget.voz.callar();
    super.dispose();
  }

  Paso? get _paso => _cual < _pasos.length ? _pasos[_cual] : null;

  bool get _termino => _paso == null;

  /// Lo que se lee en voz alta en este paso, o vacío si no hay nada.
  String get _loQueSeDice => switch (_paso) {
    MostrarPalabra(:final palabra) => palabra.italiano,
    MostrarFrase(:final frase) => frase.italiano,
    ElegirTraduccion(:final palabra) => palabra.italiano,
    // La explicación, el diálogo y el relacionar no se leen solos: el
    // primero es castellano, y los otros dos son varias frases. Tienen su
    // botón de escuchar renglón por renglón.
    MostrarExplicacion() => '',
    MostrarDialogo() => '',
    Contestar() => '',
    Relacionar() => '',
    ArmarLaFrase() => '',
    null => '',
  };

  void _decirLoDeAhora() {
    if (!_puedeHablar) return;
    final texto = _loQueSeDice;
    if (texto.isNotEmpty) widget.voz.decir(texto);
  }

  /// Si lo contestado está bien. Para los pasos que no se contestan es
  /// siempre true: no hay con qué equivocarse.
  bool get _estaBien => switch (_paso) {
    ElegirTraduccion(:final correcta) => _elegida == correcta,
    Contestar(:final pregunta) => _elegida == pregunta.correcta,
    Relacionar() => _erroresDeRelacion == 0,
    // Los dos lados en minúscula.
    //
    // Antes solo se bajaba el del alumno, y entonces **toda frase con un
    // nombre propio era imposible de acertar**: la ficha dice "Marco"
    // —comoFicha le deja la mayúscula porque es un nombre— y al
    // compararla con "marco" nunca daba. Matías mandó la foto de "Mi
    // chiamo Marco, piacere!" armada perfecta y marcada en rojo.
    ArmarLaFrase(:final frase, :final fichas) =>
      _puestas.map((i) => fichas[i]).join(' ').toLowerCase() ==
          palabrasDeLaFrase(
            frase.italiano,
          ).map(comoFicha).join(' ').toLowerCase(),
    _ => true,
  };

  bool get _sePuedeComprobar => switch (_paso) {
    ElegirTraduccion() => _elegida != null,
    Contestar() => _elegida != null,
    // El relacionar se comprueba solo cuando están las cuatro: hasta
    // entonces no hay nada que comprobar, falta trabajo.
    Relacionar(:final pares) => _parejas.length == pares.length,
    ArmarLaFrase() => _puestas.isNotEmpty,
    _ => true,
  };

  bool get _hayQueComprobar =>
      _paso is ElegirTraduccion ||
      _paso is Contestar ||
      _paso is Relacionar ||
      _paso is ArmarLaFrase;

  /// Un toque en el relacionar: primero una italiana, después su
  /// traducción. Si la pareja está bien queda puesta; si no, se marca en
  /// rojo y se suelta, sin perder las que ya estaban.
  void _tocarEnRelacionar({required bool izquierda, required String texto}) {
    final paso = _paso;
    if (paso is! Relacionar) return;
    setState(() {
      _parejaMal = null;
      if (izquierda) {
        _esperandoPareja = texto;
        return;
      }
      final italiana = _esperandoPareja;
      if (italiana == null) return;
      final par = paso.pares.firstWhere((p) => p.italiano == italiana);
      if (par.espanol == texto) {
        _parejas = {..._parejas, italiana: texto};
      } else {
        _erroresDeRelacion++;
        _parejaMal = (italiana, texto);
      }
      _esperandoPareja = null;
    });
  }

  void _comprobar() {
    setState(() {
      _comprobado = true;
      _contestadas++;
      if (_estaBien) _bien++;
    });
  }

  /// Volver a dar la prueba, con otras preguntas.
  void _volverAIntentar() {
    widget.voz.callar();
    setState(() {
      _intentos++;
      _pasos = _armarLosPasos();
      _cual = 0;
      _bien = 0;
      _contestadas = 0;
      _elegida = null;
      _puestas = [];
      _comprobado = false;
      _esperandoPareja = null;
      _parejas = {};
      _parejaMal = null;
      _erroresDeRelacion = 0;
    });
  }

  /// Si la prueba se aprobó. Fuera de la prueba no hay nota: terminarla
  /// ya es haberla hecho.
  bool get _aprobo =>
      !widget.leccion.esPrueba || _bien >= widget.leccion.paraAprobar;

  void _seguir() {
    widget.voz.callar();
    setState(() {
      _cual++;
      _elegida = null;
      _puestas = [];
      _comprobado = false;
      _esperandoPareja = null;
      _parejas = {};
      _parejaMal = null;
      _erroresDeRelacion = 0;
    });
    _decirLoDeAhora();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Barra(hechos: _cual, total: _pasos.length, alSalir: widget.alSalir),
        // Centrado vertical, pero adentro de un scroll: casi todos los
        // pasos ocupan media pantalla y pegados arriba dejaban un hueco
        // enorme abajo. El que no entra —armar una frase larga con la
        // letra del sistema grande— se desplaza como siempre.
        Expanded(
          child: LayoutBuilder(
            builder: (context, medidas) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: medidas.maxHeight - 36),
                child: Center(child: _termino ? _elFinal() : _elPaso()),
              ),
            ),
          ),
        ),
        _abajo(),
      ],
    );
  }

  Widget _elPaso() => switch (_paso!) {
    MostrarExplicacion(:final explicacion) => _LaExplicacion(
      explicacion: explicacion,
      alEscuchar: _puedeHablar ? widget.voz.decir : null,
    ),
    MostrarDialogo(:final dialogo) => _ElDialogo(
      dialogo: dialogo,
      alEscuchar: _puedeHablar ? widget.voz.decir : null,
    ),
    MostrarPalabra(:final palabra) => _Tarjeta(
      arriba: 'Palabra nueva',
      italiano: palabra.italiano,
      suena: palabra.suena,
      espanol: palabra.espanol,
      alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
    ),
    MostrarFrase(:final frase) => _Tarjeta(
      arriba: 'Así se dice',
      italiano: frase.italiano,
      suena: frase.suena,
      espanol: frase.espanol,
      alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
    ),
    ElegirTraduccion(:final palabra, :final opciones, :final correcta) =>
      _Elegir(
        consigna: (_paso! as ElegirTraduccion).esRepaso
            ? 'Repaso: ¿qué quiere decir?'
            : '¿Qué quiere decir?',
        enunciado: palabra.italiano,
        opciones: opciones,
        correcta: correcta,
        elegida: _elegida,
        comprobado: _comprobado,
        alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
        alElegir: _comprobado
            ? null
            : (cual) => setState(() => _elegida = cual),
      ),
    Contestar(:final pregunta) => _Elegir(
      consigna: pregunta.consigna,
      enunciado: pregunta.enunciado,
      chico: true,
      opciones: pregunta.opciones,
      correcta: pregunta.correcta,
      elegida: _elegida,
      comprobado: _comprobado,
      alElegir: _comprobado ? null : (cual) => setState(() => _elegida = cual),
    ),
    Relacionar(:final pares, :final traducciones) => _ElRelacionar(
      pares: pares,
      traducciones: traducciones,
      esperando: _esperandoPareja,
      parejas: _parejas,
      parejaMal: _parejaMal,
      alTocar: _comprobado ? null : _tocarEnRelacionar,
    ),
    ArmarLaFrase(:final frase, :final fichas) => _Armar(
      frase: frase,
      fichas: fichas,
      puestas: _puestas,
      comprobado: _comprobado,
      bien: _estaBien,
      alPoner: _comprobado
          ? null
          : (i) => setState(() => _puestas = [..._puestas, i]),
      alSacar: _comprobado
          ? null
          : (i) => setState(() => _puestas = [..._puestas]..remove(i)),
    ),
  };

  /// El cartel del final.
  ///
  /// Sin puntaje si no hubo nada que contestar: la lección del cuento es
  /// solo leer, y "0 de 0" sonaría a haber fallado.
  ///
  /// En la prueba sí hay nota, y hay reprobar: es lo único de la app que
  /// se puede no pasar. Reprobar no castiga —no se pierde lo hecho— pero
  /// tampoco abre la ciudad siguiente, que es de lo que se trata.
  Widget _elFinal() {
    final esPrueba = widget.leccion.esPrueba;
    final aprobo = _aprobo;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Un ícono y no un emoji: el 🎉 depende de que el celular tenga
        // ese dibujo, y donde no está se ve el cuadradito vacío. Pasó en
        // el banco de pruebas, que usa una tipografía sin emojis.
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: aprobo ? Tema.verdeSuave : Tema.terracotaSuave,
            shape: BoxShape.circle,
          ),
          child: Icon(
            aprobo ? Icons.check_rounded : Icons.refresh_rounded,
            size: 48,
            color: aprobo ? Tema.verde : Tema.terracota,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          switch ((esPrueba, aprobo)) {
            (true, true) => '¡Aprobaste!',
            (true, false) => 'Casi',
            _ => '¡Lección terminada!',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Tema.titulo,
          ),
        ),
        if (_contestadas > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$_bien de $_contestadas bien',
            style: const TextStyle(fontSize: 17, color: Tema.textoTenue),
          ),
        ],
        if (esPrueba && !aprobo) ...[
          const SizedBox(height: 8),
          Text(
            'Hacen falta ${widget.leccion.paraAprobar}. '
            'Probá de nuevo: las preguntas son otras.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        ],
      ],
    );
  }

  Widget _abajo() {
    final (texto, alTocar) = switch (_termino) {
      true when !_aprobo => ('Volver a intentar', _volverAIntentar),
      true => ('Terminar', widget.alTerminar),
      false when _hayQueComprobar && !_comprobado => (
        'Comprobar',
        _sePuedeComprobar ? _comprobar : null,
      ),
      false => ('Seguir', _seguir),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Tema.fondo,
        border: Border(top: BorderSide(color: Tema.borde)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_comprobado) ...[
            _Veredicto(
              bien: _estaBien,
              mensaje: _mensajeDelVeredicto,
              porque: _porque,
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: alTocar,
              style: Tema.botonPrincipal,
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lo que dice el renglón de arriba del botón.
  ///
  /// Cuando se erró, la que iba: decir "mal" y no decir cuál era deja al
  /// alumno igual que antes.
  String get _mensajeDelVeredicto {
    if (_estaBien) return '¡Bien!';
    final paso = _paso;
    if (paso is Relacionar) {
      return _erroresDeRelacion == 1
          ? 'Con un error, pero quedaron las cuatro'
          : 'Con $_erroresDeRelacion errores, pero quedaron las cuatro';
    }
    return switch (paso) {
      ElegirTraduccion(:final correcta) => 'Era: $correcta',
      Contestar(:final pregunta) => 'Era: ${pregunta.correcta}',
      ArmarLaFrase(:final frase) => 'Era: ${frase.italiano}',
      _ => '',
    };
  }

  /// El por qué del ejercicio, si lo trae. Se muestra siempre, se haya
  /// acertado o no: el que acierta de casualidad también lo necesita.
  String get _porque => switch (_paso) {
    Contestar(:final pregunta) => pregunta.porque,
    _ => '',
  };
}

/// Arriba: de dónde salir y cuánto falta.
class _Barra extends StatelessWidget {
  const _Barra({required this.hechos, required this.total, this.alSalir});

  final int hechos;
  final int total;
  final VoidCallback? alSalir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: alSalir,
            icon: const Icon(Icons.close_rounded),
            color: Tema.textoTenue,
            tooltip: 'Salir',
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 1 : hechos / total,
                minHeight: 10,
                backgroundColor: Tema.borde,
                valueColor: const AlwaysStoppedAnimation<Color>(Tema.verde),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La tarjeta de mostrar: una palabra o una frase, con su traducción.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.arriba,
    required this.italiano,
    required this.espanol,
    this.suena = '',
    this.alEscuchar,
  });

  final String arriba;
  final String italiano;
  final String espanol;

  /// Cómo se lee, cuando no se lee como se escribe.
  final String suena;

  final VoidCallback? alEscuchar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          arriba,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Tema.textoTenue,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          decoration: BoxDecoration(
            color: Tema.superficie,
            borderRadius: BorderRadius.circular(Tema.radio),
            boxShadow: Tema.sombra,
          ),
          child: Column(
            children: [
              Text(
                italiano,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Tema.titulo,
                ),
              ),
              if (suena.isNotEmpty && !_mismoTexto(suena, italiano)) ...[
                const SizedBox(height: 4),
                _ComoSuena(suena: suena),
              ],
              const SizedBox(height: 10),
              Text(
                espanol,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Tema.textoTenue),
              ),
              if (alEscuchar != null) ...[
                const SizedBox(height: 14),
                _BotonEscuchar(alTocar: alEscuchar!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonEscuchar extends StatelessWidget {
  const _BotonEscuchar({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: alTocar,
      icon: const Icon(Icons.volume_up_rounded, color: Tema.verde),
      label: const Text(
        'Escuchar',
        style: TextStyle(
          color: Tema.verde,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Qué quiere decir esta palabra: cuatro opciones.
class _Elegir extends StatelessWidget {
  const _Elegir({
    required this.consigna,
    required this.enunciado,
    required this.opciones,
    required this.correcta,
    required this.elegida,
    required this.comprobado,
    this.chico = false,
    this.alElegir,
    this.alEscuchar,
  });

  /// El renglón de arriba: "¿Qué quiere decir?", "Completá", "¿Qué le
  /// contestás?".
  final String consigna;

  /// Lo que se lee en la tarjeta: una palabra sola, o una frase con ___.
  final String enunciado;

  /// Una frase entera no entra con la letra de una palabra suelta.
  final bool chico;

  final List<String> opciones;
  final String correcta;
  final String? elegida;
  final bool comprobado;
  final void Function(String)? alElegir;
  final VoidCallback? alEscuchar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          consigna,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Tema.textoTenue,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          decoration: BoxDecoration(
            color: Tema.superficie,
            borderRadius: BorderRadius.circular(Tema.radio),
            boxShadow: Tema.sombra,
          ),
          child: Column(
            children: [
              Text(
                enunciado,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: chico ? 20 : 30,
                  fontWeight: FontWeight.w700,
                  color: Tema.titulo,
                ),
              ),
              if (alEscuchar != null) _BotonEscuchar(alTocar: alEscuchar!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final opcion in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Opcion(
              texto: opcion,
              elegida: opcion == elegida,
              // La correcta se pinta al comprobar aunque se haya tocado
              // otra: si no, la pantalla dice "mal" y no dice cuál era.
              correcta: comprobado && opcion == correcta,
              alTocar: alElegir == null ? null : () => alElegir!(opcion),
            ),
          ),
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.texto,
    required this.elegida,
    required this.correcta,
    this.alTocar,
  });

  final String texto;
  final bool elegida;
  final bool correcta;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final fondo = correcta
        ? Tema.correcto
        : elegida
        ? Tema.verde
        : Tema.superficie;
    return SizedBox(
      height: 54,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(Tema.radio),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tema.radio),
              border: Border.all(
                color: correcta || elegida ? Colors.transparent : Tema.borde,
                width: 1.5,
              ),
            ),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: correcta || elegida ? Colors.white : Tema.titulo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Armar la frase con fichas, igual que en Frasi.
class _Armar extends StatelessWidget {
  const _Armar({
    required this.frase,
    required this.fichas,
    required this.puestas,
    required this.comprobado,
    required this.bien,
    this.alPoner,
    this.alSacar,
  });

  final FraseDeLeccion frase;
  final List<String> fichas;
  final List<int> puestas;
  final bool comprobado;
  final bool bien;
  final void Function(int)? alPoner;
  final void Function(int)? alSacar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Armá la frase en italiano',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Tema.textoTenue,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Tema.superficie,
            borderRadius: BorderRadius.circular(Tema.radio),
            boxShadow: Tema.sombra,
          ),
          child: Text(
            frase.espanol,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Tema.titulo,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Tema.superficie,
            borderRadius: BorderRadius.circular(Tema.radio),
            border: Border.all(
              color: comprobado
                  ? (bien ? Tema.correcto : Tema.incorrecto)
                  : (puestas.isEmpty ? Tema.borde : Tema.verde),
              width: puestas.isEmpty && !comprobado ? 1.5 : 2,
            ),
          ),
          child: puestas.isEmpty
              ? const Center(
                  child: Text(
                    'Tocá las palabras de abajo',
                    style: TextStyle(fontSize: 16, color: Tema.textoTenue),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cual in puestas)
                      FichaPalabra(
                        palabra: fichas[cual],
                        puesta: true,
                        alTocar: alSacar == null ? null : () => alSacar!(cual),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        // Las puestas dejan el hueco en vez de desaparecer: así el banco no
        // se reacomoda entero a cada toque. Es lo mismo que hace Frasi.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < fichas.length; i++)
              Opacity(
                opacity: puestas.contains(i) ? 0.25 : 1,
                child: FichaPalabra(
                  palabra: fichas[i],
                  puesta: false,
                  alTocar: puestas.contains(i) || alPoner == null
                      ? null
                      : () => alPoner!(i),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// El renglón que dice si estuvo bien, arriba del botón.
class _Veredicto extends StatelessWidget {
  const _Veredicto({
    required this.bien,
    required this.mensaje,
    this.porque = '',
  });

  final bool bien;
  final String mensaje;

  /// Por qué es así. Va abajo, en gris: es lo que convierte un error en
  /// algo aprendido en vez de un número que bajó.
  final String porque;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              bien ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: bien ? Tema.correcto : Tema.incorrecto,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: bien ? Tema.correcto : Tema.incorrecto,
                ),
              ),
            ),
          ],
        ),
        if (porque.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 30),
            child: Text(
              porque,
              style: const TextStyle(fontSize: 13.5, color: Tema.textoTenue),
            ),
          ),
      ],
    );
  }
}

/// Si dos textos dicen lo mismo, más allá de mayúsculas y acentos.
///
/// Sirve para no escribir tres veces la misma palabra: "casa / se lee
/// casa / casa" ocupa una tarjeta entera para no decir nada.
bool _mismoTexto(String a, String b) => _pelado(a) == _pelado(b);

String _pelado(String texto) {
  const con = 'áàéèíìóòúùü';
  const sin = 'aaeeiioouuu';
  var salida = texto.toLowerCase();
  for (var i = 0; i < con.length; i++) {
    salida = salida.replaceAll(con[i], sin[i]);
  }
  return salida;
}

/// Cómo se lee una palabra, escrito como lo leería un argentino.
///
/// Entre comillas simples y en cursiva para que no se confunda con la
/// traducción: "ciao / *chao* / hola" se lee de una.
class _ComoSuena extends StatelessWidget {
  const _ComoSuena({required this.suena});

  final String suena;

  @override
  Widget build(BuildContext context) {
    return Text(
      'se lee "$suena"',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: Tema.verdeOscuro,
      ),
    );
  }
}

/// La tarjeta de la regla: una idea, y los ejemplos abajo.
///
/// Los ejemplos se tocan para escucharlos. En una regla de pronunciación
/// eso no es un adorno: es la mitad de la explicación.
class _LaExplicacion extends StatelessWidget {
  const _LaExplicacion({required this.explicacion, this.alEscuchar});

  final Explicacion explicacion;
  final void Function(String)? alEscuchar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: Tema.superficie,
            borderRadius: BorderRadius.circular(Tema.radio),
            boxShadow: Tema.sombra,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (explicacion.titulo.isNotEmpty) ...[
                Text(
                  explicacion.titulo,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Tema.titulo,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (explicacion.texto.isNotEmpty)
                Text(
                  explicacion.texto,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Tema.texto,
                  ),
                ),
            ],
          ),
        ),
        for (final ejemplo in explicacion.ejemplos)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Ejemplo(ejemplo: ejemplo, alEscuchar: alEscuchar),
          ),
      ],
    );
  }
}

class _Ejemplo extends StatelessWidget {
  const _Ejemplo({required this.ejemplo, this.alEscuchar});

  final FraseDeLeccion ejemplo;
  final void Function(String)? alEscuchar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tema.verdeSuave,
      borderRadius: BorderRadius.circular(Tema.radioChico),
      child: InkWell(
        onTap: alEscuchar == null ? null : () => alEscuchar!(ejemplo.italiano),
        borderRadius: BorderRadius.circular(Tema.radioChico),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ejemplo.italiano,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Tema.titulo,
                      ),
                    ),
                    if (ejemplo.suena.isNotEmpty &&
                        !_mismoTexto(ejemplo.suena, ejemplo.italiano))
                      Text(
                        'se lee "${ejemplo.suena}"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Tema.verdeOscuro,
                        ),
                      ),
                    if (ejemplo.espanol.isNotEmpty &&
                        !_mismoTexto(ejemplo.espanol, ejemplo.italiano))
                      Text(
                        ejemplo.espanol,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Tema.textoTenue,
                        ),
                      ),
                  ],
                ),
              ),
              if (alEscuchar != null)
                const Icon(
                  Icons.volume_up_rounded,
                  color: Tema.verde,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un diálogo: quién dice qué, con la traducción debajo de cada renglón.
///
/// Las dos voces van a lados distintos, como un chat. Es la forma en que
/// ya se lee una conversación sin que nadie la explique.
class _ElDialogo extends StatelessWidget {
  const _ElDialogo({required this.dialogo, this.alEscuchar});

  final Dialogo dialogo;
  final void Function(String)? alEscuchar;

  @override
  Widget build(BuildContext context) {
    // Quién habla primero va a la izquierda; el otro, a la derecha.
    final primero = dialogo.renglones.first.quien;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dialogo.situacion.isNotEmpty) ...[
          Text(
            dialogo.situacion,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tema.textoTenue,
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final renglon in dialogo.renglones)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Burbuja(
              renglon: renglon,
              aLaIzquierda: renglon.quien == primero,
              alEscuchar: alEscuchar,
            ),
          ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({
    required this.renglon,
    required this.aLaIzquierda,
    this.alEscuchar,
  });

  final RenglonDeDialogo renglon;
  final bool aLaIzquierda;
  final void Function(String)? alEscuchar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: aLaIzquierda
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        Flexible(
          child: Material(
            color: aLaIzquierda ? Tema.superficie : Tema.verdeSuave,
            borderRadius: BorderRadius.circular(Tema.radio),
            child: InkWell(
              onTap: alEscuchar == null
                  ? null
                  : () => alEscuchar!(renglon.italiano),
              borderRadius: BorderRadius.circular(Tema.radio),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (renglon.quien.isNotEmpty)
                      Text(
                        renglon.quien,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Tema.verdeOscuro,
                        ),
                      ),
                    Text(
                      renglon.italiano,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: Tema.titulo,
                      ),
                    ),
                    if (renglon.espanol.isNotEmpty)
                      Text(
                        renglon.espanol,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Tema.textoTenue,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Unir cada palabra con lo que quiere decir: una columna contra la otra.
///
/// Se toca primero una italiana y después su traducción. La pareja que
/// sale bien queda puesta en verde y no se toca más; la que sale mal
/// queda en rojo hasta el toque siguiente y hay que volver a intentarla.
/// Nada se pierde al errar: la gracia es que al final queden las cuatro.
class _ElRelacionar extends StatelessWidget {
  const _ElRelacionar({
    required this.pares,
    required this.traducciones,
    required this.esperando,
    required this.parejas,
    required this.parejaMal,
    this.alTocar,
  });

  final List<PalabraDeLeccion> pares;
  final List<String> traducciones;
  final String? esperando;
  final Map<String, String> parejas;
  final (String, String)? parejaMal;
  final void Function({required bool izquierda, required String texto})?
  alTocar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Uní cada palabra con lo que quiere decir',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Tema.textoTenue,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final par in pares)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Media(
                        texto: par.italiano,
                        resuelta: parejas.containsKey(par.italiano),
                        elegida: esperando == par.italiano,
                        mal: parejaMal?.$1 == par.italiano,
                        alTocar: alTocar == null
                            ? null
                            : () => alTocar!(
                                izquierda: true,
                                texto: par.italiano,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  for (final texto in traducciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Media(
                        texto: texto,
                        resuelta: parejas.containsValue(texto),
                        elegida: false,
                        mal: parejaMal?.$2 == texto,
                        alTocar: alTocar == null
                            ? null
                            : () => alTocar!(izquierda: false, texto: texto),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Media pareja: una de las fichas del relacionar.
class _Media extends StatelessWidget {
  const _Media({
    required this.texto,
    required this.resuelta,
    required this.elegida,
    required this.mal,
    this.alTocar,
  });

  final String texto;
  final bool resuelta;
  final bool elegida;
  final bool mal;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final fondo = resuelta
        ? Tema.correcto
        : mal
        ? Tema.incorrecto
        : elegida
        ? Tema.verde
        : Tema.superficie;
    final blanca = resuelta || mal || elegida;

    return SizedBox(
      height: 52,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: InkWell(
          onTap: resuelta ? null : alTocar,
          borderRadius: BorderRadius.circular(Tema.radio),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tema.radio),
              border: Border.all(
                color: blanca ? Colors.transparent : Tema.borde,
                width: 1.5,
              ),
            ),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: blanca ? Colors.white : Tema.titulo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

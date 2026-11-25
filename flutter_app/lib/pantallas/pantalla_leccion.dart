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
    this.alTerminar,
    this.alSalir,
    this.azar,
  });

  final Leccion leccion;
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
  late final List<Paso> _pasos = pasosDe(widget.leccion, azar: widget.azar);

  int _cual = 0;

  /// Lo elegido en el paso de las cuatro opciones.
  String? _elegida;

  /// Las fichas puestas, por su lugar en el banco.
  List<int> _puestas = [];

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
    ArmarLaFrase(:final frase, :final fichas) =>
      _puestas.map((i) => fichas[i]).join(' ').toLowerCase() ==
          palabrasDeLaFrase(frase.italiano).map(comoFicha).join(' '),
    _ => true,
  };

  bool get _sePuedeComprobar => switch (_paso) {
    ElegirTraduccion() => _elegida != null,
    ArmarLaFrase() => _puestas.isNotEmpty,
    _ => true,
  };

  bool get _hayQueComprobar =>
      _paso is ElegirTraduccion || _paso is ArmarLaFrase;

  void _comprobar() {
    setState(() {
      _comprobado = true;
      _contestadas++;
      if (_estaBien) _bien++;
    });
  }

  void _seguir() {
    widget.voz.callar();
    setState(() {
      _cual++;
      _elegida = null;
      _puestas = [];
      _comprobado = false;
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
    MostrarPalabra(:final palabra) => _Tarjeta(
      arriba: 'Palabra nueva',
      italiano: palabra.italiano,
      espanol: palabra.espanol,
      alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
    ),
    MostrarFrase(:final frase) => _Tarjeta(
      arriba: 'Así se dice',
      italiano: frase.italiano,
      espanol: frase.espanol,
      alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
    ),
    ElegirTraduccion(:final palabra, :final opciones, :final correcta) =>
      _Elegir(
        palabra: palabra,
        opciones: opciones,
        correcta: correcta,
        elegida: _elegida,
        comprobado: _comprobado,
        alEscuchar: _puedeHablar ? _decirLoDeAhora : null,
        alElegir: _comprobado
            ? null
            : (cual) => setState(() => _elegida = cual),
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

  /// El cartel del final. Sin puntaje si no hubo nada que contestar: la
  /// lección del cuento es solo leer, y "0 de 0" sonaría a haber fallado.
  Widget _elFinal() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Un ícono y no un emoji: el 🎉 depende de que el celular tenga
        // ese dibujo, y donde no está se ve el cuadradito vacío. Pasó en
        // el banco de pruebas, que usa una tipografía sin emojis.
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: Tema.verdeSuave,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 48, color: Tema.verde),
        ),
        const SizedBox(height: 16),
        const Text(
          '¡Lección terminada!',
          textAlign: TextAlign.center,
          style: TextStyle(
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
      ],
    );
  }

  Widget _abajo() {
    final (texto, alTocar) = switch (_termino) {
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
            _Veredicto(bien: _estaBien, correcta: _laCorrecta),
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

  /// La respuesta que iba, para mostrarla cuando se erró.
  String get _laCorrecta => switch (_paso) {
    ElegirTraduccion(:final correcta) => correcta,
    ArmarLaFrase(:final frase) => frase.italiano,
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
    this.alEscuchar,
  });

  final String arriba;
  final String italiano;
  final String espanol;
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
    required this.palabra,
    required this.opciones,
    required this.correcta,
    required this.elegida,
    required this.comprobado,
    this.alElegir,
    this.alEscuchar,
  });

  final PalabraDeLeccion palabra;
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
        const Text(
          '¿Qué quiere decir?',
          textAlign: TextAlign.center,
          style: TextStyle(
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
                palabra.italiano,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
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
  const _Veredicto({required this.bien, required this.correcta});

  final bool bien;
  final String correcta;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          bien ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: bien ? Tema.correcto : Tema.incorrecto,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bien ? '¡Bien!' : 'Era: $correcta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: bien ? Tema.correcto : Tema.incorrecto,
            ),
          ),
        ),
      ],
    );
  }
}

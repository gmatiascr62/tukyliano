import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../datos/repositorio_articoli.dart';
import '../logica/articulos.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/hoja_ayuda.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/texto_ajustado.dart';

/// Qué familia de artículos se practica.
///
/// Son dos sistemas distintos y cada uno tiene su regla, así que se pueden
/// machacar por separado; mezclados es lo más difícil, porque además de saber
/// la clase de la palabra hay que darse cuenta de cuál de los dos se pide.
enum GrupoArticoli { determinati, indeterminati, todos }

extension DatosGrupo on GrupoArticoli {
  String get etiqueta => switch (this) {
        GrupoArticoli.determinati => 'Determinati',
        GrupoArticoli.indeterminati => 'Indeterminati',
        GrupoArticoli.todos => 'Todos',
      };

  /// El partitivo va con los indeterminados y no aparte: el italiano no tiene
  /// "unos/unas" ni "algo de", y usa el partitivo para las dos cosas. Para el
  /// que estudia es el mismo casillero.
  Set<CategoriaArticulo> get categorias => switch (this) {
        GrupoArticoli.determinati => const {
            CategoriaArticulo.determinado,
            CategoriaArticulo.plural,
          },
        GrupoArticoli.indeterminati => const {
            CategoriaArticulo.indeterminado,
            CategoriaArticulo.partitivo,
            CategoriaArticulo.partitivoPlural,
          },
        GrupoArticoli.todos => const {
            CategoriaArticulo.determinado,
            CategoriaArticulo.plural,
            CategoriaArticulo.indeterminado,
            CategoriaArticulo.partitivo,
            CategoriaArticulo.partitivoPlural,
          },
      };
}

/// Práctica de artículos: se muestra un sustantivo italiano y hay que elegir
/// el artículo que le corresponde tocando un botón.
///
/// Cuál es la categoría que toca se ve en el artículo de la pregunta en
/// español: "la mochila" pide el determinado, "una mochila" el indeterminado,
/// "las mochilas" el plural y "algo de pan" el partitivo.
///
/// Arriba se elige con qué familia practicar: los determinados, los
/// indeterminados (con el partitivo adentro) o las dos mezcladas.
class PantallaArticoli extends StatefulWidget {
  const PantallaArticoli({super.key, this.repositorio, this.categorias});

  /// Inyectable para los tests.
  final RepositorioArticoli? repositorio;

  /// Con qué categorías arranca. Por defecto, todas. Los tests la usan para
  /// fijar una sola y poder afirmar cuál es la respuesta.
  final Set<CategoriaArticulo>? categorias;

  @override
  State<PantallaArticoli> createState() => _PantallaArticoliState();
}

class _PantallaArticoliState extends State<PantallaArticoli> {
  late final RepositorioArticoli _repositorio =
      widget.repositorio ?? RepositorioArticoli();
  final _azar = Random();

  late Set<CategoriaArticulo> _categorias =
      widget.categorias ?? GrupoArticoli.todos.categorias;

  List<Consigna> _posibles = const [];
  Consigna? _actual;
  String _elegido = '';
  bool _mostrandoResultado = false;
  int _puntaje = 0;
  int _total = 0;
  String _mensaje = 'Cargando palabras...';

  @override
  void initState() {
    super.initState();
    _empezar();
  }

  Future<void> _empezar() async {
    await _repositorio.cargar();
    if (!mounted) return;
    _rearmar();
  }

  void _rearmar() {
    _posibles =
        consignasPosibles(_repositorio.datos.sustantivos, _categorias);
    _nueva();
  }

  bool _esGrupo(GrupoArticoli grupo) =>
      setEquals(_categorias, grupo.categorias);

  /// Cambiar de familia trae una pregunta nueva: la que estaba en pantalla es
  /// de la otra. El puntaje sigue, que es de la sesión y no del grupo.
  void _cambiarGrupo(GrupoArticoli grupo) {
    if (_esGrupo(grupo)) return;
    setState(() {
      _categorias = grupo.categorias;
      _rearmar();
    });
  }

  void _abrirAyuda() {
    mostrarAyuda(
      context,
      titulo: 'Cómo funcionan los artículos',
      secciones: ayudaDeLosArticoli,
    );
  }

  void _nueva() {
    setState(() {
      _elegido = '';
      _mostrandoResultado = false;
      if (_posibles.isEmpty) {
        _actual = null;
        _mensaje = 'Todavía no hay palabras cargadas.';
        return;
      }
      // Se evita repetir la misma pregunta dos veces seguidas: con pocas
      // palabras pasa bastante y da la sensación de que no cambió nada.
      Consigna elegida;
      do {
        elegida = _posibles[_azar.nextInt(_posibles.length)];
      } while (_posibles.length > 1 &&
          elegida.palabra == _actual?.palabra &&
          elegida.categoria == _actual?.categoria);
      _actual = elegida;
    });
  }

  void _tocarArticulo(String articulo) {
    if (_mostrandoResultado) return;
    setState(() => _elegido = articulo);
  }

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nueva();
      return;
    }
    if (_elegido.isEmpty || _actual == null) return;
    setState(() {
      _total++;
      if (_acerto) _puntaje++;
      _mostrandoResultado = true;
    });
  }

  bool get _acerto => _actual != null && _elegido == _actual!.correcto;

  @override
  Widget build(BuildContext context) {
    final actual = _actual;
    if (actual == null) {
      return Column(
        children: [
          const SizedBox(height: 10),
          _encabezado(),
          Expanded(
            child: Center(
              child: Text(
                _mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _encabezado(),
          const SizedBox(height: 12),
          TarjetaPregunta(
            etiqueta: '¿Cómo se dice?',
            texto: actual.pregunta,
            alto: 118,
          ),
          const SizedBox(height: 14),
          _respuesta(actual),
          const SizedBox(height: 16),
          _botonesArticulo(actual),
          const SizedBox(height: 10),
          // Alto mínimo para que el botón no salte al aparecer la explicación,
          // pero que pueda crecer: con alto fijo la explicación larga quedaba
          // tapada por el botón.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: _explicacion(actual),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _elegido.isEmpty ? null : _accionBoton,
              style: Tema.botonPrincipal,
              child: Text(
                _mostrandoResultado ? 'Siguiente' : 'Verificar',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Puntaje, las tres familias y el botón de la explicación.
  Widget _encabezado() {
    return Column(
      children: [
        ChipPuntaje(puntaje: _puntaje, total: _total),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Las tres pastillas pasan a dos renglones si no entran, en vez de
            // salirse del borde: "Indeterminati" es larga y en un celular
            // angosto la última quedaba cortada.
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final grupo in GrupoArticoli.values)
                    Pastilla(
                      texto: grupo.etiqueta,
                      activa: _esGrupo(grupo),
                      alTocar: () => _cambiarGrupo(grupo),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 34,
              height: 34,
              child: IconButton(
                onPressed: _abrirAyuda,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.info_outline),
                color: Tema.verde,
                tooltip: 'Cómo funcionan los artículos',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// El renglón con el artículo elegido y la palabra: "· · ·  zaino" antes de
  /// elegir, "lo zaino" después.
  Widget _respuesta(Consigna actual) {
    final sinElegir = _elegido.isEmpty;
    final color = !_mostrandoResultado
        ? Tema.texto
        : _acerto
            ? Tema.correcto
            : Tema.incorrecto;

    return Container(
      height: 62,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(
          color: sinElegir ? Tema.borde : color,
          width: sinElegir ? 1.5 : 2,
        ),
      ),
      child: TextoAjustado(
        sinElegir
            ? '· · ·  ${actual.palabra}'
            : unir(_elegido, actual.palabra),
        estilo: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: sinElegir ? Tema.textoTenue : color,
        ),
      ),
    );
  }

  Widget _botonesArticulo(Consigna actual) => FilaOpciones(
        opciones: actual.categoria.opciones,
        elegido: _elegido,
        correcta: actual.correcto,
        mostrandoResultado: _mostrandoResultado,
        onTocar: _tocarArticulo,
      );

  /// Por qué va ese artículo. Es lo que convierte el ejercicio en algo que se
  /// aprende, en vez de adivinar.
  Widget _explicacion(Consigna actual) {
    if (!_mostrandoResultado) return const SizedBox.shrink();

    final sustantivo = actual.sustantivo;
    final regla = sustantivo.nota.isEmpty
        ? sustantivo.clase.explicacion
        : '${sustantivo.clase.explicacion}. ${sustantivo.nota}';
    final ayuda = actual.categoria.ayuda;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _acerto ? Icons.check_circle : Icons.cancel,
              color: _acerto ? Tema.correcto : Tema.incorrecto,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _acerto ? '¡Correcto!' : 'Va ${actual.respuesta}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _acerto ? Tema.correcto : Tema.incorrecto,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          regla,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Tema.textoTenue),
        ),
        if (ayuda.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            ayuda,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontStyle: FontStyle.italic,
              color: Tema.textoTenue,
            ),
          ),
        ],
      ],
    );
  }
}

/// Lo que explica el botón de info. Es la tabla entera de los artículos: la
/// que hay que tener a mano mientras se practica.
const List<SeccionAyuda> ayudaDeLosArticoli = [
  SeccionAyuda(
    titulo: 'Los determinados (el, la, los, las)',
    cuerpo: 'Cuál va depende de con qué letra empieza la palabra, no de lo '
        'que significa.',
    ejemplos: [
      'il libro · i libri (masculino con consonante)',
      "lo zaino · gli zaini (masculino con s impura, z, gn, ps, pn, x, y)",
      "l'amico · gli amici (masculino con vocal)",
      'la casa · le case (femenino con consonante)',
      "l'amica · le amiche (femenino con vocal)",
    ],
  ),
  SeccionAyuda(
    titulo: 'Cuándo va lo y no il',
    cuerpo: 'Es la parte que más cuesta. Van con lo (y en plural con gli) las '
        'masculinas que empiezan con:',
    ejemplos: [
      's + consonante: lo studente, lo sport, lo specchio',
      'z: lo zaino, lo zucchero',
      'gn, ps, pn: lo gnocco, lo psicologo, lo pneumatico',
      'x, y: lo xilofono, lo yogurt',
      'i + vocal: lo iodio',
    ],
  ),
  SeccionAyuda(
    titulo: 'Los indeterminados (un, una)',
    cuerpo: 'Siguen la misma división, pero el masculino con vocal NO lleva '
        'apóstrofo y el femenino con vocal SÍ. Es el error más común.',
    ejemplos: [
      'un libro, un amico (sin apóstrofo)',
      'uno zaino, uno studente',
      'una casa',
      "un'amica (con apóstrofo, solo el femenino)",
    ],
  ),
  SeccionAyuda(
    titulo: 'El partitivo: di pegado al determinado',
    cuerpo: 'Sirve para dos cosas que el italiano no dice de otra manera: '
        '"algo de" con lo que no se cuenta, y "unos/unas" en plural.',
    ejemplos: [
      'di + il = del · del pane (algo de pan)',
      'di + lo = dello · dello zucchero',
      'di + la = della · della carne',
      "di + l' = dell' · dell'acqua",
      'di + i = dei · dei libri (unos libros)',
      'di + gli = degli · degli amici',
      'di + le = delle · delle case',
    ],
  ),
  SeccionAyuda(
    titulo: 'El género no siempre coincide con el español',
    cuerpo: 'Son las que más hacen tropezar: la palabra es de un género en '
        'español y del otro en italiano.',
    ejemplos: [
      'il tavolo = la mesa',
      'la macchina = el auto',
      'il latte = la leche',
      'la mano = la mano (femenina aunque termine en -o)',
    ],
  ),
];

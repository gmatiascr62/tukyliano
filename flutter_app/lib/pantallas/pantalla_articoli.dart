import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/repositorio_articoli.dart';
import '../logica/articulos.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/texto_ajustado.dart';

/// Práctica de artículos: se muestra un sustantivo italiano y hay que elegir
/// el artículo que le corresponde tocando un botón.
///
/// Se mezclan las tres categorías (determinado, indeterminado y plural). Cuál
/// es la que toca se ve en el artículo de la pregunta en español: "la mochila"
/// pide el determinado, "una mochila" el indeterminado y "las mochilas" el
/// plural. Por eso no hace falta ningún selector.
class PantallaArticoli extends StatefulWidget {
  const PantallaArticoli({super.key, this.repositorio, this.categorias});

  /// Inyectable para los tests.
  final RepositorioArticoli? repositorio;

  /// Qué categorías entran en la mezcla. Por defecto las tres. Está acá por si
  /// más adelante se quiere practicar una sola.
  final Set<CategoriaArticulo>? categorias;

  @override
  State<PantallaArticoli> createState() => _PantallaArticoliState();
}

class _PantallaArticoliState extends State<PantallaArticoli> {
  late final RepositorioArticoli _repositorio =
      widget.repositorio ?? RepositorioArticoli();
  final _azar = Random();

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
    _posibles = consignasPosibles(
      _repositorio.datos.sustantivos,
      widget.categorias ?? CategoriaArticulo.values.toSet(),
    );
    _nueva();
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
      return Center(
        child: Text(
          _mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(child: ChipPuntaje(puntaje: _puntaje, total: _total)),
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

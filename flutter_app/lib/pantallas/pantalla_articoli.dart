import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/repositorio_articoli.dart';
import '../logica/articulos.dart';
import '../modelos/articulo.dart';
import '../tema.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/texto_ajustado.dart';

/// Práctica de artículos determinados: se muestra un sustantivo italiano y
/// hay que elegir el artículo que le corresponde tocando un botón.
///
/// Por ahora solo el determinado (il / lo / la / l'). El JSON ya trae también
/// el indeterminado y el plural para cuando se agreguen.
class PantallaArticoli extends StatefulWidget {
  const PantallaArticoli({super.key, this.repositorio});

  /// Inyectable para los tests.
  final RepositorioArticoli? repositorio;

  @override
  State<PantallaArticoli> createState() => _PantallaArticoliState();
}

class _PantallaArticoliState extends State<PantallaArticoli> {
  late final RepositorioArticoli _repositorio =
      widget.repositorio ?? RepositorioArticoli();
  final _azar = Random();

  Sustantivo? _actual;
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
    _nueva();
  }

  void _nueva() {
    final palabras = _repositorio.datos.sustantivos;
    setState(() {
      _elegido = '';
      _mostrandoResultado = false;
      if (palabras.isEmpty) {
        _actual = null;
        _mensaje = 'Todavía no hay palabras cargadas.';
        return;
      }
      // Se evita repetir la misma palabra dos veces seguidas: con pocas
      // palabras pasa bastante y da la sensación de que no cambió nada.
      Sustantivo elegida;
      do {
        elegida = palabras[_azar.nextInt(palabras.length)];
      } while (palabras.length > 1 && elegida.italiano == _actual?.italiano);
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

  bool get _acerto =>
      _actual != null && _elegido == _actual!.clase.determinativo;

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
            texto: conArticuloEspanol(actual),
            alto: 118,
          ),
          const SizedBox(height: 14),
          _respuesta(actual),
          const SizedBox(height: 16),
          _botonesArticulo(),
          const SizedBox(height: 10),
          // Alto fijo para que aparecer la explicación no mueva el botón.
          SizedBox(height: 76, child: _explicacion(actual)),
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
  Widget _respuesta(Sustantivo actual) {
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
            ? '· · ·  ${actual.italiano}'
            : unir(_elegido, actual.italiano),
        estilo: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: sinElegir ? Tema.textoTenue : color,
        ),
      ),
    );
  }

  Widget _botonesArticulo() {
    return Row(
      children: [
        for (final articulo in articulosDeterminados) ...[
          Expanded(
            child: _BotonArticulo(
              articulo: articulo,
              elegido: _elegido == articulo,
              // Al contestar se marca cuál era la correcta, aunque no sea la
              // que se tocó.
              correcto: _mostrandoResultado &&
                  articulo == _actual!.clase.determinativo,
              habilitado: !_mostrandoResultado,
              onTocar: () => _tocarArticulo(articulo),
            ),
          ),
          if (articulo != articulosDeterminados.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Por qué va ese artículo. Es lo que convierte el ejercicio en algo que se
  /// aprende, en vez de adivinar.
  Widget _explicacion(Sustantivo actual) {
    if (!_mostrandoResultado) return const SizedBox.shrink();

    final correcto = unir(actual.clase.determinativo, actual.italiano);
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
                _acerto ? '¡Correcto!' : 'Va $correcto',
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
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            actual.nota.isEmpty
                ? actual.clase.explicacion
                : '${actual.clase.explicacion}. ${actual.nota}',
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, color: Tema.textoTenue),
          ),
        ),
      ],
    );
  }
}

class _BotonArticulo extends StatelessWidget {
  const _BotonArticulo({
    required this.articulo,
    required this.elegido,
    required this.correcto,
    required this.habilitado,
    required this.onTocar,
  });

  final String articulo;
  final bool elegido;
  final bool correcto;
  final bool habilitado;
  final VoidCallback onTocar;

  @override
  Widget build(BuildContext context) {
    final fondo = correcto
        ? Tema.correcto
        : elegido
            ? Tema.verde
            : Tema.superficie;
    final colorTexto = correcto || elegido ? Colors.white : Tema.titulo;

    return SizedBox(
      height: 56,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: InkWell(
          onTap: habilitado ? onTocar : null,
          borderRadius: BorderRadius.circular(Tema.radio),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tema.radio),
              border: Border.all(
                color: correcto || elegido ? Colors.transparent : Tema.borde,
              ),
            ),
            child: Text(
              articulo,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

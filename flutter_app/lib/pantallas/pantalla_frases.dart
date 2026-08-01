import 'package:flutter/material.dart';

import '../constantes.dart';
import '../datos/repositorio_frases.dart';
import '../logica/correccion.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';
import '../widgets/texto_ajustado.dart';

/// Práctica de frases: se muestra una oración en español y el alumno la
/// escribe en italiano. Las frases vienen de frases.json, y al verificar se
/// muestra la respuesta correcta con cada palabra en verde o en rojo.
class PantallaFrases extends StatefulWidget {
  const PantallaFrases({
    super.key,
    required this.verbos,
    required this.tiempos,
    this.frasesLocales,
  });

  final List<Verbo> verbos;
  final List<String> tiempos;

  /// Inyectable para los tests.
  final RepositorioFrases? frasesLocales;

  @override
  State<PantallaFrases> createState() => _PantallaFrasesState();
}

class _PantallaFrasesState extends State<PantallaFrases> {
  late final RepositorioFrases _frases =
      widget.frasesLocales ?? RepositorioFrases();

  String _fraseEs = '';
  String _italianoReferencia = '';
  String _pista = '';
  bool _mostrandoPista = false;
  String _textoActual = '';
  String _mensajePantalla = 'Buscando una frase...';

  /// Vacío mientras no se verificó. Después trae la respuesta correcta con
  /// cada palabra marcada.
  List<PalabraCorregida> _correccion = [];

  bool _ocupado = true;
  bool _mostrandoResultado = false;

  @override
  void initState() {
    super.initState();
    _nuevaFrase();
  }

  Future<void> _nuevaFrase() async {
    setState(() {
      _mensajePantalla = 'Buscando una frase...';
      _fraseEs = '';
      _pista = '';
      _mostrandoPista = false;
      _textoActual = '';
      _correccion = [];
      _mostrandoResultado = false;
      _ocupado = true;
    });

    await _frases.cargar();
    if (!mounted) return;

    // Solo se sortean las formas que tienen frase guardada. Se descarta la
    // frase cuyo italiano no traiga la conjugación esperada, que es la red de
    // contención para el JSON remoto.
    bool conFrase(Combo combo) => _frases.tieneFrase(
          verbo: combo.verbo.nombre,
          tiempo: combo.tiempo,
          persona: combo.persona,
          conjugacionItaliana: combo.conjugacion.italiano,
        );

    var combo = elegirComboFiltrado(widget.verbos, widget.tiempos, conFrase);
    combo ??= elegirComboFiltrado(widget.verbos, tiemposDisponibles, conFrase);
    if (combo == null) {
      setState(() {
        _mensajePantalla = 'Todavía no hay frases para estos verbos.';
        _ocupado = false;
      });
      return;
    }

    final frase = _frases.elegir(
      verbo: combo.verbo.nombre,
      tiempo: combo.tiempo,
      persona: combo.persona,
      conjugacionItaliana: combo.conjugacion.italiano,
    )!;

    setState(() {
      _fraseEs = frase.espanol;
      _italianoReferencia = frase.italiano;
      _pista = frase.pista;
      _ocupado = false;
    });
  }

  void _onTecla(String tecla) {
    setState(() => _textoActual = aplicarTecla(_textoActual, tecla));
  }

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nuevaFrase();
    } else {
      _verificar();
    }
  }

  void _verificar() {
    if (_textoActual.trim().isEmpty || _fraseEs.isEmpty) return;

    setState(() {
      _correccion = corregir(
        correcta: _italianoReferencia,
        respuesta: _textoActual,
      );
      _mostrandoResultado = true;
    });
  }

  /// La pista viene con la frase, así que mostrarla no cuesta nada: solo se
  /// revela si el alumno la pide.
  Widget _pistaWidget() {
    if (_pista.isEmpty || _fraseEs.isEmpty) return const SizedBox.shrink();
    if (_mostrandoPista) {
      return Text(
        _pista,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Tema.verdeOscuro,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => setState(() => _mostrandoPista = true),
      icon: const Icon(Icons.lightbulb_outline, size: 18),
      label: const Text('Pista'),
      style: TextButton.styleFrom(foregroundColor: Tema.verde),
    );
  }

  /// La respuesta correcta, con cada palabra en verde si la escribió y en rojo
  /// si no. La letra se achica si no entra, así nunca queda cortada.
  Widget _respuestaWidget() {
    if (_correccion.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          todoAcertado(_correccion) ? Icons.check_circle : Icons.cancel,
          color: todoAcertado(_correccion) ? Tema.correcto : Tema.incorrecto,
          size: 20,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextoAjustado(
            _correccion.map((p) => p.palabra).join(' '),
            // Un renglón, como el campo de arriba, y con el mismo criterio:
            // antes letra chica que texto cortado.
            tamanoMinimo: 8,
            estilo: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            trozos: [
              for (var i = 0; i < _correccion.length; i++)
                TextSpan(
                  text: i == 0
                      ? _correccion[i].palabra
                      : ' ${_correccion[i].palabra}',
                  style: TextStyle(
                    color: _correccion[i].acertada
                        ? Tema.correcto
                        : Tema.incorrecto,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                TarjetaPregunta(
                  etiqueta: _fraseEs.isEmpty ? '' : 'Escribí en italiano',
                  texto: _fraseEs.isEmpty ? _mensajePantalla : "'$_fraseEs'",
                ),
                const SizedBox(height: 14),
                CampoTexto(
                  texto: _textoActual,
                  placeholderTexto: 'Escribí la traducción...',
                ),
                // Alto fijo, igual que la respuesta, para que mostrar la pista
                // no mueva el resto de la pantalla.
                SizedBox(height: 36, child: Center(child: _pistaWidget())),
                // Alto fijo siempre, para que el layout no salte al aparecer
                // el texto (el bug que tuvo la versión Kivy).
                SizedBox(height: 40, child: Center(child: _respuestaWidget())),
                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _ocupado ? null : _accionBoton,
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
          ),
        ),
        Teclado(onTecla: _onTecla),
      ],
    );
  }
}

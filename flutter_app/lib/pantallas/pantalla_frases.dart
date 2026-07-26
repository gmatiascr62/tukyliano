import 'package:flutter/material.dart';

import '../constantes.dart';
import '../ia/gemini.dart';
import '../ia/prompts.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';

/// Práctica de frases: la IA genera una oración corta en español y corrige la
/// traducción al italiano. Equivale a PantallaFrases de la app Kivy.
class PantallaFrases extends StatefulWidget {
  const PantallaFrases({
    super.key,
    required this.verbos,
    required this.tiempos,
    required this.apiKey,
    required this.onClaveInvalida,
    this.gemini,
  });

  final List<Verbo> verbos;
  final List<String> tiempos;
  final String apiKey;

  /// Se llama cuando Gemini rechaza la clave: hay que borrarla y pedir otra.
  final VoidCallback onClaveInvalida;

  /// Inyectable para los tests.
  final Gemini? gemini;

  @override
  State<PantallaFrases> createState() => _PantallaFrasesState();
}

class _PantallaFrasesState extends State<PantallaFrases> {
  late final Gemini _gemini = widget.gemini ?? Gemini();

  String _fraseEs = '';
  String _italianoReferencia = '';
  String _textoActual = '';
  String _feedback = '';
  Color _colorFeedback = Tema.texto;
  double _tamanoFeedback = 18;
  String _mensajePantalla = 'Generando frase...';

  bool _ocupado = true;
  bool _mostrandoResultado = false;

  @override
  void initState() {
    super.initState();
    _nuevaFrase();
  }

  Future<void> _nuevaFrase() async {
    setState(() {
      _mensajePantalla = 'Generando frase...';
      _fraseEs = '';
      _textoActual = '';
      _feedback = '';
      _mostrandoResultado = false;
      _ocupado = true;
    });

    var combo = elegirComboAzar(widget.verbos, widget.tiempos);
    combo ??= elegirComboAzar(widget.verbos, tiemposDisponibles);
    if (combo == null) {
      setState(() {
        _mensajePantalla = 'No hay verbos con datos cargados.';
        _ocupado = false;
      });
      return;
    }

    try {
      final frase = await generarFrase(
        _gemini,
        widget.apiKey,
        verbo: combo.verbo.nombre,
        traduccion: combo.verbo.traduccion,
        tiempo: combo.tiempo,
        persona: combo.persona,
        conjugacionItaliana: combo.conjugacion.italiano,
      );
      if (!mounted) return;
      setState(() {
        _fraseEs = frase.espanol;
        _italianoReferencia = frase.italiano;
        _ocupado = false;
      });
    } on ClaveInvalidaError {
      if (!mounted) return;
      widget.onClaveInvalida();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensajePantalla = 'No se pudo generar la frase. Revisá tu conexión.';
        _ocupado = false;
      });
    }
  }

  void _onTecla(String tecla) {
    setState(() => _textoActual = aplicarTecla(_textoActual, tecla));
  }

  Future<void> _accionBoton() async {
    if (_mostrandoResultado) {
      await _nuevaFrase();
    } else {
      await _verificar();
    }
  }

  Future<void> _verificar() async {
    final respuesta = _textoActual.trim();
    if (respuesta.isEmpty || _fraseEs.isEmpty) return;

    setState(() {
      _ocupado = true;
      _feedback = 'Verificando...';
      _colorFeedback = Tema.textoTenue;
      _tamanoFeedback = 18;
    });

    try {
      final correcto = await verificarFrase(
        _gemini,
        widget.apiKey,
        fraseEs: _fraseEs,
        italianoReferencia: _italianoReferencia,
        respuestaUsuario: respuesta,
      );
      if (!mounted) return;
      setState(() {
        if (correcto) {
          _feedback = '¡Correcto!';
          _colorFeedback = Tema.correcto;
          _tamanoFeedback = 18;
        } else {
          // Solo la frase correcta, sin el "Incorrecto. Era:".
          _feedback = _italianoReferencia;
          _colorFeedback = Tema.incorrecto;
          _tamanoFeedback = 15;
        }
        _mostrandoResultado = true;
        _ocupado = false;
      });
    } on ClaveInvalidaError {
      if (!mounted) return;
      widget.onClaveInvalida();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = 'No se pudo verificar. Probá de nuevo.';
        _colorFeedback = Tema.incorrecto;
        _tamanoFeedback = 15;
        _ocupado = false;
      });
    }
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
                // Alto fijo siempre, para que el layout no salte al aparecer
                // el texto (el bug que tuvo la versión Kivy).
                SizedBox(
                  height: 40,
                  child: Center(
                    child: TextoFeedback(
                      texto: _feedback,
                      color: _colorFeedback,
                      tamano: _tamanoFeedback,
                    ),
                  ),
                ),
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

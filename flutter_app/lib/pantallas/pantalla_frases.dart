import 'package:flutter/material.dart';

import '../constantes.dart';
import '../ia/gemini.dart';
import '../ia/prompts.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
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
  double _tamanoFeedback = 20;
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
      _tamanoFeedback = 20;
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
          _tamanoFeedback = 20;
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
                SizedBox(
                  height: 130,
                  child: Center(
                    child: Text(
                      _fraseEs.isEmpty
                          ? _mensajePantalla
                          : "Escribí en italiano:\n'$_fraseEs'",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: Tema.titulo),
                    ),
                  ),
                ),
                CampoTexto(
                  texto: _textoActual,
                  placeholderTexto: 'Escribí la traducción...',
                ),
                // Alto fijo siempre, para que el layout no salte al aparecer
                // el texto (el bug que tuvo la versión Kivy).
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Text(
                      _feedback,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _tamanoFeedback,
                        color: _colorFeedback,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 65,
                  child: ElevatedButton(
                    onPressed: _ocupado ? null : _accionBoton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Tema.boton,
                      foregroundColor: Tema.textoBoton,
                      disabledBackgroundColor: const Color(0xFF9E9E9E),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: Text(
                      _mostrandoResultado ? 'Siguiente' : 'Verificar',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Teclado(onTecla: _onTecla),
      ],
    );
  }
}

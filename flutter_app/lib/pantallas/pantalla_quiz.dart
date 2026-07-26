import 'package:flutter/material.dart';

import '../constantes.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';

/// Quiz de conjugaciones. Equivale a QuizVerbos de la app Kivy.
class PantallaQuiz extends StatefulWidget {
  const PantallaQuiz({
    super.key,
    required this.verbos,
    required this.tiempos,
    required this.estado,
  });

  final List<Verbo> verbos;
  final List<String> tiempos;

  /// Mensaje del chequeo de verbos nuevos.
  final String estado;

  @override
  State<PantallaQuiz> createState() => _PantallaQuizState();
}

class _PantallaQuizState extends State<PantallaQuiz> {
  int _puntaje = 0;
  int _total = 0;
  String _textoActual = '';
  String _feedback = '';
  Color _colorFeedback = Tema.texto;
  bool _mostrandoResultado = false;

  Combo? _combo;
  String _mensajeSinDatos = '';

  @override
  void initState() {
    super.initState();
    _nuevaPregunta();
  }

  void _nuevaPregunta() {
    // Si ningún verbo tiene datos para los tiempos elegidos, se prueba con
    // cualquier tiempo antes de darse por vencido, igual que en Kivy.
    var combo = elegirComboAzar(widget.verbos, widget.tiempos);
    combo ??= elegirComboAzar(widget.verbos, tiemposDisponibles);

    setState(() {
      _combo = combo;
      _mensajeSinDatos = combo == null
          ? 'No hay verbos con datos cargados.\nRevisá verbos.json / data.json.'
          : '';
      _textoActual = '';
      _feedback = '';
      _mostrandoResultado = false;
    });
  }

  void _onTecla(String tecla) {
    setState(() => _textoActual = aplicarTecla(_textoActual, tecla));
  }

  void _accionBoton() {
    if (_mostrandoResultado) {
      _nuevaPregunta();
    } else {
      _verificar();
    }
  }

  void _verificar() {
    final respuesta = _textoActual.trim().toLowerCase();
    if (respuesta.isEmpty || _combo == null) return;

    final correcta = _combo!.conjugacion.italiano.toLowerCase();
    final acerto = respuesta == correcta;

    setState(() {
      _total++;
      if (acerto) {
        _puntaje++;
        _feedback = '¡Correcto!';
        _colorFeedback = Tema.correcto;
      } else {
        _feedback = 'Incorrecto. Era: $correcta';
        _colorFeedback = Tema.incorrecto;
      }
      _mostrandoResultado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Todo lo de arriba va en un scroll que ocupa el espacio sobrante:
        // en un celular normal se ve igual (contenido arriba, teclado abajo),
        // y en una pantalla baja scrollea en vez de romperse.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(child: ChipPuntaje(puntaje: _puntaje, total: _total)),
                if (widget.estado.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      widget.estado,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TarjetaPregunta(
                  etiqueta: _combo == null ? '' : 'Traducí al italiano',
                  texto: _combo == null
                      ? _mensajeSinDatos
                      : "'${_combo!.conjugacion.espanol}'",
                ),
                const SizedBox(height: 14),
                CampoTexto(texto: _textoActual),
                // Alto fijo siempre: si cambiara al aparecer el texto, se
                // recalcularía el layout entero (el bug que tuvo Kivy).
                SizedBox(
                  height: 40,
                  child: Center(
                    child: TextoFeedback(
                      texto: _feedback,
                      color: _colorFeedback,
                    ),
                  ),
                ),
                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _accionBoton,
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

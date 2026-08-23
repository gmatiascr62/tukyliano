import 'package:flutter/material.dart';

import '../constantes.dart';
import '../logica/modo_respuesta.dart';
import '../logica/opciones_conjugacion.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/boton_opcion.dart';
import '../widgets/campo_texto.dart';
import '../widgets/pastilla.dart';
import '../widgets/tarjeta_pregunta.dart';
import '../widgets/teclado.dart';

/// Quiz de conjugaciones. Equivale a QuizVerbos de la app Kivy.
///
/// Se puede contestar de dos formas, igual que en la sección Via: tocando cuál
/// de cuatro formas del mismo verbo es la que va, o escribiéndola entera. La
/// primera sirve para reconocer la terminación cuando todavía no sale sola; la
/// segunda es la de verdad, porque hablando nadie te ofrece opciones.
class PantallaQuiz extends StatefulWidget {
  const PantallaQuiz({
    super.key,
    required this.verbos,
    required this.tiempos,
  });

  final List<Verbo> verbos;
  final List<String> tiempos;

  /// Mensaje del chequeo de verbos nuevos.

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

  ModoRespuesta _modo = ModoRespuesta.escribir;

  /// Los cuatro botones del modo de elegir. Se sortean una vez por pregunta:
  /// si se recalcularan en cada build, cambiarían de lugar solos.
  List<String> _opciones = const [];
  String _elegida = '';

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
      _opciones = combo == null ? const [] : opcionesDeConjugacion(combo);
      _limpiar();
    });
  }

  void _limpiar() {
    _textoActual = '';
    _elegida = '';
    _feedback = '';
    _mostrandoResultado = false;
  }

  /// Cambiar de modo deja la misma pregunta pero borra lo contestado: pasar a
  /// escribir con la respuesta ya elegida sería copiarla.
  void _cambiarModo(ModoRespuesta modo) {
    if (modo == _modo) return;
    setState(() {
      _modo = modo;
      _limpiar();
    });
  }

  /// Si hay algo contestado. Con el botón siempre activo, tocar "Verificar"
  /// sin contestar no hacía nada y parecía que la app se había colgado.
  bool get _hayRespuesta => _modo == ModoRespuesta.elegir
      ? _elegida.isNotEmpty
      : _textoActual.trim().isNotEmpty;

  void _tocarOpcion(String opcion) {
    if (_mostrandoResultado) return;
    setState(() => _elegida = opcion);
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
    final respuesta = _modo == ModoRespuesta.elegir
        ? _elegida.toLowerCase()
        : _textoActual.trim().toLowerCase();
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
                const SizedBox(height: 10),
                _encabezado(),
                const SizedBox(height: 12),
                TarjetaPregunta(
                  etiqueta: _combo == null ? '' : 'Traducí al italiano',
                  texto: _combo == null
                      ? _mensajeSinDatos
                      : "'${_combo!.conjugacion.espanol}'",
                ),
                const SizedBox(height: 14),
                if (_modo == ModoRespuesta.escribir)
                  CampoTexto(texto: _textoActual)
                else if (_opciones.isNotEmpty)
                  FilaOpciones(
                    opciones: _opciones,
                    elegido: _elegida,
                    correcta: _combo?.conjugacion.italiano ?? '',
                    mostrandoResultado: _mostrandoResultado,
                    onTocar: _tocarOpcion,
                  ),
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
                    onPressed:
                        _hayRespuesta || _mostrandoResultado ? _accionBoton : null,
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
        if (_modo == ModoRespuesta.escribir) Teclado(onTecla: _onTecla),
      ],
    );
  }

  /// Puntaje y las dos formas de contestar.
  Widget _encabezado() {
    return Column(
      children: [
        ChipPuntaje(puntaje: _puntaje, total: _total),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final modo in ModoRespuesta.values) ...[
              Pastilla(
                texto: modo.etiqueta,
                activa: _modo == modo,
                alTocar: () => _cambiarModo(modo),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ],
    );
  }
}

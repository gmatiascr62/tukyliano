import 'package:flutter/material.dart';

import '../constantes.dart';
import '../logica/seleccion_azar.dart';
import '../modelos/verbo.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';
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
    final pregunta = _combo == null
        ? _mensajeSinDatos
        : "¿Cómo se dice\n'${_combo!.conjugacion.espanol}'?";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Todo lo de arriba va en un scroll que ocupa el espacio sobrante:
        // en un celular normal se ve igual que antes (contenido arriba,
        // teclado abajo), y en una pantalla baja scrollea en vez de romperse.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _contenido(pregunta),
            ),
          ),
        ),
        Teclado(onTecla: _onTecla),
      ],
    );
  }

  List<Widget> _contenido(String pregunta) {
    return [
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              'Puntaje: $_puntaje/$_total',
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
          ),
        ),
        if (widget.estado.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.estado,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
            ),
          ),
        SizedBox(
          height: 130,
          child: Center(
            child: Text(
              pregunta,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Tema.titulo),
            ),
          ),
        ),
        CampoTexto(texto: _textoActual),
        // Alto fijo siempre: si cambiara al aparecer el texto, se recalcularía
        // el layout de toda la pantalla (el bug que tuvo la versión Kivy).
        SizedBox(
          height: 36,
          child: Center(
            child: Text(
              _feedback,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: _colorFeedback),
            ),
          ),
        ),
        SizedBox(
          height: 65,
          child: ElevatedButton(
            onPressed: _accionBoton,
            style: ElevatedButton.styleFrom(
              backgroundColor: Tema.boton,
              foregroundColor: Tema.textoBoton,
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              _mostrandoResultado ? 'Siguiente' : 'Verificar',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
    ];
  }
}

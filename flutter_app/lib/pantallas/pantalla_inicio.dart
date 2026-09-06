import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../logica/nivel.dart';
import '../tema.dart';

/// A dónde lleva cada uno de los cuatro botones del inicio.
enum Destino { racconti, hablar, gramatica, chat }

extension EtiquetaDestino on Destino {
  String get etiqueta => switch (this) {
        Destino.racconti => 'Racconti',
        Destino.hablar => 'Parlare',
        Destino.gramatica => 'Gramática',
        Destino.chat => 'Chat',
      };

  IconData get icono => switch (this) {
        Destino.racconti => Icons.menu_book,
        Destino.hablar => Icons.mic,
        Destino.gramatica => Icons.school,
        Destino.chat => Icons.chat_bubble_outline,
      };
}

/// La primera pantalla: cuatro botones alrededor del nivel.
///
/// Reemplaza a la barra de diez botones que se deslizaba. Cuatro entran de una
/// y son enormes para el pulgar; las siete de gramática viven adentro de su
/// propio botón, que es donde se entiende que van juntas.
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({
    super.key,
    required this.progreso,
    required this.alElegir,
  });

  final Progreso progreso;
  final ValueChanged<Destino> alElegir;

  /// Cuánto se separan del centro los cuatro botones. El aro pasa justo por
  /// donde están, así que sale de la misma cuenta.
  static const double _separado = 110;

  @override
  Widget build(BuildContext context) {
    final nivel = nivelPara(progreso.aciertos);
    const lado = _separado * 2 + 172;

    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Tukyliano',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Tema.titulo,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: lado,
          height: lado,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: _separado * 2 * 1.4142,
                  height: _separado * 2 * 1.4142,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Tema.verdeSuave, width: 3),
                  ),
                ),
              ),
              Center(child: _AnilloDeNivel(nivel: nivel)),
              _enSuLugar(lado, -1, -1, Destino.racconti),
              _enSuLugar(lado, -1, 1, Destino.hablar),
              _enSuLugar(lado, 1, -1, Destino.gramatica),
              _enSuLugar(lado, 1, 1, Destino.chat),
            ],
          ),
        ),
        const Spacer(),
        Text(
          _cuantosDias(progreso.diasPracticados),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  String _cuantosDias(int cuantos) => switch (cuantos) {
        0 => 'Todavía no practicaste esta semana',
        1 => 'Practicaste 1 de los últimos $diasDeLaSemana días',
        _ => 'Practicaste $cuantos de los últimos $diasDeLaSemana días',
      };

  /// Los cuatro van en las diagonales, a la misma distancia del centro.
  Widget _enSuLugar(double lado, int fila, int columna, Destino destino) {
    const anchoDelBoton = 118.0;
    const altoDelCirculo = 88.0;
    final medio = lado / 2;

    return Positioned(
      left: medio + columna * _separado - anchoDelBoton / 2,
      top: medio + fila * _separado - altoDelCirculo / 2,
      child: _BotonRedondo(destino: destino, alTocar: () => alElegir(destino)),
    );
  }
}

/// El anillo con el nivel adentro. Lo que va pintado es lo que falta para el
/// nivel que sigue.
class _AnilloDeNivel extends StatelessWidget {
  const _AnilloDeNivel({required this.nivel});

  final Nivel nivel;

  @override
  Widget build(BuildContext context) {
    const tamano = 152.0;

    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // El fondo del anillo va aparte para que el círculo de adentro tape
          // el aro que pasa por atrás.
          Container(
            width: tamano,
            height: tamano,
            decoration: const BoxDecoration(
              color: Tema.fondo,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(
            width: tamano,
            height: tamano,
            child: CircularProgressIndicator(
              value: nivel.cuanto,
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              backgroundColor: Tema.borde,
              valueColor: const AlwaysStoppedAnimation(Tema.verde),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NIVEL ${nivel.numero}',
                style: const TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: Tema.verde,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                nivel.nombre,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Tema.titulo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({required this.destino, required this.alTocar});

  final Destino destino;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Tema.verde,
            shape: const CircleBorder(),
            elevation: 1.5,
            shadowColor: const Color(0x33000000),
            child: InkWell(
              onTap: alTocar,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 88,
                height: 88,
                child: Icon(destino.icono, size: 38, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            destino.etiqueta,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Tema.titulo,
            ),
          ),
        ],
      ),
    );
  }
}

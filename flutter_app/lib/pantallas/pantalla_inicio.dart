import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../logica/nivel.dart';
import '../tema.dart';
import '../widgets/texto_ajustado.dart';

/// A dónde se puede ir desde el inicio: los cuatro botones en diagonal,
/// más el podcast, que va en una barra aparte debajo.
enum Destino { racconti, hablar, gramatica, chat, podcast }

extension EtiquetaDestino on Destino {
  String get etiqueta => switch (this) {
        Destino.racconti => 'Racconti',
        Destino.hablar => 'Parlare',
        Destino.gramatica => 'Gramática',
        Destino.chat => 'Chat',
        Destino.podcast => 'Podcast',
      };

  IconData get icono => switch (this) {
        Destino.racconti => Icons.menu_book,
        Destino.hablar => Icons.mic,
        Destino.gramatica => Icons.school,
        Destino.chat => Icons.chat_bubble_outline,
        Destino.podcast => Icons.headphones,
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
        // El podcast no entra en las diagonales: son cuatro y la composición
        // es con cuatro. Va acá abajo, ancho, que además es donde cae el
        // pulgar sin estirarse.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _BarraDePodcast(alTocar: () => alElegir(Destino.podcast)),
        ),
        const SizedBox(height: 18),
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
              // "Principiante" no entra al tamaño de "Alunno" y se salía del
              // anillo. Se achica solo el que no entra, en vez de bajarle el
              // tamaño a todos.
              SizedBox(
                width: tamano - 44,
                child: TextoAjustado(
                  nivel.nombre,
                  estilo: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Tema.titulo,
                  ),
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


/// La entrada al podcast: ancha y debajo del anillo, para no romper la
/// composición de los cuatro botones en diagonal.
class _BarraDePodcast extends StatelessWidget {
  const _BarraDePodcast({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tema.verdeSuave,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.headphones, size: 20, color: Tema.verde),
              SizedBox(width: 10),
              Text(
                'Podcast',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Tema.verde,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

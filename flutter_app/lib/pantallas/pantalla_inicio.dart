import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../logica/nivel.dart';
import '../tema.dart';
import '../widgets/texto_ajustado.dart';
import 'acerca_de.dart';
import '../constantes.dart';

/// A dónde se puede ir desde el inicio: los cuatro botones en diagonal,
/// más el podcast y la radio, que van en barras aparte debajo.
enum Destino { racconti, hablar, gramatica, chat, podcast, radio }

extension EtiquetaDestino on Destino {
  String get etiqueta => switch (this) {
    Destino.racconti => 'Racconti',
    Destino.hablar => 'Parlare',
    Destino.gramatica => 'Gramática',
    Destino.chat => 'Chat',
    Destino.podcast => 'Escuchar',
    Destino.radio => 'Radio',
  };

  IconData get icono => switch (this) {
    Destino.racconti => Icons.menu_book,
    Destino.hablar => Icons.mic,
    Destino.gramatica => Icons.school,
    Destino.chat => Icons.chat_bubble_outline,
    Destino.podcast => Icons.headphones,
    Destino.radio => Icons.radio,
  };
}

/// Radio de las tarjetas de esta pantalla. Más redondeado que el del resto de
/// la app a propósito: es la pantalla que se ve primero.
const double _radio = 22;

/// Sombra de las tarjetas: baja, ancha y apenas visible.
const List<BoxShadow> _sombra = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 6)),
];

/// La primera pantalla: la semana arriba, cuatro botones alrededor del nivel.
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

  @override
  Widget build(BuildContext context) {
    final nivel = nivelPara(progreso.aciertos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El título va centrado y el botón de "acerca de" flotando a la
        // derecha, encima: así el título queda en el medio de la pantalla de
        // verdad y no en el medio de lo que sobra al costado del botón.
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                nombreDeLaApp,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Tema.titulo,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => mostrarAcercaDe(context),
                  icon: const Icon(Icons.info_outline),
                  color: Tema.textoTenue,
                  tooltip: 'Acerca de',
                ),
              ),
            ],
          ),
        ),
        _TarjetaDeLaSemana(progreso: progreso),
        Expanded(
          child: _Diagonales(nivel: nivel, alElegir: alElegir),
        ),
        const SizedBox(height: 14),
        _BarraDePodcast(alTocar: () => alElegir(Destino.podcast)),
        const SizedBox(height: 9),
        _BarraDeRadio(alTocar: () => alElegir(Destino.radio)),
      ],
    );
  }
}

/// Cuánto se separan del centro los cuatro botones, y cuánto mide cada uno.
/// El ancho es mayor que el círculo porque abajo va la etiqueta, que es más
/// larga que él.
const double _separado = 116;
const double _circulo = 96;
const double _anchoDelBoton = 124;
const double _anillo = 150;

/// Lo que ocupa la etiqueta de abajo del círculo: el espacio más el renglón.
/// Es fijo, y la etiqueta se achica para entrar: así los cuatro botones miden
/// exactamente lo mismo y la caja de la composición no miente.
const double _altoDeLaEtiqueta = 32;

/// Lo que mide la composición entera sin achicar nada.
const double _anchoNatural = _separado * 2 + _anchoDelBoton;
const double _altoNatural = _separado * 2 + _circulo + _altoDeLaEtiqueta;

/// El medio de la cruz de botones dentro de esa caja.
///
/// En horizontal es el medio de la caja. En vertical NO: abajo de los dos
/// círculos de abajo cuelga la etiqueta, así que el medio está más arriba que
/// el centro geométrico. El anillo va acá y no en el centro de la caja, o
/// quedaría unos puntos más abajo que los cuatro botones.
const double _cruzX = _anchoNatural / 2;
const double _cruzY = _separado + _circulo / 2;

/// Los cuatro botones alrededor del anillo.
///
/// Se dibuja siempre al mismo tamaño y después se achica entero para que
/// entre en lo que haya. Antes se dibujaba a tamaño fijo y listo: en un
/// celular más bajo que el mío —360 x 720— los de arriba se montaban sobre la
/// tarjeta de la semana y los de abajo sobre la barra del podcast. El Stack
/// va con Clip.none, así que nada lo frenaba; simplemente se derramaba.
///
/// Achicar la composición entera, y no cada pedazo por separado, es lo que
/// hace que no se desarme: las distancias, los círculos, las etiquetas y el
/// anillo bajan todos en la misma proporción y la cruz sigue siendo una cruz.
///
/// Con scaleDown solo se achica: en una pantalla grande se queda en su tamaño
/// en vez de estirarse hasta ocupar todo, que es lo que haría contain.
class _Diagonales extends StatelessWidget {
  const _Diagonales({required this.nivel, required this.alElegir});

  final Nivel nivel;
  final ValueChanged<Destino> alElegir;

  @override
  Widget build(BuildContext context) {
    return Center(
      // La clave es para los tests: con ella se puede preguntar qué pedazo de
      // pantalla le tocó, y verificar que los cuatro botones estén adentro.
      key: const ValueKey('los-botones'),
      // El aire de arriba y de abajo no es decorativo: sin él la composición
      // se achica justo hasta tocar la tarjeta de la semana y la barra del
      // podcast, y aunque no se monte, se ve apretada.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: _anchoNatural,
            height: _altoNatural,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _cruzX - _anillo / 2,
                  top: _cruzY - _anillo / 2,
                  child: _AnilloDeNivel(nivel: nivel),
                ),
                for (final (fila, columna, destino) in const [
                  (-1, -1, Destino.racconti),
                  (-1, 1, Destino.hablar),
                  (1, -1, Destino.gramatica),
                  (1, 1, Destino.chat),
                ])
                  Positioned(
                    left: _cruzX + columna * _separado - _anchoDelBoton / 2,
                    top: _cruzY + fila * _separado - _circulo / 2,
                    child: SizedBox(
                      // Para los tests: con la clave se puede preguntar dónde
                      // quedó dibujado cada botón.
                      key: ValueKey(destino),
                      width: _anchoDelBoton,
                      child: _BotonRedondo(
                        destino: destino,
                        alTocar: () => alElegir(destino),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Los últimos siete días, el de hoy a la derecha.
///
/// Antes esto era un renglón gris al pie que decía "practicaste 4 de los
/// últimos 7 días". Decía lo mismo, pero en el último lugar donde se mira.
/// Dibujado y arriba se lee de un vistazo, y el día vacío se ve.
class _TarjetaDeLaSemana extends StatelessWidget {
  const _TarjetaDeLaSemana({required this.progreso});

  final Progreso progreso;

  static const _iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final cuantos = progreso.diasPracticados;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(_radio),
        boxShadow: _sombra,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Esta semana',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Tema.titulo,
                  ),
                ),
              ),
              Text(
                // Un cero no se canta como cero: se invita.
                cuantos == 0
                    ? 'Empezá hoy'
                    : '$cuantos de $diasDeLaSemana días',
                style: const TextStyle(fontSize: 12.5, color: Tema.textoTenue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var atras = diasDeLaSemana - 1; atras >= 0; atras--)
                _UnDia(
                  letra:
                      _iniciales[hoy.subtract(Duration(days: atras)).weekday -
                          1],
                  hecho: progreso.practicoHace(atras),
                  esHoy: atras == 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnDia extends StatelessWidget {
  const _UnDia({required this.letra, required this.hecho, required this.esHoy});

  final String letra;
  final bool hecho;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hecho ? Tema.verde : Tema.verdeSuave,
            shape: BoxShape.circle,
            border: esHoy && !hecho
                ? Border.all(color: Tema.verde, width: 2)
                : null,
          ),
          child: hecho
              ? const Icon(Icons.check, size: 17, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 5),
        Text(
          letra,
          style: TextStyle(
            fontSize: 11,
            fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
            color: esHoy ? Tema.titulo : Tema.textoTenue,
          ),
        ),
      ],
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
    const tamano = _anillo;
    final siguiente = nivel.numero < escalones.length
        ? escalones[nivel.numero].$2
        : '';

    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // El disco blanco va aparte del anillo para que tape lo que pase por
          // atrás y para que la sombra salga del borde del disco, no del aro.
          Container(
            width: tamano,
            height: tamano,
            decoration: const BoxDecoration(
              color: Tema.superficie,
              shape: BoxShape.circle,
              boxShadow: _sombra,
            ),
          ),
          SizedBox(
            width: tamano - 14,
            height: tamano - 14,
            child: CircularProgressIndicator(
              value: nivel.cuanto,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Tema.verdeSuave,
              valueColor: const AlwaysStoppedAnimation(Tema.verde),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NIVEL ${nivel.numero}',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: Tema.verde,
                ),
              ),
              const SizedBox(height: 2),
              // "Principiante" no entra al tamaño de "Alunno" y se salía del
              // anillo. Se achica solo el que no entra, en vez de bajarle el
              // tamaño a todos.
              SizedBox(
                width: tamano - 48,
                child: TextoAjustado(
                  nivel.nombre,
                  estilo: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Tema.titulo,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // El anillo se llenaba sin decir nunca para qué.
              Text(
                nivel.esElUltimo ? '¡completo!' : 'faltan ${nivel.faltan}',
                style: const TextStyle(fontSize: 11, color: Tema.textoTenue),
                semanticsLabel: nivel.esElUltimo
                    ? 'Llegaste al último nivel'
                    : 'Faltan ${nivel.faltan} aciertos para $siguiente',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Tema.verdeClaro, Tema.verde],
            ),
            boxShadow: [
              BoxShadow(
                color: Tema.verde.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          // El Material va adentro del Container y transparente: el degradado
          // lo pinta el Container, y el Material solo pone la onda del toque.
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: alTocar,
              child: Icon(destino.icono, size: 40, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 9),
        // Un renglón siempre, y con alto fijo. "Gramática" entraba en dos y
        // ese botón quedaba más alto que los otros tres: la composición medía
        // menos de lo que ocupaba, y el de abajo a la izquierda se derramaba
        // por debajo aunque todo lo demás entrara. Acá importa menos que la
        // palabra se vea grande que que los cuatro botones midan igual.
        SizedBox(
          height: _altoDeLaEtiqueta - 9,
          child: TextoAjustado(
            destino.etiqueta,
            estilo: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Tema.titulo,
            ),
          ),
        ),
      ],
    );
  }
}

/// El podcast no entra en las diagonales: son cuatro y la composición es con
/// cuatro. Va abajo, ancho, que además es donde cae el pulgar sin estirarse.
class _BarraDePodcast extends StatelessWidget {
  const _BarraDePodcast({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radio),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Tema.verde, Tema.verdeClaro],
          ),
          borderRadius: BorderRadius.circular(_radio),
          boxShadow: [
            BoxShadow(
              color: Tema.verde.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(_radio),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.headphones, size: 24, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escuchar',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'El podcast y las fábulas de La Fontaine',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 22, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La radio va debajo del podcast, y de blanco a propósito.
///
/// Dos barras verdes iguales pelean entre ellas y la pantalla se vuelve una
/// lista. Esta es la de escuchar cuando ya no querés practicar nada: va más
/// callada, y el orden dice cuál se usa más seguido.
class _BarraDeRadio extends StatelessWidget {
  const _BarraDeRadio({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    // La sombra va en el Ink y no adentro del InkWell: dibujada adentro se
    // pinta encima del blanco de la tarjeta y la deja gris sucia. Se vio.
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_radio),
      child: Ink(
        decoration: BoxDecoration(
          color: Tema.superficie,
          borderRadius: BorderRadius.circular(_radio),
          boxShadow: _sombra,
        ),
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(_radio),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.radio, size: 22, color: Tema.verde),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radio',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Tema.titulo,
                        ),
                      ),
                      Text(
                        'Italiano en vivo, a velocidad real',
                        style: TextStyle(fontSize: 12, color: Tema.textoTenue),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Tema.textoTenue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

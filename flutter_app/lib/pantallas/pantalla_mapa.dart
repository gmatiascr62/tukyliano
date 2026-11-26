import 'dart:math';

import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../logica/nivel.dart';
import '../modelos/destino.dart';
import '../modelos/percorso.dart';
import '../tema.dart';

/// Cuánto mide de ancho el dibujo del mapa por cada punto de alto.
const double proporcionDelMapa = 941 / 1672;

/// Dónde queda dibujado el mapa adentro de la pantalla.
///
/// El mapa se dibuja tapando toda la pantalla, y como es más ancho de lo
/// que da el celular, **se recorta de los costados**. Entonces la posición
/// de una ciudad no se puede calcular sobre la pantalla: hay que calcularla
/// sobre el dibujo, que empieza antes del borde izquierdo y termina después
/// del derecho.
///
/// Esto es exactamente lo que me equivoqué armando la maqueta: puse las
/// ciudades en porcentaje de la pantalla y quedaron todas corridas, con
/// Nápoles flotando en el agua. Por eso la cuenta vive acá, sola y con su
/// test, en vez de desparramada adentro de la pantalla.
Rect dondeEntraElMapa(Size pantalla, {double proporcion = proporcionDelMapa}) {
  // Se agranda el dibujo hasta que tape la pantalla por los dos lados, y se
  // queda el que más agrande: ese es el que no deja huecos.
  final escala = max(pantalla.width / proporcion, pantalla.height);
  final ancho = escala * proporcion;
  return Rect.fromLTWH(
    (pantalla.width - ancho) / 2,
    (pantalla.height - escala) / 2,
    ancho,
    escala,
  );
}

/// Cuánto mide de lado la chapita de una ciudad, y cuánto sube respecto
/// del punto del mapa.
///
/// Está acá arriba y no adentro de [_Ciudad] porque el perrito se para
/// **al lado** de la chapita: si las dos medidas no son las mismas, queda
/// flotando o pisándola.
const double ladoDeLaChapa = 54;
const double ladoApagada = 46;
const double loQueSubeLaChapa = 34;

/// El perrito que acompaña el camino: cuánto mide y la proporción del
/// dibujo (124 x 220, ya recortado).
const double altoDelPerrito = 72;
const double anchoDelPerrito = altoDelPerrito * 124 / 220;

/// El mapa de Italia: la primera pantalla de la app.
///
/// Antes el inicio eran cuatro círculos y tres barras. Para Matías, que
/// sabe lo que necesita hoy, estaba bien; para el que no sabe nada eran
/// seis puertas sin ningún orden. Ahora lo primero que se ve es el camino,
/// y las herramientas quedan al costado: están a mano, pero no son lo que
/// la app te propone cuando abrís.
///
/// Las ciudades que faltan no se esconden: se muestran apagadas. Un mapa
/// casi vacío se lee como "la app está a medio hacer"; Italia entera en
/// gris con una sola encendida se lee como "todavía no", y de paso muestra
/// cuánto camino hay.
///
/// Abajo había una tarjeta que decía qué lección tocaba. Matías la marcó y
/// la sacó: "creo que es innecesario". Y es cierto que repetía —la ciudad
/// encendida ya es la que toca, y adentro está la lección con su botón—,
/// además de tapar media Sicilia.
class PantallaMapa extends StatelessWidget {
  const PantallaMapa({
    super.key,
    required this.ciudades,
    required this.progreso,
    this.alElegir,
    this.alIrA,
    this.alVerElAlbum,
  });

  final List<Ciudad> ciudades;
  final Progreso progreso;
  final void Function(Ciudad)? alElegir;

  /// Tocar al perrito abre el álbum del viaje. Si no viene, el perrito se
  /// dibuja igual pero no se toca.
  final VoidCallback? alVerElAlbum;

  /// Las herramientas de siempre: la radio, el chat, los cuentos. Si no
  /// viene, la barra del costado no se dibuja (los tests del mapa solo).
  final void Function(Destino)? alIrA;

  bool _terminada(Ciudad ciudad) =>
      ciudad.lecciones.isNotEmpty &&
      ciudad.lecciones.every((l) => progreso.hizo(l.id));

  /// Una ciudad se abre cuando tiene contenido y las anteriores están
  /// terminadas. Hoy sólo Palermo tiene lecciones, así que las otras cuatro
  /// están apagadas porque están vacías, no por castigo.
  bool _abierta(int cual) {
    if (ciudades[cual].lecciones.isEmpty) return false;
    for (var antes = 0; antes < cual; antes++) {
      if (!_terminada(ciudades[antes])) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, medidas) {
        final mapa = dondeEntraElMapa(
          Size(medidas.maxWidth, medidas.maxHeight),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/camino/italia.jpg', fit: BoxFit.cover),
            for (var i = 0; i < ciudades.length; i++)
              _ponerla(
                ciudades[i],
                mapa,
                abierta: _abierta(i),
                terminada: _terminada(ciudades[i]),
              ),
            // Mientras el camino no terminó de cargar no hay ciudades, y
            // entonces no hay dónde pararlo. Sin esto la pantalla se caía
            // entera en ese momento: lo encontraron los tests de las otras
            // secciones, que abren la app sin camino.
            if (ciudades.isNotEmpty)
              _elPerrito(ciudades[_dondeVaElPerrito], mapa),
            const Positioned(top: 10, left: 14, right: 14, child: _Banner()),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _LaSemana(progreso: progreso),
            ),
            if (alIrA != null)
              Positioned(
                top: 86,
                right: 10,
                child: _Herramientas(alIrA: alIrA!),
              ),
          ],
        );
      },
    );
  }

  /// En qué ciudad está parado el perrito: la que toca.
  ///
  /// Si ya están todas hechas se queda en la última, que es hasta donde
  /// llegó; y si no hay ninguna abierta todavía, en la primera.
  int get _dondeVaElPerrito {
    for (var i = 0; i < ciudades.length; i++) {
      if (_abierta(i) && !_terminada(ciudades[i])) return i;
    }
    for (var i = ciudades.length - 1; i >= 0; i--) {
      if (_terminada(ciudades[i])) return i;
    }
    return 0;
  }

  /// El perrito, parado al lado de la chapita de la ciudad que toca.
  ///
  /// **No camina: se desliza.** Lo pidió así Matías —"que no tenga
  /// animación de los pies caminando, solo que se desplace"— y además es
  /// lo honesto: un muñequito moviendo las patas sin avanzar queda peor
  /// que uno que no las mueve. Cuando se termina una ciudad y se abre la
  /// siguiente, [AnimatedPositioned] lo lleva solo de una a la otra.
  ///
  /// Mide menos que la chapita a propósito: lo que manda en la pantalla
  /// es el camino, y el perrito acompaña.
  Widget _elPerrito(Ciudad donde, Rect mapa) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      // A la izquierda de la chapita y apoyado en su base, para que se
      // lea como que está parado al lado y no encima.
      left:
          mapa.left +
          donde.x * mapa.width -
          ladoDeLaChapa / 2 -
          anchoDelPerrito -
          2,
      top:
          mapa.top +
          donde.y * mapa.height -
          loQueSubeLaChapa +
          ladoDeLaChapa -
          altoDelPerrito,
      width: anchoDelPerrito,
      height: altoDelPerrito,
      // Tocarlo abre el álbum del viaje. `opaque` porque el dibujo tiene
      // fondo transparente: sin eso solo contarían los toques que caen
      // justo sobre el perro y no los del aire de alrededor, que en un
      // muñequito flaco es casi todo el rectángulo.
      child: GestureDetector(
        onTap: alVerElAlbum,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'El álbum del viaje',
          child: Image.asset('assets/camino/perrito.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _ponerla(
    Ciudad ciudad,
    Rect mapa, {
    required bool abierta,
    required bool terminada,
  }) {
    const ancho = 86.0;
    return Positioned(
      left: mapa.left + ciudad.x * mapa.width - ancho / 2,
      top: mapa.top + ciudad.y * mapa.height - loQueSubeLaChapa,
      width: ancho,
      child: _Ciudad(
        ciudad: ciudad,
        abierta: abierta,
        terminada: terminada,
        alTocar: abierta && alElegir != null ? () => alElegir!(ciudad) : null,
      ),
    );
  }
}

class _Ciudad extends StatelessWidget {
  const _Ciudad({
    required this.ciudad,
    required this.abierta,
    required this.terminada,
    this.alTocar,
  });

  final Ciudad ciudad;
  final bool abierta;
  final bool terminada;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final encendida = abierta || terminada;
    final lado = abierta && !terminada ? ladoDeLaChapa : ladoApagada;
    return GestureDetector(
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: lado,
            height: lado,
            decoration: BoxDecoration(
              color: encendida ? Colors.white : const Color(0xFFE8EBE9),
              borderRadius: BorderRadius.circular(16),
              border: abierta && !terminada
                  ? Border.all(color: Tema.verde, width: 3)
                  : null,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: ciudad.icono.isEmpty
                ? null
                : ColorFiltered(
                    colorFilter: encendida
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )
                        : const ColorFilter.matrix(_enGris),
                    child: Image.asset('assets/camino/${ciudad.icono}.png'),
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            ciudad.nombre,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: encendida ? Colors.white : const Color(0xFFDDE3E0),
              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La matriz que deja una imagen en blanco y negro. Así el mismo dibujo
  /// sirve apagado y encendido: no hacen falta dos versiones de cada uno.
  static const List<double> _enGris = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    0.6,
    0,
  ];
}

/// El nombre de la app, arriba de todo.
///
/// Es lo primero que se ve al abrir, y sobre el mar queda bien: la
/// pastilla blanca ya viene en el dibujo, así que no hace falta ponerle
/// fondo ni sombra de este lado.
class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/camino/dueparole.png',
        // Un poco más grande que el primer intento, no mucho: más que
        // esto y empieza a competir con el mapa, que es lo que la
        // pantalla tiene que mostrar.
        width: 268,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// La semana, abajo de todo: siete marcas, una por día.
///
/// Antes era un renglón que decía "4 de 7 días". Dibujada se lee de un
/// vistazo y, sobre todo, **se ve el hueco**: el día que falta es lo que
/// invita a volver, y un número no lo muestra.
///
/// Va abajo y no arriba porque arriba está el nombre de la app, y porque
/// es lo último que mirás antes de guardar el teléfono.
class _LaSemana extends StatelessWidget {
  const _LaSemana({required this.progreso});

  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final nivel = nivelPara(progreso.aciertos);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // De la más vieja a hoy, que es como se lee una semana.
              for (var atras = diasDeLaSemana - 1; atras >= 0; atras--)
                _Dia(
                  inicial: _inicialDe(atras),
                  hecho: progreso.practicoHace(atras),
                  esHoy: atras == 0,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            nivel.esElUltimo ? nivel.nombre : 'faltan ${nivel.faltan}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }

  /// La primera letra del día, como la diría un argentino: L M M J V S D.
  static String _inicialDe(int cuantosAtras) {
    const iniciales = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final dia = DateTime.now().subtract(Duration(days: cuantosAtras));
    return iniciales[dia.weekday - 1];
  }
}

class _Dia extends StatelessWidget {
  const _Dia({required this.inicial, required this.hecho, required this.esHoy});

  final String inicial;
  final bool hecho;
  final bool esHoy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: hecho ? Tema.verde : const Color(0xFFEDF1EE),
            shape: BoxShape.circle,
            // Hoy lleva borde aunque todavía no esté hecho: marca dónde
            // estás parado, que es lo que vuelve al hueco una invitación
            // y no un reproche.
            border: esHoy && !hecho
                ? Border.all(color: Tema.verde, width: 2)
                : null,
          ),
          child: hecho
              ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          inicial,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
            color: esHoy ? Tema.titulo : Tema.textoTenue,
          ),
        ),
      ],
    );
  }
}

/// Las herramientas, sobre el Adriático.
///
/// Van de ese lado porque del otro, a la altura de los botones, se mete
/// Cerdeña: es el único costado con mar libre de arriba a abajo. Cada una
/// lleva su dibujo de arcilla, los mismos que las ciudades, así que el
/// mapa entero se ve de una sola mano.
///
/// Son las cuatro de `herramientasDelMapa`, no las seis: gramática y
/// hablar están adentro de la ciudad. El porqué está en destino.dart.
class _Herramientas extends StatelessWidget {
  const _Herramientas({required this.alIrA});

  final void Function(Destino) alIrA;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final destino in herramientasDelMapa)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Tooltip(
              message: destino.etiqueta,
              child: GestureDetector(
                onTap: () => alIrA(destino),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/camino/${destino.dibujo}.png'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

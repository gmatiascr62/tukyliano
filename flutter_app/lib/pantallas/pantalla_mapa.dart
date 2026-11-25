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
class PantallaMapa extends StatelessWidget {
  const PantallaMapa({
    super.key,
    required this.ciudades,
    required this.progreso,
    this.alElegir,
    this.alIrA,
  });

  final List<Ciudad> ciudades;
  final Progreso progreso;
  final void Function(Ciudad)? alElegir;

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

  /// La que toca: la primera abierta sin terminar.
  Ciudad? get _laQueToca {
    for (var i = 0; i < ciudades.length; i++) {
      if (_abierta(i) && !_terminada(ciudades[i])) return ciudades[i];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final toca = _laQueToca;
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
            Positioned(
              top: 10,
              left: 14,
              right: 14,
              child: _Arriba(progreso: progreso),
            ),
            if (alIrA != null)
              Positioned(
                top: 86,
                right: 10,
                child: _Herramientas(alIrA: alIrA!),
              ),
            if (toca != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: _Seguir(
                  ciudad: toca,
                  progreso: progreso,
                  alTocar: alElegir == null ? null : () => alElegir!(toca),
                ),
              ),
          ],
        );
      },
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
      top: mapa.top + ciudad.y * mapa.height - 34,
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
    final lado = abierta && !terminada ? 54.0 : 46.0;
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

/// La tarjeta de abajo: qué toca hacer hoy.
class _Seguir extends StatelessWidget {
  const _Seguir({required this.ciudad, required this.progreso, this.alTocar});

  final Ciudad ciudad;
  final Progreso progreso;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final toca = ciudad.lecciones
        .where((l) => !progreso.hizo(l.id))
        .firstOrNull;
    // La sombra va por decoración y no por el elevation de Material: es la
    // misma que usa el resto de la app, y la de Material se dibujaba como
    // un borde negro duro en vez de una sombra.
    return Container(
      decoration: BoxDecoration(
        color: Tema.superficie,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 13, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ciudad.nombre} · ${toca?.titulo ?? ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Tema.titulo,
                      ),
                    ),
                    if (toca?.deQueVa.isNotEmpty ?? false)
                      Text(
                        toca!.deQueVa,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Tema.textoTenue,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Tema.verde,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La racha y el nivel, en un solo renglón.
///
/// En la pantalla vieja eran dos cosas grandes: una tarjeta con los siete
/// días y un anillo en el medio. Acá el protagonista es el mapa, así que
/// van juntas y chicas. No se sacan: la racha es de lo poco que hace volver
/// al otro día.
class _Arriba extends StatelessWidget {
  const _Arriba({required this.progreso});

  final Progreso progreso;

  @override
  Widget build(BuildContext context) {
    final nivel = nivelPara(progreso.aciertos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 19,
            color: Tema.verde,
          ),
          const SizedBox(width: 5),
          // Los dos flexibles y con puntos suspensivos: con la letra del
          // sistema agrandada, "Principiante · faltan 50" no entra al lado
          // de la racha y el renglón se desborda. Es lo mismo que pasó con
          // la tarjeta de Frasi, y acá se evita de entrada.
          Flexible(
            child: Text(
              '${progreso.diasPracticados} de $diasDeLaSemana días',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Tema.titulo,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              nivel.esElUltimo
                  ? nivel.nombre
                  : '${nivel.nombre} · faltan ${nivel.faltan}',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: Tema.textoTenue),
            ),
          ),
        ],
      ),
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

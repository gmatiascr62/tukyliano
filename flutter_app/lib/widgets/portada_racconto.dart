import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Los dibujos que existen. Cada uno se dibuja con líneas y formas, acá mismo:
/// no hay archivos de imagen, así que no pesan nada, no hay que bajarlas de
/// internet, se ven nítidas en cualquier pantalla y no son de nadie.
enum Dibujo {
  taza,
  gatto,
  tempio,
  pizza,
  valigia,
  schermo,
  mare,
  telefono,
  villa,
  libro,
}

/// La portada de un cuento: un color y un dibujo.
///
/// El JSON solo dice cuál le toca a cada cuento, con lo que agregar un cuento
/// con una portada que ya existe no necesita un APK nuevo.
class Portada {
  const Portada({required this.dibujo, required this.color});

  final Dibujo dibujo;

  /// El color de arriba del degradado. El de abajo se saca de este mismo.
  final Color color;
}

/// Las portadas que existen, por el nombre con el que las pide el JSON.
const portadas = <String, Portada>{
  'colazione': Portada(dibujo: Dibujo.taza, color: Color(0xFFE0913A)),
  'gatto': Portada(dibujo: Dibujo.gatto, color: Color(0xFFCC7040)),
  'roma': Portada(dibujo: Dibujo.tempio, color: Color(0xFF9A8763)),
  'pizza': Portada(dibujo: Dibujo.pizza, color: Color(0xFFC4453B)),
  'lavoro': Portada(dibujo: Dibujo.valigia, color: Color(0xFF4A6B8A)),
  'ufficio': Portada(dibujo: Dibujo.schermo, color: Color(0xFF5F7080)),
  'mare': Portada(dibujo: Dibujo.mare, color: Color(0xFF2E9A9A)),
  'telefono': Portada(dibujo: Dibujo.telefono, color: Color(0xFF6C5CA8)),
  'mistero': Portada(dibujo: Dibujo.villa, color: Color(0xFF6E4463)),
};

/// La que se usa cuando el cuento no dice ninguna, o dice una que esta versión
/// de la app todavía no conoce. Un cuento nuevo con una portada nueva se ve
/// igual de bien hasta que salga el APK que la trae.
const portadaPorDefecto = Portada(dibujo: Dibujo.libro, color: Tema.verde);

Portada portadaDe(String nombre) => portadas[nombre] ?? portadaPorDefecto;

/// Dónde vive cada foto. Van adentro del APK y no se bajan de internet: son
/// pocas y chicas, y así el cuento se ve igual sin señal.
String rutaDeFoto(String nombre) => 'assets/racconti/$nombre.jpg';

/// Una foto del cuento, con el dibujo de respaldo.
///
/// El respaldo importa: el JSON puede nombrar una foto que este APK todavía no
/// trae (los cuentos se actualizan solos, las fotos no). En ese caso se ve el
/// dibujo en vez de un cartel de error.
class FotoRacconto extends StatelessWidget {
  const FotoRacconto({
    super.key,
    required this.nombre,
    required this.respaldo,
    this.ancho,
    this.alto,
    this.fit = BoxFit.cover,
  });

  final String nombre;

  /// Lo que se muestra si la foto no está en el APK.
  final Widget respaldo;

  final double? ancho;
  final double? alto;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (nombre.isEmpty) return respaldo;
    return Image.asset(
      rutaDeFoto(nombre),
      width: ancho,
      height: alto,
      fit: fit,
      errorBuilder: (_, _, _) => respaldo,
    );
  }
}

/// La foto ancha de arriba del cuento, con las esquinas redondeadas.
class FotoDelCuento extends StatelessWidget {
  const FotoDelCuento({super.key, required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    if (nombre.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Tema.radio),
      child: FotoRacconto(
        nombre: nombre,
        ancho: double.infinity,
        fit: BoxFit.fitWidth,
        // Si falta, no se muestra nada: el cuento se lee igual.
        respaldo: const SizedBox.shrink(),
      ),
    );
  }
}

/// El cuadradito de la lista y del encabezado.
class PortadaRacconto extends StatelessWidget {
  const PortadaRacconto({
    super.key,
    required this.imagen,
    this.foto = '',
    this.lado = 54,
  });

  final String imagen;

  /// La miniatura del juego de fotos, cuando el cuento tiene. Si está, se ve
  /// en lugar del dibujo.
  final String foto;

  final double lado;

  @override
  Widget build(BuildContext context) {
    final portada = portadaDe(imagen);

    final dibujo = Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(gradient: _degradado(portada.color)),
      child: CustomPaint(painter: DibujoPortada(portada.dibujo)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tema.radioChico),
      child: FotoRacconto(
        nombre: foto,
        ancho: lado,
        alto: lado,
        respaldo: dibujo,
      ),
    );
  }
}

/// La franja ancha de arriba, cuando se entra a la obra. Acá el dibujo tiene
/// lugar para lucirse: es la presentación del cuento.
class BandaPortada extends StatelessWidget {
  const BandaPortada({
    super.key,
    required this.imagen,
    required this.titulo,
    required this.subtitulo,
    this.alto = 104,
  });

  final String imagen;
  final String titulo;
  final String subtitulo;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final portada = portadaDe(imagen);

    return ClipRRect(
      borderRadius: BorderRadius.circular(Tema.radio),
      child: Container(
        height: alto,
        decoration: BoxDecoration(gradient: _degradado(portada.color)),
        child: Row(
          children: [
            SizedBox(
              width: alto,
              height: alto,
              child: CustomPaint(painter: DibujoPortada(portada.dibujo)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Del color elegido a una versión más oscura del mismo. Se calcula en vez de
/// declararse para que agregar una portada sea una línea y no dos colores que
/// hay que combinar a mano.
LinearGradient _degradado(Color color) {
  final hsl = HSLColor.fromColor(color);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      color,
      hsl
          .withLightness((hsl.lightness - 0.17).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation + 0.06).clamp(0.0, 1.0))
          .toColor(),
    ],
  );
}

/// Dibuja la escena de la portada.
///
/// Todo se mide en fracciones del lado, así el mismo dibujo sirve para el
/// cuadradito de la lista y para la franja grande. Son formas planas y pocas:
/// a 54 píxeles lo que se tiene que leer es la silueta, no el detalle.
class DibujoPortada extends CustomPainter {
  const DibujoPortada(this.dibujo);

  final Dibujo dibujo;

  /// Blanco lleno, para lo que tiene que verse siempre.
  static const _lleno = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final lado = math.min(size.width, size.height);
    // Todo se dibuja en un cuadrado centrado, con un margen parejo.
    final origen = Offset(
      (size.width - lado) / 2,
      (size.height - lado) / 2,
    );
    canvas.save();
    canvas.translate(origen.dx, origen.dy);

    switch (dibujo) {
      case Dibujo.taza:
        _taza(canvas, lado);
      case Dibujo.gatto:
        _gatto(canvas, lado);
      case Dibujo.tempio:
        _tempio(canvas, lado);
      case Dibujo.pizza:
        _pizza(canvas, lado);
      case Dibujo.valigia:
        _valigia(canvas, lado);
      case Dibujo.schermo:
        _schermo(canvas, lado);
      case Dibujo.mare:
        _mare(canvas, lado);
      case Dibujo.telefono:
        _telefono(canvas, lado);
      case Dibujo.villa:
        _villa(canvas, lado);
      case Dibujo.libro:
        _libro(canvas, lado);
    }

    canvas.restore();
  }

  /// Pincel de relleno.
  Paint _relleno(Color color) => Paint()..color = color;

  /// Pincel de línea, con el grosor en fracción del lado para que se agrande
  /// junto con el dibujo.
  Paint _linea(double lado, Color color, double grosor) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = lado * grosor
    ..strokeCap = StrokeCap.round;

  Color get _tenue => Colors.white.withValues(alpha: 0.32);
  Color get _apenas => Colors.white.withValues(alpha: 0.18);

  /// Una taza de café con el vapor: el desayuno.
  void _taza(Canvas canvas, double l) {
    // El vapor, dos curvas que suben.
    for (final x in [0.42, 0.56]) {
      final vapor = Path()
        ..moveTo(l * x, l * 0.38)
        ..cubicTo(l * (x + 0.07), l * 0.31, l * (x - 0.06), l * 0.26, l * x,
            l * 0.19);
      canvas.drawPath(vapor, _linea(l, _tenue, 0.045));
    }

    // El plato.
    canvas.drawRRect(
      RRect.fromLTRBR(l * 0.19, l * 0.72, l * 0.81, l * 0.78, Radius.circular(l * 0.03)),
      _relleno(_lleno),
    );

    // La taza.
    final taza = Path()
      ..moveTo(l * 0.28, l * 0.44)
      ..lineTo(l * 0.66, l * 0.44)
      ..lineTo(l * 0.63, l * 0.7)
      ..quadraticBezierTo(l * 0.62, l * 0.72, l * 0.6, l * 0.72)
      ..lineTo(l * 0.34, l * 0.72)
      ..quadraticBezierTo(l * 0.32, l * 0.72, l * 0.31, l * 0.7)
      ..close();
    canvas.drawPath(taza, _relleno(_lleno));

    // El asa.
    final asa = Path()
      ..moveTo(l * 0.67, l * 0.5)
      ..cubicTo(l * 0.8, l * 0.5, l * 0.8, l * 0.63, l * 0.65, l * 0.63);
    canvas.drawPath(asa, _linea(l, _lleno, 0.05));
  }

  /// Un gato sentado, de frente.
  void _gatto(Canvas canvas, double l) {
    // El cuerpo, una gota ancha abajo.
    final cuerpo = Path()
      ..moveTo(l * 0.5, l * 0.36)
      ..cubicTo(l * 0.74, l * 0.42, l * 0.76, l * 0.62, l * 0.74, l * 0.78)
      ..lineTo(l * 0.26, l * 0.78)
      ..cubicTo(l * 0.24, l * 0.62, l * 0.26, l * 0.42, l * 0.5, l * 0.36)
      ..close();
    canvas.drawPath(cuerpo, _relleno(_lleno));

    // La cola, saliendo a la derecha.
    final cola = Path()
      ..moveTo(l * 0.74, l * 0.76)
      ..cubicTo(l * 0.9, l * 0.76, l * 0.9, l * 0.58, l * 0.82, l * 0.54);
    canvas.drawPath(cola, _linea(l, _lleno, 0.055));

    // Las orejas, antes de la cabeza para que la base quede tapada.
    for (final signo in [-1.0, 1.0]) {
      final borde = 0.5 + signo * 0.17;
      final oreja = Path()
        ..moveTo(l * borde, l * 0.21)
        ..lineTo(l * (0.5 + signo * 0.15), l * 0.07)
        ..lineTo(l * (0.5 + signo * 0.03), l * 0.16)
        ..close();
      canvas.drawPath(oreja, _relleno(_lleno));
    }

    // La cabeza.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(l * 0.5, l * 0.28),
        width: l * 0.36,
        height: l * 0.33,
      ),
      _relleno(_lleno),
    );

    // Los ojos y la nariz, del color del fondo para que se lean como huecos.
    final rasgo = _relleno(Colors.black.withValues(alpha: 0.42));
    for (final signo in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(l * (0.5 + signo * 0.075), l * 0.27),
          width: l * 0.05,
          height: l * 0.065,
        ),
        rasgo,
      );
    }
    final nariz = Path()
      ..moveTo(l * 0.47, l * 0.35)
      ..lineTo(l * 0.53, l * 0.35)
      ..lineTo(l * 0.5, l * 0.39)
      ..close();
    canvas.drawPath(nariz, rasgo);
  }

  /// Un templo con columnas: Roma.
  void _tempio(Canvas canvas, double l) {
    // El frontón.
    final fronton = Path()
      ..moveTo(l * 0.5, l * 0.16)
      ..lineTo(l * 0.86, l * 0.36)
      ..lineTo(l * 0.14, l * 0.36)
      ..close();
    canvas.drawPath(fronton, _relleno(_lleno));

    // Las cuatro columnas.
    for (var i = 0; i < 4; i++) {
      final x = 0.22 + i * 0.19;
      canvas.drawRRect(
        RRect.fromLTRBR(
          l * x,
          l * 0.4,
          l * (x + 0.09),
          l * 0.74,
          Radius.circular(l * 0.015),
        ),
        _relleno(_lleno),
      );
    }

    // Los escalones.
    canvas.drawRect(
      Rect.fromLTRB(l * 0.14, l * 0.74, l * 0.86, l * 0.79),
      _relleno(_lleno),
    );
    canvas.drawRect(
      Rect.fromLTRB(l * 0.08, l * 0.79, l * 0.92, l * 0.84),
      _relleno(_tenue),
    );
  }

  /// Una porción de pizza, con la punta para abajo.
  void _pizza(Canvas canvas, double l) {
    final porcion = Path()
      ..moveTo(l * 0.5, l * 0.82)
      ..lineTo(l * 0.19, l * 0.28)
      ..quadraticBezierTo(l * 0.5, l * 0.14, l * 0.81, l * 0.28)
      ..close();
    canvas.drawPath(porcion, _relleno(_lleno));

    // La corteza, la tira de arriba.
    final corteza = Path()
      ..moveTo(l * 0.19, l * 0.28)
      ..quadraticBezierTo(l * 0.5, l * 0.14, l * 0.81, l * 0.28)
      ..quadraticBezierTo(l * 0.5, l * 0.22, l * 0.19, l * 0.28)
      ..close();
    canvas.drawPath(corteza, _relleno(_tenue));

    // El salame, tres redondeles del color del fondo.
    final salame = _relleno(Colors.black.withValues(alpha: 0.34));
    canvas.drawCircle(Offset(l * 0.38, l * 0.38), l * 0.055, salame);
    canvas.drawCircle(Offset(l * 0.6, l * 0.4), l * 0.05, salame);
    canvas.drawCircle(Offset(l * 0.5, l * 0.57), l * 0.045, salame);
  }

  /// Un portafolio: el trabajo.
  void _valigia(Canvas canvas, double l) {
    // El asa.
    final asa = Path()
      ..moveTo(l * 0.38, l * 0.32)
      ..lineTo(l * 0.38, l * 0.24)
      ..lineTo(l * 0.62, l * 0.24)
      ..lineTo(l * 0.62, l * 0.32);
    canvas.drawPath(asa, _linea(l, _lleno, 0.05));

    canvas.drawRRect(
      RRect.fromLTRBR(
        l * 0.14,
        l * 0.32,
        l * 0.86,
        l * 0.76,
        Radius.circular(l * 0.06),
      ),
      _relleno(_lleno),
    );

    // El cierre del medio, del color del fondo.
    canvas.drawRect(
      Rect.fromLTRB(l * 0.14, l * 0.51, l * 0.86, l * 0.56),
      _relleno(Colors.black.withValues(alpha: 0.18)),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        l * 0.44,
        l * 0.48,
        l * 0.56,
        l * 0.59,
        Radius.circular(l * 0.02),
      ),
      _relleno(_lleno),
    );
  }

  /// Una pantalla de computadora: la oficina.
  void _schermo(Canvas canvas, double l) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        l * 0.14,
        l * 0.24,
        l * 0.86,
        l * 0.62,
        Radius.circular(l * 0.05),
      ),
      _relleno(_lleno),
    );

    // Los renglones de la pantalla.
    for (final (i, ancho) in [0.5, 0.36, 0.44].indexed) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          l * 0.22,
          l * (0.33 + i * 0.08),
          l * (0.22 + ancho),
          l * (0.36 + i * 0.08),
          Radius.circular(l * 0.015),
        ),
        _relleno(Colors.black.withValues(alpha: 0.22)),
      );
    }

    // El pie.
    canvas.drawRect(
      Rect.fromLTRB(l * 0.45, l * 0.62, l * 0.55, l * 0.72),
      _relleno(_tenue),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        l * 0.3,
        l * 0.72,
        l * 0.7,
        l * 0.78,
        Radius.circular(l * 0.03),
      ),
      _relleno(_lleno),
    );
  }

  /// Sol, costa y olas: el mar.
  void _mare(Canvas canvas, double l) {
    canvas.drawCircle(Offset(l * 0.72, l * 0.26), l * 0.11, _relleno(_lleno));

    // Los cerros del fondo.
    final cerros = Path()
      ..moveTo(l * 0.02, l * 0.58)
      ..lineTo(l * 0.26, l * 0.3)
      ..lineTo(l * 0.44, l * 0.48)
      ..lineTo(l * 0.58, l * 0.36)
      ..lineTo(l * 0.86, l * 0.58)
      ..close();
    canvas.drawPath(cerros, _relleno(_tenue));

    // El agua.
    canvas.drawRect(
      Rect.fromLTRB(l * 0, l * 0.58, l * 1, l * 1),
      _relleno(_apenas),
    );

    // Tres olas.
    for (final (i, y) in [0.66, 0.75, 0.84].indexed) {
      final desde = i.isEven ? 0.14 : 0.3;
      final ola = Path()..moveTo(l * desde, l * y);
      for (var j = 0; j < 2; j++) {
        final x = desde + j * 0.28;
        ola
          ..quadraticBezierTo(
              l * (x + 0.07), l * (y - 0.05), l * (x + 0.14), l * y)
          ..quadraticBezierTo(
              l * (x + 0.21), l * (y + 0.05), l * (x + 0.28), l * y);
      }
      canvas.drawPath(ola, _linea(l, _lleno, 0.035));
    }
  }

  /// Dos globos de diálogo: la llamada.
  void _telefono(Canvas canvas, double l) {
    // El de atrás, más chico y tenue.
    final atras = RRect.fromLTRBR(
      l * 0.42,
      l * 0.16,
      l * 0.88,
      l * 0.46,
      Radius.circular(l * 0.08),
    );
    canvas.drawRRect(atras, _relleno(_tenue));
    final puntaAtras = Path()
      ..moveTo(l * 0.78, l * 0.44)
      ..lineTo(l * 0.8, l * 0.58)
      ..lineTo(l * 0.66, l * 0.45)
      ..close();
    canvas.drawPath(puntaAtras, _relleno(_tenue));

    // El de adelante.
    final frente = RRect.fromLTRBR(
      l * 0.1,
      l * 0.4,
      l * 0.62,
      l * 0.72,
      Radius.circular(l * 0.08),
    );
    canvas.drawRRect(frente, _relleno(_lleno));
    final punta = Path()
      ..moveTo(l * 0.22, l * 0.7)
      ..lineTo(l * 0.2, l * 0.86)
      ..lineTo(l * 0.36, l * 0.71)
      ..close();
    canvas.drawPath(punta, _relleno(_lleno));

    // Los tres puntitos de "está hablando".
    final punto = _relleno(Colors.black.withValues(alpha: 0.25));
    for (final x in [0.24, 0.36, 0.48]) {
      canvas.drawCircle(Offset(l * x, l * 0.56), l * 0.035, punto);
    }
  }

  /// Una villa de noche, con dos ventanas encendidas: la novela.
  void _villa(Canvas canvas, double l) {
    // La luna.
    canvas.drawCircle(Offset(l * 0.78, l * 0.2), l * 0.09, _relleno(_tenue));

    // El techo.
    final techo = Path()
      ..moveTo(l * 0.5, l * 0.22)
      ..lineTo(l * 0.88, l * 0.46)
      ..lineTo(l * 0.12, l * 0.46)
      ..close();
    canvas.drawPath(techo, _relleno(_lleno));

    // La casa.
    canvas.drawRect(
      Rect.fromLTRB(l * 0.2, l * 0.46, l * 0.8, l * 0.82),
      _relleno(_lleno),
    );

    // Las ventanas encendidas y la puerta, del color del fondo.
    final hueco = _relleno(Colors.black.withValues(alpha: 0.28));
    for (final x in [0.29, 0.585]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          l * x,
          l * 0.53,
          l * (x + 0.125),
          l * 0.65,
          Radius.circular(l * 0.015),
        ),
        hueco,
      );
    }
    canvas.drawRRect(
      RRect.fromLTRBR(
        l * 0.44,
        l * 0.62,
        l * 0.56,
        l * 0.82,
        Radius.circular(l * 0.015),
      ),
      hueco,
    );
  }

  /// Un libro abierto: la portada de cuando no hay ninguna elegida.
  void _libro(Canvas canvas, double l) {
    final izquierda = Path()
      ..moveTo(l * 0.5, l * 0.32)
      ..quadraticBezierTo(l * 0.3, l * 0.22, l * 0.12, l * 0.28)
      ..lineTo(l * 0.12, l * 0.7)
      ..quadraticBezierTo(l * 0.3, l * 0.64, l * 0.5, l * 0.74)
      ..close();
    final derecha = Path()
      ..moveTo(l * 0.5, l * 0.32)
      ..quadraticBezierTo(l * 0.7, l * 0.22, l * 0.88, l * 0.28)
      ..lineTo(l * 0.88, l * 0.7)
      ..quadraticBezierTo(l * 0.7, l * 0.64, l * 0.5, l * 0.74)
      ..close();
    canvas.drawPath(izquierda, _relleno(_lleno));
    canvas.drawPath(derecha, _relleno(_tenue));
    canvas.drawLine(
      Offset(l * 0.5, l * 0.32),
      Offset(l * 0.5, l * 0.74),
      _linea(l, Colors.black.withValues(alpha: 0.2), 0.02),
    );
  }

  @override
  bool shouldRepaint(DibujoPortada anterior) => anterior.dibujo != dibujo;
}

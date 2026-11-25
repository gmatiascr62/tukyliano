import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../modelos/destino.dart';
import '../modelos/percorso.dart';
import '../tema.dart';

/// Una ciudad del camino, por dentro.
///
/// Lo importante de esta pantalla es lo que NO tiene: un menú. Adentro de
/// una ciudad hay una fila —lección 1, 2, 3, y al final la prueba— y una
/// sola cosa para apretar, que es la que toca. Las hechas quedan en verde y
/// las que faltan, apagadas.
///
/// Si acá arriba hubiera botones iguales —gramática, hablar— el que no
/// sabe nada volvería a tener que elegir, que es justo de lo que el camino
/// lo saca. Por eso van abajo de todo, chiquitas y bajo el cartel de
/// "practicá más": están para el que quiere repasar, no para avanzar.
class PantallaCiudad extends StatelessWidget {
  const PantallaCiudad({
    super.key,
    required this.ciudad,
    required this.progreso,
    this.alVolver,
    this.alEmpezar,
    this.alIrA,
  });

  final Ciudad ciudad;
  final Progreso progreso;
  final VoidCallback? alVolver;

  /// Qué hacer cuando se aprieta la lección que toca.
  final void Function(Leccion)? alEmpezar;

  /// Las de practicar un tema. Si no viene, el cartel de abajo no se
  /// dibuja (los tests que solo miran la fila de lecciones).
  final void Function(Destino)? alIrA;

  /// La primera sin hacer: la única que se puede apretar.
  Leccion? get _laQueToca {
    for (final leccion in ciudad.lecciones) {
      if (!progreso.hizo(leccion.id)) return leccion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // La prueba no se cuenta, ni arriba ni abajo. Contarla solo en el
    // numerador daba "4 de 3" al terminar la ciudad.
    final hechas = progreso.cuantasHechas(
      ciudad.lecciones.where((l) => !l.esPrueba).map((l) => l.id),
    );
    final total = ciudad.cuantasLecciones;
    final toca = _laQueToca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(ciudad: ciudad, alVolver: alVolver),
        _Avance(hechas: hechas, total: total),
        Expanded(
          // "Practicá más" va adentro de la lista, no clavado abajo: si
          // fuera una barra fija se leería como parte del camino, y además
          // en un celular chico le comería un escalón de lugar a la fila,
          // que es lo único que importa acá.
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            itemCount: ciudad.lecciones.length + (alIrA == null ? 0 : 1),
            itemBuilder: (_, i) {
              if (i == ciudad.lecciones.length) {
                return _PracticarMas(alIrA: alIrA!);
              }
              final leccion = ciudad.lecciones[i];
              return _Paso(
                leccion: leccion,
                numero: i + 1,
                hecha: progreso.hizo(leccion.id),
                esLaQueToca: identical(leccion, toca),
                alEmpezar: alEmpezar,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Gramática y hablar, al final de la fila.
///
/// Chiquitas y abajo de todo a propósito: no son un escalón del camino,
/// son para el que ya hizo la lección y quiere seguir dándole al mismo
/// tema. Llevan los mismos dibujos de arcilla que el mapa.
class _PracticarMas extends StatelessWidget {
  const _PracticarMas({required this.alIrA});

  final void Function(Destino) alIrA;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practicá más',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Tema.textoTenue,
            ),
          ),
          const SizedBox(height: 9),
          // Wrap y no Row: con la letra del sistema agrandada las dos
          // chapitas no entran en un renglón —en los tests, con la
          // tipografía de prueba, se pasaban 6 píxeles— y así la segunda
          // baja sola en vez de quedar cortada.
          Wrap(
            spacing: 10,
            runSpacing: 9,
            children: [
              for (final destino in paraPracticarMas)
                _Chapita(destino: destino, alTocar: () => alIrA(destino)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chapita extends StatelessWidget {
  const _Chapita({required this.destino, required this.alTocar});

  final Destino destino;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alTocar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        decoration: BoxDecoration(
          color: Tema.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Tema.borde),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/camino/${destino.dibujo}.png',
              width: 26,
              height: 26,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                destino.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Tema.titulo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.ciudad, this.alVolver});

  final Ciudad ciudad;
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Tema.terracota,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (alVolver != null)
            IconButton(
              onPressed: alVolver,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              tooltip: 'Volver',
            ),
          if (ciudad.icono.isNotEmpty)
            Image.asset(
              'assets/camino/${ciudad.icono}.png',
              width: 46,
              height: 46,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ciudad.nombre,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (ciudad.subtitulo.isNotEmpty)
                  Text(
                    'Nivel ${ciudad.nivel} · ${ciudad.subtitulo}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Tema.terracotaSuave,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avance extends StatelessWidget {
  const _Avance({required this.hechas, required this.total});

  final int hechas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : hechas / total,
                minHeight: 10,
                backgroundColor: Tema.borde,
                valueColor: const AlwaysStoppedAnimation<Color>(Tema.verde),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$hechas de $total',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Tema.textoTenue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un escalón de la fila.
class _Paso extends StatelessWidget {
  const _Paso({
    required this.leccion,
    required this.numero,
    required this.hecha,
    required this.esLaQueToca,
    this.alEmpezar,
  });

  final Leccion leccion;
  final int numero;
  final bool hecha;
  final bool esLaQueToca;
  final void Function(Leccion)? alEmpezar;

  IconData get _dibujo {
    if (leccion.esPrueba) return Icons.star_rounded;
    if (leccion.esLectura) return Icons.menu_book_rounded;
    return Icons.record_voice_over_rounded;
  }

  Color get _colorDelDibujo {
    if (hecha) return Tema.verde;
    if (esLaQueToca) return leccion.esPrueba ? _mostaza : Tema.verdeOscuro;
    return const Color(0xFFC3CCC7);
  }

  static const Color _mostaza = Color(0xFFE0A528);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _colorDelDibujo,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(_dibujo, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Caja(
              leccion: leccion,
              hecha: hecha,
              esLaQueToca: esLaQueToca,
              alEmpezar: alEmpezar,
            ),
          ),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  const _Caja({
    required this.leccion,
    required this.hecha,
    required this.esLaQueToca,
    this.alEmpezar,
  });

  final Leccion leccion;
  final bool hecha;
  final bool esLaQueToca;
  final void Function(Leccion)? alEmpezar;

  @override
  Widget build(BuildContext context) {
    final apagada = !hecha && !esLaQueToca;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: hecha
            ? Tema.verdeSuave
            : apagada
            ? const Color(0xFFEDF1EE)
            : Tema.superficie,
        borderRadius: BorderRadius.circular(19),
        border: esLaQueToca ? Border.all(color: Tema.verde, width: 2.5) : null,
        boxShadow: esLaQueToca ? Tema.sombra : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leccion.titulo,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: apagada ? const Color(0xFFA0ACA6) : Tema.titulo,
                      ),
                    ),
                    if (leccion.deQueVa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          leccion.deQueVa,
                          style: TextStyle(
                            fontSize: 13,
                            color: apagada
                                ? const Color(0xFFB4BEB9)
                                : Tema.textoTenue,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (hecha)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Tema.verde,
                  size: 28,
                ),
            ],
          ),
          if (esLaQueToca) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: alEmpezar == null ? null : () => alEmpezar!(leccion),
                style: Tema.botonPrincipal,
                child: const Text(
                  'Empezar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

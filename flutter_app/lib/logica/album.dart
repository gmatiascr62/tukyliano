import '../datos/progreso.dart';
import '../modelos/percorso.dart';

/// Cada cuántas lecciones el perrito saca una foto.
///
/// Dos: con diez lecciones por ciudad son cinco fotos, que es lo que pidió
/// Matías. Está acá y no desparramado por la pantalla porque es la regla
/// del premio, y el día que cambie tiene que cambiar en un solo lugar.
const int leccionesPorFoto = 2;

/// Una foto del álbum, con todo lo que la pantalla necesita saber: de qué
/// ciudad es, si ya se abrió, y cuántas lecciones faltan si no.
class FotoDelViaje {
  const FotoDelViaje({
    required this.ciudad,
    required this.foto,
    required this.abierta,
    required this.faltan,
  });

  final Ciudad ciudad;
  final Foto foto;
  final bool abierta;

  /// Cuántas lecciones de esa ciudad faltan para que se abra. Cero si ya
  /// está abierta.
  final int faltan;
}

/// El álbum entero del viaje, en el orden del camino.
///
/// Las fotos no se esconden: una cerrada se muestra tapada y con cuánto
/// falta. Es lo mismo que se hizo con los racconti y con las ciudades del
/// mapa —saber que están y qué hay que hacer para llegar es parte de lo
/// que empuja a seguir—, y encima acá el que mira ya sabe que hay cinco
/// por ciudad, porque las ve.
List<FotoDelViaje> albumDelViaje(List<Ciudad> ciudades, Progreso progreso) {
  final todas = <FotoDelViaje>[];
  for (final ciudad in ciudades) {
    if (ciudad.album.isEmpty) continue;
    // La prueba no cuenta: el premio es de las lecciones.
    final hechas = ciudad.lecciones
        .where((l) => !l.esPrueba && progreso.hizo(l.id))
        .length;
    for (var i = 0; i < ciudad.album.length; i++) {
      final pedidas = (i + 1) * leccionesPorFoto;
      todas.add(
        FotoDelViaje(
          ciudad: ciudad,
          foto: ciudad.album[i],
          abierta: hechas >= pedidas,
          faltan: hechas >= pedidas ? 0 : pedidas - hechas,
        ),
      );
    }
  }
  return todas;
}

/// Cuántas hay abiertas, para el renglón de arriba del álbum.
int cuantasAbiertas(List<FotoDelViaje> album) =>
    album.where((f) => f.abierta).length;

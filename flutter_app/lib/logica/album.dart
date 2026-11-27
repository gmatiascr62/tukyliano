import '../datos/progreso.dart';
import '../modelos/percorso.dart';

/// Cuántas lecciones de la ciudad hay que llevar hechas para que se abra
/// su foto número [cual], contando desde cero.
///
/// Las fotos se reparten parejo entre las lecciones de **esa** ciudad. En
/// Cerdeña —diez lecciones y cinco fotos— da una cada dos, que es como lo
/// pidió Matías; en Palermo, que tiene cinco lecciones y también cinco
/// fotos, da una por lección.
///
/// Antes era "cada dos" a secas, y así tres de las cinco de Palermo no se
/// abrían nunca: no había con qué. Repartir en vez de contar de a dos deja
/// la misma regla donde la ciudad da para eso y, sobre todo, hace que el
/// álbum de una ciudad siempre se pueda completar terminándola.
///
/// Una ciudad sin lecciones no abre nada: pide una lección que no existe.
int leccionesParaLaFoto(Ciudad ciudad, int cual) {
  final total = ciudad.cuantasLecciones;
  if (total <= 0 || ciudad.album.isEmpty) return cual + 1;
  return ((cual + 1) * total / ciudad.album.length).ceil();
}

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
      final pedidas = leccionesParaLaFoto(ciudad, i);
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

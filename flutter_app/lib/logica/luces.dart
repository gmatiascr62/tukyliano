import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../modelos/percorso.dart';
import '../tema.dart';

/// En qué color está el camino, según cuántas luces quedan prendidas.
///
/// Las seis luces son dos rojas, dos amarillas y dos verdes, en ese orden,
/// así que el color es el de la última que se prendió. Con ninguna
/// prendida el color es el rojo igual: estar en cero no es estar bien.
enum Animo {
  cuidado('Cuidado', Tema.incorrecto),
  seguilo('Seguilo', Color(0xFFE0A526)),
  bien('Vas bien', Tema.verde);

  const Animo(this.etiqueta, this.color);

  final String etiqueta;
  final Color color;
}

/// El color de la luz número [cual], contando desde cero. Es fijo: las dos
/// primeras son rojas pase lo que pase, y por eso la fila entera se lee
/// como un termómetro aunque esté apagada.
Animo animoDeLaLuz(int cual) => switch (cual) {
  0 || 1 => Animo.cuidado,
  2 || 3 => Animo.seguilo,
  _ => Animo.bien,
};

/// En qué ánimo está el que lleva [luces] prendidas.
Animo animoDe(int luces) =>
    luces <= 0 ? Animo.cuidado : animoDeLaLuz(luces - 1);

/// Cobra las semanas sin estudiar: una luz por semana, y cuando no quedan
/// luces, una ciudad por semana.
///
/// Retroceder una ciudad es deshacer la prueba de la última ciudad
/// aprobada: con eso la siguiente se vuelve a cerrar y el cuento que esa
/// prueba había abierto se cierra solo, porque los dos se calculan de ahí.
/// Para volver a avanzar hay que darla de nuevo, que es lo que pidió
/// Matías.
///
/// Estando en la primera ciudad no hay nada atrás: ahí el castigo se queda
/// en cero luces y no pasa nada más. Perder algo que todavía no se ganó
/// sería echar de la app al que recién llega.
///
/// Devuelve cuántas ciudades se retrocedieron, para poder avisarlo.
int cobrarElOlvido(Progreso progreso, List<Ciudad> ciudades, {DateTime? hoy}) {
  final semanas = progreso.semanasSinEstudiar(hoy: hoy);
  if (semanas <= 0) return 0;

  var retrocedidas = 0;
  for (var golpe = 0; golpe < semanas; golpe++) {
    if (progreso.luces > 0) {
      progreso.perderUnaLuz();
      continue;
    }
    final ultima = _ultimaAprobada(progreso, ciudades);
    if (ultima == null) break;
    progreso.olvidar('${ultima.id}-prueba');
    retrocedidas++;
  }
  // Se cobran todas, incluso las que no tuvieron qué cobrar: si no, el
  // mismo castigo volvería a intentarse en cada arranque.
  progreso.cobrarSemanas(semanas);
  return retrocedidas;
}

/// La última ciudad del camino con la prueba aprobada, que es la que
/// mantiene abierta a la siguiente.
Ciudad? _ultimaAprobada(Progreso progreso, List<Ciudad> ciudades) {
  for (var i = ciudades.length - 1; i >= 0; i--) {
    if (progreso.hizo('${ciudades[i].id}-prueba')) return ciudades[i];
  }
  return null;
}

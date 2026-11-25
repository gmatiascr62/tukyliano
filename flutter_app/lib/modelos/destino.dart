import 'package:flutter/material.dart';

/// A dónde se puede ir desde el mapa.
///
/// Vivía adentro de la vieja pantalla de inicio. Cuando el mapa pasó a ser
/// el inicio y esa pantalla se fue, el enum quedó acá: es el vocabulario de
/// la navegación, no de una pantalla.
enum Destino { racconti, hablar, gramatica, chat, podcast, radio }

/// Las que van al costado del mapa, de arriba para abajo.
///
/// Son cuatro y no seis. Matías lo marcó mirando el APK: "van esos en main
/// y vos pusiste todos, los que sobran van en la siguiente pantalla". Y
/// tiene razón por lo mismo que existe el camino: el mapa tiene que decir
/// qué hacer ahora, y seis puertas al costado vuelven a ser el menú del
/// que el camino lo saca.
///
/// Las cuatro que quedan son las que se usan solas, sin depender de en qué
/// lección va: prender la radio, charlar, escuchar un capítulo, leer un
/// cuento.
const List<Destino> herramientasDelMapa = [
  Destino.radio,
  Destino.chat,
  Destino.podcast,
  Destino.racconti,
];

/// Las otras dos: las de practicar un tema.
///
/// Viven adentro de la ciudad, abajo de la fila de lecciones, porque son
/// repaso de lo que la ciudad enseña. Fuera de ese contexto —sueltas en el
/// mapa— no se sabe qué gramática ni qué hablar.
const List<Destino> paraPracticarMas = [Destino.gramatica, Destino.hablar];

extension EtiquetaDestino on Destino {
  String get etiqueta => switch (this) {
    Destino.racconti => 'Racconti',
    Destino.hablar => 'Parlare',
    Destino.gramatica => 'Gramática',
    Destino.chat => 'Chat',
    Destino.podcast => 'Escuchar',
    Destino.radio => 'Radio',
  };

  /// El dibujo de arcilla que le toca, del juego que generó Matías.
  String get dibujo => switch (this) {
    Destino.racconti => 'racconti',
    Destino.hablar => 'parlare',
    Destino.gramatica => 'gramatica',
    Destino.chat => 'chat',
    Destino.podcast => 'auriculares',
    Destino.radio => 'radio',
  };

  /// El ícono de siempre. Ya no se usa en el mapa —ahí van los dibujos—
  /// pero lo siguen usando las pantallas de adentro.
  IconData get icono => switch (this) {
    Destino.racconti => Icons.menu_book,
    Destino.hablar => Icons.mic,
    Destino.gramatica => Icons.school,
    Destino.chat => Icons.chat_bubble_outline,
    Destino.podcast => Icons.headphones,
    Destino.radio => Icons.radio,
  };
}

import 'package:flutter/material.dart';

/// A dónde se puede ir desde el mapa.
///
/// Vivía adentro de la vieja pantalla de inicio. Cuando el mapa pasó a ser
/// el inicio y esa pantalla se fue, el enum quedó acá: es el vocabulario de
/// la navegación, no de una pantalla.
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

import 'package:flutter/material.dart';

/// Colores de la app Kivy, replicados tal cual durante la migración para que
/// las dos versiones se puedan comparar 1 a 1. El rediseño queda para el final.
class Tema {
  const Tema._();

  /// Window.clearcolor de Kivy
  static const Color fondo = Color(0xFFF2F2F2);

  /// Gris de los botones de Kivy
  static const Color boton = Color(0xFF5A5A5A);
  static const Color textoBoton = Colors.white;

  /// Azul oscuro de los títulos y las preguntas
  static const Color titulo = Color(0xFF1A1A66);

  static const Color texto = Color(0xFF1A1A1A);
  static const Color textoTenue = Color(0xFF808080);

  static const Color correcto = Color(0xFF1A991A);
  static const Color incorrecto = Color(0xFFB31A1A);
}

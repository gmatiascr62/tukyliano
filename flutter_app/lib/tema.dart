import 'package:flutter/material.dart';

/// Paleta de la app, tomada del verde del logo (#58A030).
class Tema {
  const Tema._();

  static const Color verde = Color(0xFF58A030);
  static const Color verdeClaro = Color(0xFF8FC93F);
  static const Color verdeOscuro = Color(0xFF3D7A1F);
  static const Color verdeSuave = Color(0xFFEAF3E0);

  static const Color fondo = Color(0xFFF5F7F2);
  static const Color superficie = Colors.white;
  static const Color borde = Color(0xFFE0E6D8);

  static const Color titulo = Color(0xFF23301C);
  static const Color texto = Color(0xFF1F2421);
  static const Color textoTenue = Color(0xFF6B7280);

  static const Color boton = verde;
  static const Color textoBoton = Colors.white;

  static const Color correcto = Color(0xFF2E7D32);
  static const Color incorrecto = Color(0xFFC62828);

  static const double radio = 14;
  static const double radioChico = 10;

  static ThemeData get datos {
    final esquema = ColorScheme.fromSeed(
      seedColor: verde,
      primary: verde,
      surface: superficie,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      fontFamily: 'Roboto',
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (estados) =>
              estados.contains(WidgetState.selected) ? verde : Colors.white,
        ),
        side: const BorderSide(color: borde, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  /// Botón principal (Verificar, Siguiente, Empezar, Guardar).
  static ButtonStyle get botonPrincipal => ElevatedButton.styleFrom(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFC7D4BC),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
      );

  /// Sombra suave para las tarjetas.
  static List<BoxShadow> get sombra => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ];
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String archivoProgreso = 'progreso.json';

/// Cuántos días para atrás se miran para el "practicaste X de los últimos 7".
const int diasDeLaSemana = 7;

/// Lo que se lleva hecho en la app, guardado en el celular.
///
/// Son dos cosas nada más: cuántas veces se acertó desde siempre —de ahí sale
/// el nivel— y qué días se practicó. Alcanza para que la pantalla de inicio
/// tenga algo real que mostrar, y no obliga a llevar la cuenta de cada palabra
/// por separado, que es un paso que se puede dar después.
///
/// Vive en la carpeta privada de la app, igual que la clave de la IA. Si se
/// desinstala la app se pierde: no hay cuenta ni nube, y eso es a propósito.
class Progreso {
  Progreso({Future<Directory?> Function()? carpeta})
      : _carpeta = carpeta ?? _carpetaDeLaApp;

  /// Devuelve null cuando no hay dónde guardar (los tests): ahí el progreso
  /// vale solo para la sesión abierta.
  final Future<Directory?> Function() _carpeta;

  static Future<Directory?> _carpetaDeLaApp() =>
      getApplicationDocumentsDirectory();

  /// Los días viejos no se usan para nada, así que no se guardan para siempre.
  static const int _cuantosDiasGuardar = 60;

  File? _archivo;
  int _aciertos = 0;
  final Set<String> _dias = {};

  /// Cuántas veces se acertó desde que se instaló la app.
  int get aciertos => _aciertos;

  /// De los últimos siete días, en cuántos se practicó.
  int get diasPracticados {
    final hoy = DateTime.now();
    var cuantos = 0;
    for (var i = 0; i < diasDeLaSemana; i++) {
      if (_dias.contains(_comoTexto(hoy.subtract(Duration(days: i))))) {
        cuantos++;
      }
    }
    return cuantos;
  }

  static String _comoTexto(DateTime dia) =>
      '${dia.year}-${dia.month.toString().padLeft(2, '0')}-'
      '${dia.day.toString().padLeft(2, '0')}';

  Future<File?> _obtenerArchivo() async {
    if (_archivo != null) return _archivo;
    try {
      final dir = await _carpeta();
      return dir == null
          ? null
          : _archivo = File('${dir.path}/$archivoProgreso');
    } catch (_) {
      return null;
    }
  }

  Future<void> cargar() async {
    try {
      final archivo = await _obtenerArchivo();
      if (archivo == null || !archivo.existsSync()) return;
      final datos = jsonDecode(archivo.readAsStringSync());
      if (datos is! Map<String, dynamic>) return;
      _aciertos = datos['aciertos'] as int? ?? 0;
      _dias
        ..clear()
        ..addAll([
          for (final dia in datos['dias'] as List? ?? []) dia.toString(),
        ]);
    } catch (_) {
      // Un archivo roto no tiene que impedir usar la app: se arranca de cero.
    }
  }

  /// Una respuesta acertada. Es lo único que sube el nivel.
  void acerto() {
    _aciertos++;
    practico();
  }

  /// Se practicó hoy, más allá de si se acertó o no. Sirve para el contador de
  /// días: entrar y equivocarse también es practicar.
  void practico() {
    final hoy = _comoTexto(DateTime.now());
    final esNuevo = _dias.add(hoy);
    if (esNuevo) _limpiarViejos();
    _guardar();
  }

  void _limpiarViejos() {
    if (_dias.length <= _cuantosDiasGuardar) return;
    final ordenados = _dias.toList()..sort();
    _dias
      ..clear()
      ..addAll(ordenados.sublist(ordenados.length - _cuantosDiasGuardar));
  }

  Future<void> _guardar() async {
    try {
      final archivo = await _obtenerArchivo();
      archivo?.writeAsStringSync(
        jsonEncode({'aciertos': _aciertos, 'dias': _dias.toList()..sort()}),
      );
    } catch (_) {
      // Si no se puede escribir, el progreso igual vale para esta sesión.
    }
  }
}

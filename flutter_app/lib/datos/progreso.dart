import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String archivoProgreso = 'progreso.json';

/// Cuántos días para atrás se miran para el "practicaste X de los últimos 7".
const int diasDeLaSemana = 7;

/// Cuántas luces tiene la fila de abajo del mapa: dos rojas, dos amarillas
/// y dos verdes.
const int cuantasLuces = 6;

/// Cada cuántas lecciones se prende una luz.
const int leccionesPorLuz = 2;

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

  /// Las luces prendidas, de cero a [cuantasLuces].
  int _luces = 0;

  /// Lecciones contadas desde la última luz: cuando llega a
  /// [leccionesPorLuz] se prende una.
  int _haciaLaLuz = 0;

  /// La última lección que contó para la luz. Hacer dos veces seguidas la
  /// misma no suma: lo pidió así Matías para que no se pueda sumar luz
  /// repitiendo la lección 1 una y otra vez.
  String _ultimaContada = '';

  /// El día de la última lección, en texto. De acá sale el reloj del
  /// olvido: cada semana entera sin hacer ninguna cuesta una luz.
  ///
  /// Vacío mientras no se hizo ninguna lección, y ahí no se castiga nada:
  /// no se puede perder lo que todavía no se empezó.
  String _diaDeLaUltima = '';

  /// Las lecciones del camino que ya se hicieron, por id.
  ///
  /// Van acá y no en un archivo aparte porque es lo mismo: cuánto llevás
  /// hecho. Un archivo más sería otra cosa que puede faltar, romperse o
  /// quedar desincronizada con ésta.
  final Set<String> _hechas = {};

  /// Cuántas veces se acertó desde que se instaló la app.
  int get aciertos => _aciertos;

  /// Si esa lección del camino ya está hecha.
  bool hizo(String leccion) => _hechas.contains(leccion);

  /// Cuántas de esas lecciones están hechas.
  int cuantasHechas(Iterable<String> lecciones) =>
      lecciones.where(_hechas.contains).length;

  /// De los últimos siete días, en cuántos se practicó.
  int get diasPracticados {
    var cuantos = 0;
    for (var i = 0; i < diasDeLaSemana; i++) {
      if (practicoHace(i)) cuantos++;
    }
    return cuantos;
  }

  /// Si se practicó el día que cae [cuantosDias] para atrás. Cero es hoy.
  ///
  /// El contador de arriba dice cuántos días, y con esto la pantalla puede
  /// mostrar además cuáles: una semana dibujada se lee de un vistazo y el
  /// hueco del día que falta se ve, que es lo que invita a volver.
  bool practicoHace(int cuantosDias) => _dias.contains(
    _comoTexto(DateTime.now().subtract(Duration(days: cuantosDias))),
  );

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
      // Las guardadas por una versión anterior no traen esta lista, y eso
      // no es un error: es que todavía no había camino.
      _hechas
        ..clear()
        ..addAll([
          for (final hecha in datos['hechas'] as List? ?? []) hecha.toString(),
        ]);
      // Lo de las luces tampoco está en los archivos viejos: ahí se
      // arranca con cero prendidas y sin reloj corriendo, que es lo mismo
      // que le pasa al que instala la app por primera vez.
      _luces = (datos['luces'] as int? ?? 0).clamp(0, cuantasLuces);
      _haciaLaLuz = (datos['haciaLaLuz'] as int? ?? 0).clamp(
        0,
        leccionesPorLuz - 1,
      );
      _ultimaContada = datos['ultimaContada']?.toString() ?? '';
      _diaDeLaUltima = datos['diaDeLaUltima']?.toString() ?? '';
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

  /// Se terminó una lección del camino.
  ///
  /// Suma para la luz **aunque ya estuviera hecha**: si sólo contaran las
  /// nuevas, el día que se termine todo el contenido no habría forma de
  /// mantener las luces y se perderían ciudades sin poder hacer nada. Lo
  /// que no vale es repetir siempre la misma, así que tiene que ser
  /// distinta de la última que contó.
  ///
  /// El reloj del olvido se reinicia igual, cuente o no: el que repite la
  /// misma lección está estudiando, aunque no sume.
  void termino(String leccion) {
    _hechas.add(leccion);
    _diaDeLaUltima = _comoTexto(DateTime.now());
    if (leccion != _ultimaContada) {
      _ultimaContada = leccion;
      _haciaLaLuz++;
      if (_haciaLaLuz >= leccionesPorLuz) {
        _haciaLaLuz = 0;
        if (_luces < cuantasLuces) _luces++;
      }
    }
    practico();
  }

  /// Las luces prendidas.
  int get luces => _luces;

  /// Cuántas semanas enteras pasaron desde la última lección.
  ///
  /// Cero mientras no se hizo ninguna: el castigo es por dejar algo
  /// empezado, no por no haber empezado.
  int semanasSinEstudiar({DateTime? hoy}) {
    final ultima = _comoFecha(_diaDeLaUltima);
    if (ultima == null) return 0;
    final dias = (hoy ?? DateTime.now()).difference(ultima).inDays;
    return dias < 0 ? 0 : dias ~/ diasDeLaSemana;
  }

  /// Da por cobradas [semanas] semanas de olvido, corriendo el reloj para
  /// adelante. Sin esto el mismo castigo se cobraría en cada arranque.
  void cobrarSemanas(int semanas) {
    final ultima = _comoFecha(_diaDeLaUltima);
    if (ultima == null || semanas <= 0) return;
    _diaDeLaUltima = _comoTexto(
      ultima.add(Duration(days: semanas * diasDeLaSemana)),
    );
    _guardar();
  }

  /// Se apaga una luz. No baja de cero.
  void perderUnaLuz() {
    if (_luces > 0) _luces--;
    _guardar();
  }

  /// Se deshace una lección, que es lo que pasa al retroceder una ciudad:
  /// su prueba deja de estar aprobada y el cuento que abría se vuelve a
  /// cerrar solo, porque eso se calcula de acá.
  void olvidar(String leccion) {
    if (_hechas.remove(leccion)) _guardar();
  }

  static DateTime? _comoFecha(String texto) {
    final partes = texto.split('-');
    if (partes.length != 3) return null;
    final year = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (year == null || mes == null || dia == null) return null;
    return DateTime(year, mes, dia);
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
        jsonEncode({
          'aciertos': _aciertos,
          'dias': _dias.toList()..sort(),
          'hechas': _hechas.toList()..sort(),
          'luces': _luces,
          'haciaLaLuz': _haciaLaLuz,
          'ultimaContada': _ultimaContada,
          'diaDeLaUltima': _diaDeLaUltima,
        }),
      );
    } catch (_) {
      // Si no se puede escribir, el progreso igual vale para esta sesión.
    }
  }
}

import 'dart:io';

/// Qué tan bien le puede ir a este celular con el modelo adentro.
enum QueTanBien {
  /// Entra cómodo.
  bien,

  /// Entra, pero justo: va a andar lento y conviene avisarlo.
  justo,

  /// No entra: mejor no dejar que lo intente y que la app se muera sola.
  no,
}

/// Lo que se pudo averiguar del celular.
class Capacidad {
  const Capacidad({required this.memoriaMb, required this.queTanBien});

  /// Memoria RAM total, en megabytes. Cero si no se pudo averiguar.
  final int memoriaMb;

  final QueTanBien queTanBien;

  bool get puede => queTanBien != QueTanBien.no;

  /// Lo que hay que decirle a alguien antes de que se baje 400 MB.
  String get aviso => switch (queTanBien) {
        QueTanBien.bien => '',
        QueTanBien.justo =>
          'Tu celular tiene ${(memoriaMb / 1024).toStringAsFixed(1)} GB de '
              'memoria: el chat va a andar, pero lento. Las respuestas pueden '
              'tardar medio minuto.',
        QueTanBien.no =>
          'Tu celular tiene ${(memoriaMb / 1024).toStringAsFixed(1)} GB de '
              'memoria y el chat necesita al menos 3 GB para andar. El resto '
              'de la app funciona igual.',
      };
}

/// Cuánta memoria hace falta, en megas, para cargar el modelo sin que Android
/// mate la app.
///
/// El archivo pesa unos 400 MB y en memoria ocupa parecido, más el contexto.
/// El número no sale de una cuenta exacta sino de lo que pasa en la práctica:
/// abajo de 3 GB de RAM total, lo que le queda libre a una app con el sistema
/// y WhatsApp corriendo no alcanza.
const int memoriaMinimaMb = 3 * 1024;

/// A partir de acá anda cómodo.
const int memoriaComodaMb = 6 * 1024;

/// Mira cuánta memoria tiene el celular.
///
/// Lee /proc/meminfo, que en Android está siempre y no necesita ningún plugin
/// ni permiso. [archivo] es para los tests.
Future<Capacidad> mirarElCelular({File? archivo}) async {
  final memoria = await _memoriaTotalMb(archivo ?? File('/proc/meminfo'));

  // Sin dato no se asusta a nadie ni se le promete nada: se deja probar. Pasa
  // en el escritorio y en los tests, no en un celular.
  if (memoria <= 0) {
    return const Capacidad(memoriaMb: 0, queTanBien: QueTanBien.bien);
  }
  if (memoria < memoriaMinimaMb) {
    return Capacidad(memoriaMb: memoria, queTanBien: QueTanBien.no);
  }
  if (memoria < memoriaComodaMb) {
    return Capacidad(memoriaMb: memoria, queTanBien: QueTanBien.justo);
  }
  return Capacidad(memoriaMb: memoria, queTanBien: QueTanBien.bien);
}

/// La línea que interesa de /proc/meminfo es la primera:
/// "MemTotal:        7824560 kB".
Future<int> _memoriaTotalMb(File archivo) async {
  try {
    if (!await archivo.exists()) return 0;
    final texto = await archivo.readAsString();
    final linea = RegExp(r'MemTotal:\s+(\d+)\s*kB').firstMatch(texto);
    if (linea == null) return 0;
    return (int.parse(linea.group(1)!) / 1024).round();
  } catch (_) {
    return 0;
  }
}

/// Cuántos hilos conviene darle al modelo.
///
/// La mitad de los núcleos: los celulares tienen cuatro chicos y cuatro
/// grandes, y usarlos todos no acelera —los chicos frenan a los grandes— pero
/// sí calienta el teléfono y se come la batería. Nunca menos de dos ni más de
/// cuatro.
int hilosParaElModelo({int? nucleos}) {
  final cuantos = nucleos ?? Platform.numberOfProcessors;
  return (cuantos ~/ 2).clamp(2, 4);
}

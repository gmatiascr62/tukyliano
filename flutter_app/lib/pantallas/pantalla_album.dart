import 'package:flutter/material.dart';

import '../datos/progreso.dart';
import '../logica/album.dart';
import '../modelos/percorso.dart';
import '../pantallas/pantalla_mapa.dart' show altoDelPerrito;
import '../tema.dart';

/// Dónde viven las fotos del álbum.
const String carpetaDeFotos = 'assets/album';

/// El álbum del viaje del perrito: una foto cada dos lecciones.
///
/// Es el otro premio del camino, además de los racconti, y es de otra
/// clase: el cuento es para leer y esto es para mirar. Sirve para lo que
/// no sirve una barra de progreso —ver de dónde venís— y da una razón
/// para hacer la lección número 6 que no es "falta para el 100%".
///
/// Las que faltan se muestran tapadas y con cuántas lecciones faltan. Una
/// foto escondida no tira de nadie; una tapada, sí.
class PantallaAlbum extends StatelessWidget {
  const PantallaAlbum({
    super.key,
    required this.ciudades,
    required this.progreso,
    this.alVolver,
  });

  final List<Ciudad> ciudades;
  final Progreso progreso;
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    final album = albumDelViaje(ciudades, progreso);
    final abiertas = cuantasAbiertas(album);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecera(abiertas: abiertas, total: album.length, alVolver: alVolver),
        Expanded(
          child: album.isEmpty
              ? const _SinFotos()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: album.length,
                  itemBuilder: (_, i) =>
                      _Tarjeta(cual: album[i], numero: i + 1),
                ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.abiertas, required this.total, this.alVolver});

  final int abiertas;
  final int total;
  final VoidCallback? alVolver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Tema.verde,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (alVolver != null)
            IconButton(
              onPressed: alVolver,
              icon: const Icon(Icons.arrow_back_rounded),
              color: Colors.white,
              tooltip: 'Volver',
            ),
          Image.asset(
            'assets/camino/perrito.png',
            height: altoDelPerrito,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El álbum del viaje',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  total == 0
                      ? 'Todavía sin fotos'
                      : '$abiertas de $total fotos',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Una foto, abierta o tapada.
///
/// Las dos ocupan lo mismo y están en el mismo lugar: así el álbum se ve
/// entero desde el primer día y cada foto que se abre aparece donde ya
/// estaba el hueco, en vez de correr a las demás de lugar.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.cual, required this.numero});

  final FotoDelViaje cual;
  final int numero;

  @override
  Widget build(BuildContext context) {
    final abierta = cual.abierta;
    return Container(
      decoration: BoxDecoration(
        color: abierta ? Tema.superficie : const Color(0xFFEDF1EE),
        borderRadius: BorderRadius.circular(Tema.radio),
        border: Border.all(color: Tema.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: abierta
                ? Image.asset(
                    '$carpetaDeFotos/${cual.foto.archivo}',
                    fit: BoxFit.cover,
                  )
                : const _Tapada(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cual.ciudad.nombre,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: abierta ? Tema.verde : const Color(0xFF8D9A94),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  abierta
                      ? (cual.foto.texto.isEmpty
                            ? 'Foto $numero'
                            : cual.foto.texto)
                      : _loQueFalta(cual.faltan),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: abierta ? Tema.texto : const Color(0xFF8D9A94),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// En singular cuando falta una sola: "Falta 1 lección" y no "Faltan 1".
  static String _loQueFalta(int cuantas) =>
      cuantas == 1 ? 'Falta 1 lección' : 'Faltan $cuantas lecciones';
}

class _Tapada extends StatelessWidget {
  const _Tapada();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDDE3E0),
      child: const Center(
        child: Icon(Icons.lock_rounded, color: Color(0xFF8D9A94), size: 30),
      ),
    );
  }
}

class _SinFotos extends StatelessWidget {
  const _SinFotos();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'El perrito todavía no sacó ninguna foto.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Tema.textoTenue),
        ),
      ),
    );
  }
}

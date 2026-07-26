import 'package:flutter/material.dart';

import '../modelos/verbo.dart';
import '../tema.dart';

/// Fase 2: muestra los verbos cargados y la versión, para verificar que la
/// carga local y la actualización remota funcionan. El quiz llega en la fase 3.
class PantallaVerbos extends StatelessWidget {
  const PantallaVerbos({super.key, required this.datos, required this.estado});

  final DatosVerbos? datos;
  final String estado;

  @override
  Widget build(BuildContext context) {
    if (datos == null) {
      return const Center(
        child: Text(
          'Cargando verbos...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    final verbos = datos!.verbos.values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'Versión ${datos!.version} · ${verbos.length} verbos',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: Tema.titulo),
        ),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              estado,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
            ),
          ),
        ),
        Expanded(
          child: verbos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay verbos con datos cargados.',
                    style: TextStyle(fontSize: 16, color: Tema.textoTenue),
                  ),
                )
              : ListView.builder(
                  itemCount: verbos.length,
                  itemBuilder: (context, i) => _FilaVerbo(verbo: verbos[i]),
                ),
        ),
        const Text(
          'El quiz llega en la fase 3',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Tema.textoTenue),
        ),
      ],
    );
  }
}

class _FilaVerbo extends StatelessWidget {
  const _FilaVerbo({required this.verbo});

  final Verbo verbo;

  @override
  Widget build(BuildContext context) {
    final tiempos = verbo.tiempos.keys.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '${verbo.nombre} (${verbo.traduccion})',
              style: const TextStyle(fontSize: 17, color: Tema.texto),
            ),
          ),
          Text(
            tiempos == 1 ? '1 tiempo' : '$tiempos tiempos',
            style: const TextStyle(fontSize: 13, color: Tema.textoTenue),
          ),
        ],
      ),
    );
  }
}

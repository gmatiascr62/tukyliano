import 'package:flutter/material.dart';

import '../tema.dart';

/// Un bloque de la explicación: un título, un párrafo corto y ejemplos.
class SeccionAyuda {
  const SeccionAyuda({
    required this.titulo,
    this.cuerpo = '',
    this.ejemplos = const [],
  });

  final String titulo;
  final String cuerpo;
  final List<String> ejemplos;
}

/// Abre la explicación de una sección desde abajo.
///
/// Va en una hoja y no en una pantalla aparte para que se pueda leer y cerrar
/// sin perder el ejercicio que estaba a medio contestar.
Future<void> mostrarAyuda(
  BuildContext context, {
  required String titulo,
  required List<SeccionAyuda> secciones,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Tema.superficie,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Tema.radio)),
    ),
    builder: (context) => HojaAyuda(titulo: titulo, secciones: secciones),
  );
}

class HojaAyuda extends StatelessWidget {
  const HojaAyuda({super.key, required this.titulo, required this.secciones});

  final String titulo;
  final List<SeccionAyuda> secciones;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Tema.titulo,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: Tema.textoTenue,
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                for (final seccion in secciones) ...[
                  Text(
                    seccion.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Tema.verdeOscuro,
                    ),
                  ),
                  if (seccion.cuerpo.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      seccion.cuerpo,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: Tema.texto,
                      ),
                    ),
                  ],
                  if (seccion.ejemplos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final ejemplo in seccion.ejemplos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ejemplo,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            color: Tema.titulo,
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

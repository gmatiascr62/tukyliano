import 'package:flutter/material.dart';

import '../modelos/seccion.dart';
import '../tema.dart';

/// Las siete de gramática, con una línea que diga de qué va cada una.
///
/// En la barra vieja eran siete botones sueltos con una palabra cada uno:
/// "Via" no le dice nada a nadie hasta que entra y lo ve. Acá entra la
/// explicación.
class PantallaGramatica extends StatelessWidget {
  const PantallaGramatica({super.key, required this.alElegir});

  final ValueChanged<Seccion> alElegir;

  static const List<(Seccion, IconData, String)> temas = [
    (Seccion.frases, Icons.short_text, 'Armá la frase entera con el verbo'),
    (Seccion.verbos, Icons.autorenew, 'Conjugá en los seis tiempos'),
    (Seccion.articoli, Icons.abc, 'il, lo, gli, delle: cuál va con cada uno'),
    (
      Seccion.preposizioni,
      Icons.swap_horiz,
      'a, in, di, da, su: la que no se traduce igual',
    ),
    (Seccion.via, Icons.logout, 'andare via, buttare via: el «away» italiano'),
    (Seccion.ci, Icons.place_outlined, 'Próximamente'),
    (Seccion.ne, Icons.pie_chart_outline, 'Próximamente'),
  ];

  static bool _estaLista(Seccion seccion) =>
      seccion != Seccion.ci && seccion != Seccion.ne;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: temas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final (seccion, icono, dice) = temas[i];
        return _Tarjeta(
          seccion: seccion,
          icono: icono,
          dice: dice,
          alTocar: () => alElegir(seccion),
        );
      },
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.seccion,
    required this.icono,
    required this.dice,
    required this.alTocar,
  });

  final Seccion seccion;
  final IconData icono;
  final String dice;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final lista = PantallaGramatica._estaLista(seccion);
    final color = lista ? Tema.verde : Tema.textoTenue;

    return Material(
      color: Tema.superficie,
      borderRadius: BorderRadius.circular(Tema.radio),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lista ? Tema.verdeSuave : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, size: 23, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seccion.etiqueta,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: lista ? Tema.titulo : Tema.textoTenue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dice,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Tema.borde),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../widgets/hoja_ayuda.dart';

/// De dónde salió lo que hay adentro de la app.
///
/// Existe porque el diccionario está bajo Creative Commons
/// Atribución-CompartirIgual, y esa licencia pide que se diga de dónde salió.
/// Pero no está solo por obligación: alguien se tomó el trabajo de armarlo y
/// de regalarlo, y eso se nombra.
///
/// Va en una hoja y no en una pantalla aparte, como el resto de las ayudas de
/// la app: se abre, se lee y se cierra sin perder dónde estabas.
Future<void> mostrarAcercaDe(BuildContext context) => mostrarAyuda(
      context,
      titulo: 'Acerca de Tukyliano',
      secciones: const [
        SeccionAyuda(
          titulo: 'El diccionario',
          cuerpo: 'Lo que traduce cuando marcás una palabra entre '
              'almohadillas sale de FreeDict y WikDict, armado a partir de '
              'Wiktionary. Se usa con permiso: licencia Creative Commons '
              'Atribución-CompartirIgual 3.0.',
          ejemplos: ['freedict.org', 'wikdict.com', 'wiktionary.org'],
        ),
        SeccionAyuda(
          titulo: 'Las voces',
          cuerpo: 'El italiano que se escucha en los cuentos y en los '
              'ejercicios lo pronuncia tu propio celular. Los episodios del '
              'podcast están grabados aparte.',
        ),
        SeccionAyuda(
          titulo: 'La radio',
          cuerpo: 'La emisora en vivo la transmite Senti Chi Parla! OdV, una '
              'asociación italiana de voluntarios. Tukyliano solo la '
              'reproduce: no la hace, no la graba y no gana nada con ella. '
              'Desde la pantalla de Radio se puede entrar a su sitio y '
              'ayudarla.',
          ejemplos: ['radiosentichiparla.org'],
        ),
        SeccionAyuda(
          titulo: 'Tus datos',
          cuerpo: 'Lo que practicás se guarda solo en este celular y no se '
              'manda a ningún lado. Si desinstalás la app, se borra. No hay '
              'cuenta ni nube, y es a propósito.',
        ),
      ],
    );

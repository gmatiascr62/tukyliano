# Fotos del perrito que todavía no tienen ciudad

Las fotos del álbum del viaje viven en `flutter_app/assets/album/`, y ahí
entran al APK. Esta carpeta es la sala de espera: **las fotos de ciudades
que todavía no tienen lecciones**.

Por qué no están allá directamente: el álbum abre una foto cada tantas
lecciones de su ciudad, repartidas entre las que haya. Una ciudad sin
lecciones no puede abrir ninguna, así que declararlas sería prometer algo
que no se puede cumplir —hay un test que no lo deja— y además las cinco
pesarían en el APK sin que nadie pueda verlas nunca.

## Cómo se mudan

Cuando la ciudad tenga sus lecciones:

1. Copiar los `.jpg` a `flutter_app/assets/album/`.
2. Agregar el `album` de esa ciudad en `flutter_app/assets/percorso.json`,
   con el `archivo` y el `texto` de cada una.
3. Borrarlas de acá.

Los tests de `flutter_app/test/album_test.dart` chequean lo demás: que el
archivo exista, que tenga pie de foto y que la última se pueda abrir
terminando la ciudad.

## Napoli

Las mandó Matías el 28/11/2026, numeradas por él. En orden de álbum:

1. `napoli-1.jpg` — Selfie en Castel dell'Ovo, con el Vesubio atrás.
2. `napoli-2.jpg` — Pizza Margherita con la camiseta del Napoli.
3. `napoli-3.jpg` — Selfie en Spaccanapoli con Pulcinella.
4. `napoli-4.jpg` — Sfogliatella frente al mural de Maradona.
5. `napoli-5.jpg` — Selfie en el Duomo con el pizzaiolo y los cornicelli.

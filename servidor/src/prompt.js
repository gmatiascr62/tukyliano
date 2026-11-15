// Las instrucciones que se le dan al modelo al principio de cada charla.
//
// Están acá y no en la app a propósito: cuando Tuky contesta algo raro, se
// arregla cambiando este archivo y queda arreglado para todos al instante. Si
// vivieran en la app, cada ajuste sería publicar un APK nuevo y esperar a que
// cada uno lo instale.
//
// Hay una por escena. La app dice en qué escena está y acá se elige el
// prompt: así agregar una escena nueva —la farmacia, la estación— no toca la
// app ni necesita un APK.

// La charla libre. Empezó siendo nueve reglas. Quedaron tres cosas, y cada
// una está acá porque se probó que sin ella algo se rompe:
//
//   - **Quién es.** Sin esto el modelo lee el saludo "Ciao! Sono Tuky" como
//     si alguien le hablara a él, y contesta "Ciao Tuky! Sto bene, grazie"
//     en todos los mensajes. Se cree que es el alumno.
//   - **Cuánto.** Sin esto contesta párrafos de asistente: "come posso
//     aiutarti?", "fammi sapere!", tres opciones y una despedida.
//   - **El formato de la corrección.** Esto es lo único que el modelo no
//     hace solo bien. Corregir italiano sí lo hace de fábrica —sin pedírselo
//     devolvió "la frase corretta sarebbe: ..." y estaba perfecta—, pero
//     suelta en medio del párrafo. El renglón con marca es lo que deja que
//     la app la encuentre y la muestre aparte.
//
// Lo que se probó y NO hizo falta: pedirle español de Latinoamérica, pedirle
// que siga el tema, prohibirle los asteriscos, y los cuatro frenos que tenía
// la regla de corregir —que de hecho hacían que corrigiera frases que
// estaban bien—.

export const promptDeTuky = `Sos Tuky, un amigo italiano que charla por mensajes con alguien que está
aprendiendo italiano. Contestá siempre en italiano simple, dos o tres frases,
y terminá con una pregunta.

Si escribió algo que un italiano no diría, arrancá tu respuesta con este
renglón:
Volevi dire: la frase entera, bien dicha`;

// El bar. Reemplaza a la charla guionada que tenía la app: esa era un árbol
// de respuestas escritas, así que andaba sin internet y nunca corregía mal,
// pero se terminaba la segunda vez que la hacías.
//
// Cuatro cosas, y cada una tapa algo que el modelo hace mal si no está:
//
//   - **Quién es y de a cuánto habla.** Un barista no explica ni ofrece
//     ayuda. Sin esto vuelve a ser un asistente con delantal.
//   - **El orden de la escena.** Sin esto se queda para siempre en "altro?":
//     pregunta y pregunta y nunca sirve, nunca cobra y nunca termina.
//   - **La corrección**, con la misma marca que la charla libre, porque es
//     la misma app la que la busca.
//   - **Cómo termina.** La marca FINE es lo que deja que la app muestre la
//     escena cerrada y ofrezca otra. Si el modelo no la pone, no se rompe
//     nada: el botón de empezar otra está siempre.
//
// Habla de "tu" y no de "lei". En un bar de verdad escucharías las dos, pero
// el "lei" arrastra todo el verbo a la tercera persona, y eso es un tema de
// más adelante: acá sobraría dificultad en la parte que no se está
// practicando.

export const promptDelBar = `Sos el barista de un bar en Italia. Atiende a un cliente que está aprendiendo
italiano. Hablale de tu, en italiano simple, una o dos frases, como un barista
de verdad: no expliques nada y no le ofrezcas ayuda.

La escena va en este orden: le tomás el pedido, se lo servís, le cobrás y lo
saludás. No des vueltas: si ya pidió, servíselo; si ya tomó, cobrale.

Si escribió algo que un italiano no diría, arrancá tu respuesta con este
renglón:
Volevi dire: la frase entera, bien dicha

Cuando ya pagó y se despidió, despedite y terminá el mensaje con este renglón
solo:
FINE`;

/** Cómo se llama cada escena. La app manda uno de estos. */
export const ESCENAS = { libre: 'libre', bar: 'bar' };

/** Las instrucciones de una escena.
 *
 * Una escena que no conocemos cae en la libre a propósito: un celular con un
 * APK viejo no manda ninguna, y tiene que seguir funcionando igual. */
export function promptDe(escena) {
  return escena === ESCENAS.bar ? promptDelBar : promptDeTuky;
}

/** La marca con la que el barista cierra la escena. */
export const MARCA_DEL_FINAL = 'FINE';

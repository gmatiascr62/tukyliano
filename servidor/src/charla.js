// Arma la charla que se le manda al modelo a partir de lo que mandó la app.
//
// La app manda la charla tal cual la ve el alumno: el saludo con el que
// arrancó y los mensajes que siguieron. Todo lo que es "cómo se le habla al
// modelo" —las instrucciones y el formato de los turnos— vive acá.
//
// El formato es el de siempre, el de los chats: una lista de turnos con
// `role` y `content`. Lo entienden todos los modelos del catálogo de
// Cloudflare, así que cambiar de modelo no toca este archivo.

import { promptDeTuky } from './prompt.js';

/** Un turno. 'system' son las instrucciones, 'user' es el alumno y
 * 'assistant' es Tuky. */
export function turno(rol, texto) {
  return { role: rol, content: texto };
}

/** La charla entera, lista para mandársela al modelo.
 *
 * `saludo` es con el que arrancó, que la app sortea sola para no gastar un
 * pedido. `mensajes` son los que vinieron después, cada uno con `quien`
 * ('yo' o 'ia') y `texto`.
 *
 * Las instrucciones van como turno 'system', que es donde van. Con Gemini
 * había que meterlas disfrazadas de primer mensaje del alumno porque el
 * modelo lite devolvía 400 si se usaba el campo de sistema. Acá no.
 */
export function contenidos({ saludo, mensajes }) {
  return [
    turno('system', promptDeTuky),
    turno('assistant', saludo),
    ...mensajes.map((mensaje) =>
      turno(mensaje.quien === 'yo' ? 'user' : 'assistant', mensaje.texto),
    ),
  ];
}

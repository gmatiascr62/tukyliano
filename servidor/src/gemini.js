// El que le pregunta a Gemini qué quiere decir una palabra.
//
// Es lo único del servidor que habla con Google, y existe solo para el
// diccionario: el chat sigue andando con el modelo de Cloudflare, que no
// necesita ninguna clave.
//
// **Por qué acá sí una clave y en el chat no.** En el chat se eliminó a
// propósito: la app pedía una clave de Google, el usuario la tenía que
// conseguir y vivía adentro de un APK público, donde cualquiera la saca.
// Esto es distinto: la clave vive en Cloudflare, encriptada, al lado del
// código. No viaja al celular de nadie.
//
// **Y por qué Gemini y no el modelo del chat.** Se midió con veinte
// palabras de las fábulas. Gemini acertó las catorce que contestó;
// "lumicino" lo tradujo "en las últimas", que es el modismo, y "ducatone"
// lo tradujo "patacón". El del chat falló cuatro de diecinueve: a
// "pecchie" (abejas) le puso "manchas, lunares".
//
// Si la clave no está, esto devuelve null y el servidor contesta que no
// sabe. No se rompe nada: queda como estaba antes de que esto existiera.

const MODELO = 'gemini-3.6-flash';
const URL = 'https://generativelanguage.googleapis.com/v1beta/models/' +
  `${MODELO}:generateContent`;

// Cuánto se espera antes de darse por vencido. Alguien que tocó una
// palabra está mirando la pantalla: si tarda más que esto, prefiere un
// "no está" a seguir esperando.
const CUANTO_ESPERAR = 12000;

const PEDIDO = `Sos un diccionario italiano → español rioplatense.

Traducí la palabra italiana que te paso. Si te doy el renglón donde
aparece, traducí lo que quiere decir AHÍ.

Devolvé SOLO un objeto JSON, sin explicar nada y sin \`\`\`:

{"base": "forma de diccionario", "es": ["traducción", "otra"]}

- "es": de una a tres traducciones, cortas, de una o dos palabras cada
  una. Es para mostrar al costado mientras alguien lee, no una
  definición.
- "base": la palabra como la listaría un diccionario (infinitivo,
  singular, masculino). Si ya es esa, repetila.
- Si es un nombre propio, devolvé {"es": []}.
- Si no sabés qué quiere decir, devolvé {"es": []}. Es mejor que
  inventar: lo vacío se le muestra como "no está", y una traducción
  inventada el que lee no tiene con qué darse cuenta.`;

/** Qué quiere decir una palabra, o null si no se pudo saber.
 *
 * Devuelve {es: [...], base: '...'}. Nunca tira: una palabra que no se
 * pudo traducir no puede voltear el pedido, y el que la buscó tiene que
 * recibir "no está" y no un error.
 */
export async function queQuiereDecir(palabra, donde, clave) {
  const { que } = await loQueDijo(palabra, donde, clave);
  return que;
}

/** Lo mismo, pero contando también por qué no se pudo.
 *
 * El motivo es un número —el código HTTP que devolvió Google— o una
 * palabra. No revela nada de la clave y ahorra tener que leer los logs de
 * Cloudflare para saber si la clave no sirve (403), si se acabó la cuota
 * (429) o si el pedido está mal armado (400). Desde afuera esas tres se
 * ven igual: "no sé qué quiere decir".
 */
export async function loQueDijo(palabra, donde, clave) {
  if (!clave) return { que: null, porQue: 'sinClave' };

  const texto = donde
    ? `${PEDIDO}\n\npalabra: ${palabra}\nrenglón: ${donde}`
    : `${PEDIDO}\n\npalabra: ${palabra}`;

  let contestado;
  try {
    contestado = await fetch(URL, {
      method: 'POST',
      headers: {
        'x-goog-api-key': clave,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: texto }] }],
        generationConfig: {
          temperature: 0,
          responseMimeType: 'application/json',
        },
      }),
      signal: AbortSignal.timeout(CUANTO_ESPERAR),
    });
  } catch (error) {
    console.error('gemini no contestó', String(error));
    return { que: null, porQue: String(error).includes('timeout')
      ? 'tardo' : 'red' };
  }

  if (!contestado.ok) {
    console.error('gemini dijo que no', contestado.status);
    return { que: null, porQue: contestado.status };
  }

  let datos;
  try {
    datos = await contestado.json();
  } catch {
    return { que: null, porQue: 'noEsJson' };
  }

  const crudo = datos?.candidates?.[0]?.content?.parts
    ?.map((p) => p?.text ?? '')
    .join('')
    .trim();
  if (!crudo) return { que: null, porQue: 'vacio' };

  let dicho;
  try {
    dicho = JSON.parse(crudo);
  } catch {
    console.error('gemini no devolvió JSON', crudo.slice(0, 120));
    return { que: null, porQue: 'noEsJson' };
  }

  const que = loQuePasaElControl(palabra, dicho);
  return { que, porQue: que ? '' : 'noSupo' };
}

/// Cuánto puede medir una traducción. Más que esto no es una traducción,
/// es una explicación, y no entra en el renglón donde se muestra.
const LARGO_MAXIMO = 40;

/** Deja pasar solo lo que sirve para mostrar. Null si no sirve nada.
 *
 * Una IA traduciendo palabras sueltas se equivoca de maneras que se
 * pueden ver sin saber italiano, y acá no hay nadie mirando: lo que
 * salga de este control se le muestra a alguien y se guarda para
 * siempre.
 */
export function loQuePasaElControl(palabra, dicho) {
  if (!dicho || typeof dicho !== 'object') return null;

  const traducciones = [];
  for (const cual of Array.isArray(dicho.es) ? dicho.es.slice(0, 3) : []) {
    if (typeof cual !== 'string') continue;
    const limpia = cual.trim();
    if (!limpia || limpia.length > LARGO_MAXIMO) continue;
    if (limpia.split(/\s+/).length > 4) continue;
    // La palabra italiana devuelta tal cual: eso es copiar, no traducir.
    // Las que se escriben igual en los dos idiomas se pierden, y es el
    // precio de no mostrar nunca una copia disfrazada de traducción.
    if (limpia.toLowerCase() === palabra) continue;
    traducciones.push(limpia);
  }
  if (traducciones.length === 0) return null;

  const base = typeof dicho.base === 'string' ? dicho.base.trim() : '';
  return {
    es: traducciones,
    base: base && base.toLowerCase() !== palabra ? base : '',
  };
}

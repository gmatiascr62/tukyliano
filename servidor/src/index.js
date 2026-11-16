// El punto de entrada del Worker: lo único que sabe de Cloudflare.
//
// Agarra lo que viene del ambiente —la base, el modelo, los códigos, los
// topes— y se lo pasa a atender.js, que es donde está la lógica y lo que se
// prueba.

import { atenderLaCharla } from './atender.js';
import { MODELO_POR_DEFECTO } from './modelo.js';
import {
  atenderLaPalabra,
  TOPES_POR_DEFECTO as TOPES_DE_PALABRAS,
} from './palabras.js';
import { queSalioMal } from './respuestas.js';

/// Cuántos mensajes por día si nadie dice otra cosa.
///
/// Sesenta por persona es una charla larga de práctica, no un límite que se
/// sienta. Dos mil en total es lo que separa un día raro de una factura rara.
const TOPES_POR_DEFECTO = { deCadaUno: 60, deTodos: 2000 };

export default {
  async fetch(pedido, ambiente) {
    const donde = new URL(pedido.url);

    // Para saber si está vivo sin gastar ni una neurona.
    if (pedido.method === 'GET' && donde.pathname === '/salud') {
      return Response.json({ ok: true });
    }

    const esCharla = pedido.method === 'POST' && donde.pathname === '/charla';
    const esPalabra = pedido.method === 'POST' && donde.pathname === '/palabra';
    if (!esCharla && !esPalabra) {
      return queSalioMal('pedidoRaro');
    }

    let cuerpo;
    try {
      cuerpo = await pedido.json();
    } catch {
      return queSalioMal('pedidoRaro');
    }

    if (esPalabra) {
      try {
        return await atenderLaPalabra(cuerpo, {
          base: ambiente.BASE,
          // La clave de Gemini. Es lo único del servidor que habla con
          // Google, y es solo para el diccionario: el chat sigue andando
          // con el modelo de Cloudflare, sin ninguna clave. Si no está
          // cargada, el diccionario contesta "no está" y nada se rompe.
          clave: ambiente.GEMINI_API_KEY,
          permitidos: codigos(ambiente.CODIGOS),
          topes: {
            deCadaUno: numero(ambiente.TOPE_DE_PALABRAS_POR_PERSONA,
                              TOPES_DE_PALABRAS.deCadaUno),
            deTodos: numero(ambiente.TOPE_DE_PALABRAS,
                            TOPES_DE_PALABRAS.deTodos),
          },
          ahora: new Date(),
        });
      } catch (error) {
        console.error('se rompió buscando una palabra', error);
        return queSalioMal('roto');
      }
    }

    try {
      return await atenderLaCharla(cuerpo, {
        base: ambiente.BASE,
        ia: ambiente.AI,
        modelo: ambiente.MODELO || MODELO_POR_DEFECTO,
        permitidos: codigos(ambiente.CODIGOS),
        topes: {
          deCadaUno: numero(ambiente.TOPE_POR_PERSONA, TOPES_POR_DEFECTO.deCadaUno),
          deTodos: numero(ambiente.TOPE_DEL_SERVIDOR, TOPES_POR_DEFECTO.deTodos),
        },
        ahora: new Date(),
      });
    } catch (error) {
      // Cualquier cosa que no esperábamos. Queda en el log de Cloudflare, y al
      // alumno le llega un cartel que se entiende.
      console.error('se rompió atendiendo', error);
      return queSalioMal('roto');
    }
  },
};

/** Los códigos permitidos, separados por coma. Vacío = entra cualquiera. */
function codigos(texto) {
  if (typeof texto !== 'string') return [];
  return texto
    .split(',')
    .map((c) => c.trim())
    .filter((c) => c !== '');
}

function numero(texto, siNo) {
  const valor = Number.parseInt(texto ?? '', 10);
  return Number.isFinite(valor) && valor > 0 ? valor : siNo;
}

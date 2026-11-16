// El diccionario de respaldo.
//
// Lo que más importa probar acá no es que traduzca: es que le pregunte a la
// IA UNA sola vez por palabra. Esa es la idea entera, y si se rompe no se
// nota mirando la pantalla —la traducción aparece igual— pero se paga.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { loQuePasaElControl } from '../src/gemini.js';
import {
  atenderLaPalabra,
  laQueYaEsta,
  loQueMando,
  normalizar,
} from '../src/palabras.js';
import { BaseDeMentira } from './base_de_mentira.js';

const TOPES = { deCadaUno: 120, deTodos: 3000 };

function afuera(base, extra = {}) {
  return {
    base,
    clave: 'una-clave',
    permitidos: [],
    topes: TOPES,
    ahora: new Date('2026-11-16T10:00:00Z'),
    ...extra,
  };
}

/// Cuenta cuántas veces se le preguntó a Gemini de verdad.
function gemniDeMentira(contesta) {
  const llamadas = [];
  globalThis.fetch = async (url, opciones) => {
    llamadas.push({ url, cuerpo: JSON.parse(opciones.body) });
    return {
      ok: true,
      json: async () => ({
        candidates: [{ content: { parts: [{ text: JSON.stringify(contesta) }] } }],
      }),
    };
  };
  return llamadas;
}

test('la palabra se normaliza igual que en el diccionario de la app', () => {
  // Si no, "Lumicino" y "lumicino" serían dos filas y dos preguntas a la IA
  // por la misma palabra.
  assert.equal(normalizar('Lumicino'), 'lumicino');
  assert.equal(normalizar('perché'), 'perche');
  assert.equal(normalizar('  CAFFÈ.  '), 'caffe');
});

test('un pedido sin palabra o sin quién no se atiende', () => {
  assert.equal(loQueMando(null), null);
  assert.equal(loQueMando({ quien: 'yo' }), null);
  assert.equal(loQueMando({ palabra: 'ciao' }), null);
  assert.equal(loQueMando({ palabra: '...', quien: 'yo' }), null);
  assert.equal(loQueMando({ palabra: 'x'.repeat(60), quien: 'yo' }), null);
});

test('a la IA se le pregunta UNA vez por palabra, y nunca más', async () => {
  const base = new BaseDeMentira();
  const llamadas = gemniDeMentira({ es: ['velita'], base: 'lumicino' });

  const primera = await atenderLaPalabra(
    { palabra: 'lumicino', quien: 'uno' }, afuera(base));
  assert.equal((await primera.json()).de, 'ia');
  assert.equal(llamadas.length, 1);

  // El mismo que pregunta de nuevo.
  const otraVez = await atenderLaPalabra(
    { palabra: 'lumicino', quien: 'uno' }, afuera(base));
  assert.equal((await otraVez.json()).de, 'base');

  // Y otra persona, que es el caso que importa: el amigo de Matías.
  const otroCelular = await atenderLaPalabra(
    { palabra: 'Lumicino', quien: 'dos' }, afuera(base));
  const dijo = await otroCelular.json();
  assert.equal(dijo.de, 'base');
  assert.deepEqual(dijo.es, ['velita']);

  assert.equal(llamadas.length, 1, 'se le preguntó a la IA más de una vez');
});

test('lo que se guarda queda buscable', async () => {
  const base = new BaseDeMentira();
  gemniDeMentira({ es: ['abejas'], base: 'pecchia' });
  await atenderLaPalabra({ palabra: 'pecchie', quien: 'uno' }, afuera(base));

  const guardada = await laQueYaEsta(base, 'pecchie');
  assert.deepEqual(guardada.es, ['abejas']);
  assert.equal(guardada.base, 'pecchia');
});

test('sin clave de Gemini contesta que no sabe, y no se rompe', async () => {
  const base = new BaseDeMentira();
  const llamadas = gemniDeMentira({ es: ['velita'] });

  const contesto = await atenderLaPalabra(
    { palabra: 'lumicino', quien: 'uno' }, afuera(base, { clave: '' }));

  const dijo = await contesto.json();
  assert.equal(contesto.status, 200);
  assert.deepEqual(dijo.es, []);
  assert.equal(dijo.de, 'nadie');
  assert.equal(llamadas.length, 0);
});

test('una palabra que la IA no sabe no se guarda', async () => {
  // Guardar un "no sé" sería cerrarle la puerta para siempre: el día que la
  // IA mejore, esa palabra nunca se vuelve a preguntar.
  const base = new BaseDeMentira();
  gemniDeMentira({ es: [] });

  await atenderLaPalabra({ palabra: 'chirimbolo', quien: 'uno' }, afuera(base));
  assert.equal(await laQueYaEsta(base, 'chirimbolo'), null);
});

test('la que ya está en la base no gasta tope', async () => {
  const base = new BaseDeMentira();
  gemniDeMentira({ es: ['velita'] });
  const apretado = { ...TOPES, deCadaUno: 1 };

  await atenderLaPalabra({ palabra: 'lumicino', quien: 'uno' },
                         afuera(base, { topes: apretado }));

  // El tope es 1 y ya se usó. Otra palabra nueva tiene que rebotar...
  const nueva = await atenderLaPalabra({ palabra: 'pecchie', quien: 'uno' },
                                       afuera(base, { topes: apretado }));
  assert.equal(nueva.status, 429);

  // ...pero una que ya está tiene que salir igual, porque no cuesta nada.
  const vieja = await atenderLaPalabra({ palabra: 'lumicino', quien: 'uno' },
                                       afuera(base, { topes: apretado }));
  assert.equal(vieja.status, 200);
  assert.equal((await vieja.json()).de, 'base');
});

test('el código de invitación vale igual que en el chat', async () => {
  const base = new BaseDeMentira();
  gemniDeMentira({ es: ['velita'] });
  const conCodigos = afuera(base, { permitidos: ['abc'] });

  const sinCodigo = await atenderLaPalabra(
    { palabra: 'lumicino', quien: 'uno' }, conCodigos);
  assert.equal(sinCodigo.status, 401);

  const conCodigo = await atenderLaPalabra(
    { palabra: 'lumicino', quien: 'uno', codigo: 'abc' }, conCodigos);
  assert.equal(conCodigo.status, 200);
});

test('el renglón se le manda a la IA, que es lo que desambigua', async () => {
  // "lumicino" solo es "lucecita". En "ridotto al lumicino" es "en las
  // últimas", que es lo que quiere saber el que lo tocó.
  const base = new BaseDeMentira();
  const llamadas = gemniDeMentira({ es: ['en las últimas'] });

  await atenderLaPalabra(
    { palabra: 'lumicino', donde: 'Un Lupo già ridotto al lumicino',
      quien: 'uno' },
    afuera(base));

  const texto = llamadas[0].cuerpo.contents[0].parts[0].text;
  assert.ok(texto.includes('ridotto al lumicino'), texto);
});

test('el control no deja pasar lo que no sirve para mostrar', () => {
  // Todo esto lo devolvió Gemini de verdad alguna vez.
  assert.equal(loQuePasaElControl('lumicino', null), null);
  assert.equal(loQuePasaElControl('lumicino', { es: [] }), null);
  assert.equal(loQuePasaElControl('lumicino', { es: [''] }), null);
  // Una explicación en vez de una traducción.
  assert.equal(
    loQuePasaElControl('lumicino', {
      es: ['la luz tenue de una vela que está por apagarse del todo'],
    }),
    null,
  );
  // La palabra italiana copiada tal cual.
  assert.equal(loQuePasaElControl('regalo', { es: ['regalo'] }), null);

  const bien = loQuePasaElControl('pecchie', {
    es: ['abejas', 'abeja'], base: 'pecchia',
  });
  assert.deepEqual(bien.es, ['abejas', 'abeja']);
  assert.equal(bien.base, 'pecchia');
});

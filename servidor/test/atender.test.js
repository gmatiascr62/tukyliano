import test from 'node:test';
import assert from 'node:assert/strict';

import { atenderLaCharla, loQueMando, puedeEntrar } from '../src/atender.js';
import { BaseDeMentira } from './base_de_mentira.js';

/// Una charla mínima que sí sirve, para ir cambiándole una cosa por vez.
function unPedido(cambios = {}) {
  return {
    quien: 'celular-1',
    codigo: 'abc',
    saludo: 'Ciao! Sono Tuky. Come stai?',
    mensajes: [{ quien: 'yo', texto: 'sto bene' }],
    ...cambios,
  };
}

/// Lo de afuera, todo de mentira: ni internet, ni base, ni cuota.
function unMundo(cambios = {}) {
  return {
    base: new BaseDeMentira(),
    clave: 'la-clave',
    permitidos: [],
    topes: { deCadaUno: 60, deTodos: 2000 },
    traer: contesta('Benissimo! E tu?'),
    ahora: new Date('2026-10-24T12:00:00Z'),
    ...cambios,
  };
}

/// Un fetch de mentira que devuelve lo que Gemini devolvería.
function contesta(texto) {
  return async () =>
    new Response(
      JSON.stringify({ candidates: [{ content: { parts: [{ text: texto }] } }] }),
      { status: 200 },
    );
}

/// Un fetch de mentira que falla con un código.
function falla(estado, cuerpo = '') {
  return async () => new Response(cuerpo, { status: estado });
}

test('una charla bien armada devuelve lo que contestó Tuky', async () => {
  const salida = await atenderLaCharla(unPedido(), unMundo());

  assert.equal(salida.status, 200);
  assert.deepEqual(await salida.json(), { texto: 'Benissimo! E tu?' });
});

test('la clave no viaja de vuelta nunca', async () => {
  const salida = await atenderLaCharla(unPedido(), unMundo());

  assert.ok(!(await salida.text()).includes('la-clave'));
});

test('lo que se le manda a Google lleva la clave y la charla', async () => {
  let aDonde = null;
  let conQue = null;
  const mundo = unMundo({
    traer: async (url, opciones) => {
      aDonde = url;
      conQue = JSON.parse(opciones.body);
      return contesta('ok')();
    },
  });

  await atenderLaCharla(unPedido(), mundo);

  assert.ok(aDonde.includes('key=la-clave'));
  assert.equal(conQue.contents[1].parts[0].text, 'Ciao! Sono Tuky. Come stai?');
  assert.equal(conQue.contents.at(-1).parts[0].text, 'sto bene');
});

test('sin código, cuando hay lista, no entra', async () => {
  const mundo = unMundo({ permitidos: ['uno', 'dos'] });

  const salida = await atenderLaCharla(unPedido({ codigo: '' }), mundo);

  assert.equal(salida.status, 401);
  assert.equal((await salida.json()).error, 'sinCodigo');
});

test('con un código que no está en la lista, tampoco', async () => {
  const mundo = unMundo({ permitidos: ['uno', 'dos'] });

  const salida = await atenderLaCharla(unPedido({ codigo: 'tres' }), mundo);

  assert.equal((await salida.json()).error, 'codigoQueNoEs');
});

test('con un código de la lista, sí', async () => {
  const mundo = unMundo({ permitidos: ['uno', 'dos'] });

  const salida = await atenderLaCharla(unPedido({ codigo: ' dos ' }), mundo);

  assert.equal(salida.status, 200);
});

test('con la lista vacía entra cualquiera', () => {
  // Es a propósito, para poder probar antes de repartir códigos. El README
  // dice por qué no se puede dejar así con el APK publicado.
  assert.ok(puedeEntrar('', []));
  assert.ok(puedeEntrar(undefined, []));
});

test('al llegar al tope de la persona, corta y no le pide a Google', async () => {
  let fuiAGoogle = false;
  const mundo = unMundo({
    topes: { deCadaUno: 2, deTodos: 2000 },
    traer: async () => {
      fuiAGoogle = true;
      return contesta('ok')();
    },
  });

  await atenderLaCharla(unPedido(), mundo);
  await atenderLaCharla(unPedido(), mundo);
  fuiAGoogle = false;
  const tercero = await atenderLaCharla(unPedido(), mundo);

  assert.equal(tercero.status, 429);
  assert.equal((await tercero.json()).error, 'topeDeLaPersona');
  assert.equal(fuiAGoogle, false, 'pasado el tope no se gasta cuota');
});

test('el tope de uno no deja sin mensajes a los demás', async () => {
  const mundo = unMundo({ topes: { deCadaUno: 1, deTodos: 2000 } });

  await atenderLaCharla(unPedido({ quien: 'celular-1' }), mundo);
  const suyo = await atenderLaCharla(unPedido({ quien: 'celular-1' }), mundo);
  const ajeno = await atenderLaCharla(unPedido({ quien: 'celular-2' }), mundo);

  assert.equal(suyo.status, 429);
  assert.equal(ajeno.status, 200);
});

test('el tope del servidor corta a todos', async () => {
  const mundo = unMundo({ topes: { deCadaUno: 60, deTodos: 2 } });

  await atenderLaCharla(unPedido({ quien: 'celular-1' }), mundo);
  await atenderLaCharla(unPedido({ quien: 'celular-2' }), mundo);
  const tercero = await atenderLaCharla(unPedido({ quien: 'celular-3' }), mundo);

  assert.equal((await tercero.json()).error, 'topeDelServidor');
});

test('los contadores son de cada día', async () => {
  const base = new BaseDeMentira();
  const topes = { deCadaUno: 1, deTodos: 2000 };

  const hoy = unMundo({ base, topes, ahora: new Date('2026-10-24T23:00:00Z') });
  await atenderLaCharla(unPedido(), hoy);
  const segundo = await atenderLaCharla(unPedido(), hoy);
  assert.equal(segundo.status, 429);

  const manana = unMundo({ base, topes, ahora: new Date('2026-10-25T01:00:00Z') });
  const otroDia = await atenderLaCharla(unPedido(), manana);
  assert.equal(otroDia.status, 200, 'al otro día se renueva');
});

test('lo que guarda es solo quién, qué día y cuántos', async () => {
  const base = new BaseDeMentira();

  await atenderLaCharla(unPedido(), unMundo({ base }));

  // Ni el texto de la charla ni la respuesta quedan en ningún lado.
  const todo = JSON.stringify([...base.filas.entries()]);
  assert.ok(!todo.includes('sto bene'));
  assert.ok(!todo.includes('Benissimo'));
});

test('la cuota agotada de Google se cuenta como tal', async () => {
  const salida = await atenderLaCharla(
    unPedido(),
    unMundo({ traer: falla(429) }),
  );

  assert.equal((await salida.json()).error, 'cuota');
});

test('una clave mala es un problema nuestro, no del alumno', async () => {
  const salida = await atenderLaCharla(
    unPedido(),
    unMundo({ traer: falla(403, 'API key not valid') }),
  );

  const dicho = await salida.json();
  assert.equal(salida.status, 500);
  // No se le dice "tu clave no sirve": él no tiene ninguna clave.
  assert.ok(!dicho.mensaje.toLowerCase().includes('tu clave'));
});

test('si Google no contesta nada, se avisa y no se rompe', async () => {
  const mundo = unMundo({
    traer: async () => new Response(JSON.stringify({ candidates: [] }), { status: 200 }),
  });

  const salida = await atenderLaCharla(unPedido(), mundo);

  assert.equal((await salida.json()).error, 'sinRespuesta');
});

test('un pedido que no se entiende no llega a Google', async () => {
  let fuiAGoogle = false;
  const mundo = unMundo({
    traer: async () => {
      fuiAGoogle = true;
      return contesta('ok')();
    },
  });

  for (const roto of [
    null,
    'un texto',
    unPedido({ quien: '' }),
    unPedido({ saludo: '' }),
    unPedido({ mensajes: [] }),
    unPedido({ mensajes: [{ quien: 'otro', texto: 'hola' }] }),
    unPedido({ mensajes: [{ quien: 'yo', texto: '' }] }),
    // El último tiene que ser del alumno: si no, no hay qué contestar.
    unPedido({ mensajes: [{ quien: 'ia', texto: 'Ciao!' }] }),
  ]) {
    const salida = await atenderLaCharla(roto, mundo);
    assert.equal(salida.status, 400, `tendría que rechazar: ${JSON.stringify(roto)}`);
  }

  assert.equal(fuiAGoogle, false, 'un pedido roto no gasta cuota');
});

test('acepta una charla larga con los dos lados', () => {
  const pedido = loQueMando(
    unPedido({
      mensajes: [
        { quien: 'yo', texto: 'ciao' },
        { quien: 'ia', texto: 'Ciao! Come stai?' },
        { quien: 'yo', texto: 'bene' },
      ],
    }),
  );

  assert.equal(pedido.mensajes.length, 3);
});

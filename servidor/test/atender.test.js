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

/// Lo de afuera, todo de mentira: ni modelo, ni base, ni cuota.
function unMundo(cambios = {}) {
  return {
    base: new BaseDeMentira(),
    ia: contesta('Benissimo! E tu?'),
    modelo: '@cf/un/modelo',
    permitidos: [],
    topes: { deCadaUno: 60, deTodos: 2000 },
    ahora: new Date('2026-10-24T12:00:00Z'),
    ...cambios,
  };
}

/// Workers AI de mentira: un objeto con run(), que es todo lo que se usa.
function contesta(texto) {
  return { async run() { return { response: texto }; } };
}

/// Workers AI de mentira que se rompe. Lo que llega del de verdad es una
/// excepción con un texto, no un código de estado.
function falla(queDice) {
  return { async run() { throw new Error(queDice); } };
}

test('una charla bien armada devuelve lo que contestó Tuky', async () => {
  const salida = await atenderLaCharla(unPedido(), unMundo());

  assert.equal(salida.status, 200);
  assert.deepEqual(await salida.json(), { texto: 'Benissimo! E tu?' });
});

test('le manda al modelo las instrucciones, el saludo y la charla', async () => {
  let cual = null;
  let conQue = null;
  const mundo = unMundo({
    ia: {
      async run(modelo, opciones) {
        cual = modelo;
        conQue = opciones;
        return { response: 'ok' };
      },
    },
  });

  await atenderLaCharla(unPedido(), mundo);

  assert.equal(cual, '@cf/un/modelo');
  assert.equal(conQue.messages[0].role, 'system');
  assert.equal(conQue.messages[1].content, 'Ciao! Sono Tuky. Come stai?');
  assert.equal(conQue.messages.at(-1).content, 'sto bene');
  assert.equal(conQue.messages.at(-1).role, 'user');
});

test('cuál modelo contesta se decide afuera, no acá', async () => {
  // Es lo que deja cambiar de modelo tocando un renglón de wrangler.toml, sin
  // publicar un APK ni que nadie instale nada.
  let cual = null;
  const mundo = unMundo({
    modelo: '@cf/otro/modelo',
    ia: { async run(modelo) { cual = modelo; return { response: 'ok' }; } },
  });

  await atenderLaCharla(unPedido(), mundo);

  assert.equal(cual, '@cf/otro/modelo');
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

test('al llegar al tope de la persona, corta y no gasta neuronas', async () => {
  let fuiAlModelo = false;
  const mundo = unMundo({
    topes: { deCadaUno: 2, deTodos: 2000 },
    ia: {
      async run() {
        fuiAlModelo = true;
        return { response: 'ok' };
      },
    },
  });

  await atenderLaCharla(unPedido(), mundo);
  await atenderLaCharla(unPedido(), mundo);
  fuiAlModelo = false;
  const tercero = await atenderLaCharla(unPedido(), mundo);

  assert.equal(tercero.status, 429);
  assert.equal((await tercero.json()).error, 'topeDeLaPersona');
  assert.equal(fuiAlModelo, false, 'pasado el tope no se gasta cuota');
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

test('la cuota agotada del día se cuenta como tal', async () => {
  // Workers AI no devuelve un 429: tira una excepción y hay que leerla.
  for (const queDice of [
    'Capacity temporarily exceeded',
    'rate limit reached',
    'error 5035: billing required',
  ]) {
    const salida = await atenderLaCharla(
      unPedido(),
      unMundo({ ia: falla(queDice) }),
    );

    assert.equal((await salida.json()).error, 'cuota', queDice);
  }
});

test('que el modelo se caiga es un problema nuestro, no del alumno', async () => {
  const salida = await atenderLaCharla(
    unPedido(),
    unMundo({ ia: falla('Internal error') }),
  );

  const dicho = await salida.json();
  assert.equal(salida.status, 502);
  // No se le habla de claves ni de modelos: no tiene ninguno.
  assert.ok(!dicho.mensaje.toLowerCase().includes('clave'));
});

test('si el modelo no contesta nada, se avisa y no se rompe', async () => {
  for (const vacio of [{}, { response: '' }, { response: '   ' }, null]) {
    const mundo = unMundo({ ia: { async run() { return vacio; } } });

    const salida = await atenderLaCharla(unPedido(), mundo);

    assert.equal((await salida.json()).error, 'sinRespuesta');
  }
});

test('un pedido que no se entiende no llega al modelo', async () => {
  let fuiAlModelo = false;
  const mundo = unMundo({
    ia: {
      async run() {
        fuiAlModelo = true;
        return { response: 'ok' };
      },
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

  assert.equal(fuiAlModelo, false, 'un pedido roto no gasta cuota');
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

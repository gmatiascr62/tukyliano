import test from 'node:test';
import assert from 'node:assert/strict';

import {
  contenidos,
  esSoloTraduccion,
  pedidosDeTraduccion,
  textoParaLaIa,
} from '../src/charla.js';
import { promptDeTuky } from '../src/prompt.js';

test('las instrucciones van primero, como turno del alumno', () => {
  const turnos = contenidos({
    saludo: 'Ciao! Sono Tuky. Che musica ascolti?',
    mensajes: [{ quien: 'yo', texto: 'mi piace il rock' }],
  });

  assert.equal(turnos[0].role, 'user');
  assert.equal(turnos[0].parts[0].text, promptDeTuky);
});

test('el saludo va como turno de Tuky, no del alumno', () => {
  // Es lo que el alumno ya vio en pantalla: si no coincidiera, la charla que
  // la IA recuerda no sería la que se está teniendo.
  const turnos = contenidos({
    saludo: 'Ciao! Sono Tuky. Che musica ascolti?',
    mensajes: [{ quien: 'yo', texto: 'mi piace il rock' }],
  });

  assert.equal(turnos[1].role, 'model');
  assert.equal(turnos[1].parts[0].text, 'Ciao! Sono Tuky. Che musica ascolti?');
});

test('la charla va en orden y con quién dijo cada cosa', () => {
  const turnos = contenidos({
    saludo: 'Ciao!',
    mensajes: [
      { quien: 'yo', texto: 'mi chiamo Matías' },
      { quien: 'ia', texto: 'Piacere! Dove abiti?' },
      { quien: 'yo', texto: 'abito a Buenos Aires' },
    ],
  });

  assert.deepEqual(
    turnos.slice(2).map((t) => [t.role, t.parts[0].text]),
    [
      ['user', 'mi chiamo Matías'],
      ['model', 'Piacere! Dove abiti?'],
      ['user', 'abito a Buenos Aires'],
    ],
  );
});

test('las instrucciones tienen el formato de la corrección', () => {
  // Es lo que la app busca para pintar la corrección aparte.
  assert.ok(promptDeTuky.includes('Correzione:'));
});

/// El prompt viene cortado en renglones de 78 caracteres, así que una frase
/// puede estar partida al medio. Esto busca por lo que dice, no por dónde
/// cayeron los saltos de renglón: si mañana se reacomoda el texto, el test
/// tiene que seguir valiendo.
function dice(frase) {
  const unaLinea = (t) => t.replace(/\s+/g, ' ');
  return unaLinea(promptDeTuky).includes(unaLinea(frase));
}

test('le prohíbe corregir repitiendo la frase tal cual', () => {
  // Sin esto, a una frase bien escrita le contesta "Correzione:" y la misma
  // frase, que al que aprende le hace creer que estaba mal.
  assert.ok(dice('repita la frase tal como la escribió'));
});

test('le dice que lo normal es NO corregir', () => {
  // Corregir todo el tiempo convierte la charla en un examen. La corrección es
  // la excepción, y eso tiene que estar dicho.
  assert.ok(dice('Lo normal es NO corregir'));
});

test('no corrige por poner el sujeto, que no es un error', () => {
  // En italiano se puede omitir, pero decirlo también está bien. Sin esta
  // línea corregía "io sono" a "sono" y enseñaba mal.
  assert.ok(dice('Poner el sujeto (io, tu, lui) no es un error'));
});

test('no hay ninguna clave pegada en el código', () => {
  // La clave vive en un secreto de Cloudflare. Esto es la red por si alguna
  // vez alguien la pega "un ratito para probar".
  assert.ok(!/AIza[0-9A-Za-z_-]{10,}/.test(promptDeTuky));
});

test('reconoce lo que se pidió traducir', () => {
  assert.deepEqual(pedidosDeTraduccion('quiero #manteca# y #pan#'), [
    'manteca',
    'pan',
  ]);
  assert.deepEqual(pedidosDeTraduccion('no hay nada'), []);
  // Una almohadilla sola no abre un pedido.
  assert.deepEqual(pedidosDeTraduccion('cuesta #5'), []);
});

test('distingue ir al diccionario de charlar', () => {
  assert.ok(esSoloTraduccion('#manteca#'));
  assert.ok(esSoloTraduccion('  #manteca#  '));
  assert.ok(!esSoloTraduccion('mi serve la #manteca#'));
  assert.ok(!esSoloTraduccion('sin almohadillas'));
});

test('el recordatorio de traducir va solo en el último mensaje', () => {
  const turnos = contenidos({
    saludo: 'Ciao!',
    mensajes: [
      { quien: 'yo', texto: 'dammi la #manteca#' },
      { quien: 'ia', texto: 'burro' },
      { quien: 'yo', texto: 'e il #pane#' },
    ],
  });

  // El viejo queda tal cual: recordárselo de nuevo ensucia el historial.
  assert.equal(turnos[2].parts[0].text, 'dammi la #manteca#');
  assert.ok(turnos[4].parts[0].text.includes('#pane# = #(traducción)#'));
});

test('un mensaje sin almohadillas no se toca', () => {
  assert.equal(textoParaLaIa('ciao, come stai?'), 'ciao, come stai?');
});

test('al pedido suelto se le pide que no siga la charla', () => {
  const texto = textoParaLaIa('#manteca#');
  assert.ok(texto.includes('no es charla'));
  assert.ok(texto.includes('sin preguntas'));
});

test('nunca le dice para qué lado traducir sin darle los dos', () => {
  // Adivinar el idioma con reglas fallaba la mitad de las veces: "ventana" y
  // "finestra" se escriben demasiado parecido.
  const texto = textoParaLaIa('mi serve la #manteca#');
  assert.ok(texto.includes('Si está en español'));
  assert.ok(texto.includes('si está en italiano'));
});

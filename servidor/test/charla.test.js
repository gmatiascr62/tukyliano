import test from 'node:test';
import assert from 'node:assert/strict';

import { contenidos, turno } from '../src/charla.js';
import { promptDeTuky } from '../src/prompt.js';

const UNA_CHARLA = {
  saludo: 'Ciao! Sono Tuky. Come stai?',
  mensajes: [
    { quien: 'yo', texto: 'sto bene' },
    { quien: 'ia', texto: 'Che bello! Cosa fai oggi?' },
    { quien: 'yo', texto: 'lavoro' },
  ],
};

test('las instrucciones van como turno del sistema', () => {
  const turnos = contenidos(UNA_CHARLA);

  assert.equal(turnos[0].role, 'system');
  assert.equal(turnos[0].content, promptDeTuky);
});

test('el saludo va como turno de Tuky, no del alumno', () => {
  // Si fuera del alumno, el modelo creería que el alumno se saludó solo.
  const turnos = contenidos(UNA_CHARLA);

  assert.equal(turnos[1].role, 'assistant');
  assert.equal(turnos[1].content, 'Ciao! Sono Tuky. Come stai?');
});

test('la charla va en orden y con quién dijo cada cosa', () => {
  const turnos = contenidos(UNA_CHARLA);

  assert.deepEqual(turnos.slice(2), [
    turno('user', 'sto bene'),
    turno('assistant', 'Che bello! Cosa fai oggi?'),
    turno('user', 'lavoro'),
  ]);
});

test('el último turno es siempre del alumno', () => {
  // Es lo que hace que el modelo conteste en vez de seguir hablando solo.
  const turnos = contenidos(UNA_CHARLA);

  assert.equal(turnos.at(-1).role, 'user');
});

test('el mensaje del alumno se manda tal cual se escribió', () => {
  // Antes acá se le colgaba un recordatorio sobre las almohadillas. Las
  // traducciones ahora las contesta el diccionario de la app, así que el
  // modelo recibe la frase y nada más.
  const turnos = contenidos({
    saludo: 'Ciao!',
    mensajes: [{ quien: 'yo', texto: 'mi serve la manteca' }],
  });

  assert.equal(turnos.at(-1).content, 'mi serve la manteca');
});

test('las instrucciones tienen el formato de la corrección', () => {
  assert.ok(promptDeTuky.includes('Volevi dire:'));
  assert.ok(promptDeTuky.includes('italiano simple'));
});

test('la corrección va entera, no a medias', () => {
  // Salían arregladas por la mitad: "a lavoro" donde va "al lavoro".
  assert.ok(promptDeTuky.includes('de punta a punta'));
});

test('si la frase está bien, no hay renglón de corrección', () => {
  assert.ok(promptDeTuky.includes('no pongas ese renglón'));
});

test('la marca de la corrección está en italiano', () => {
  // La regla 1 pide escribir siempre en italiano. Un renglón en castellano
  // la contradice, y dos instrucciones peleadas es lo que peor sigue un
  // modelo. La app lo muestra traducido si hace falta.
  assert.ok(!promptDeTuky.includes('Quisiste decir'));
});

test('no corrige por poner el sujeto, que no es un error', () => {
  assert.ok(promptDeTuky.includes('nunca corrijas por eso'));
});

test('ya no dice nada de las almohadillas', () => {
  // Eran tres de las nueve reglas y el modelo igual se equivocaba. Las
  // traducciones salen del diccionario y al modelo le quedó un solo trabajo.
  assert.ok(!promptDeTuky.includes('#'));
  assert.ok(!promptDeTuky.includes('traducción'));
});

test('son cuatro reglas y ninguna más', () => {
  // Eran nueve. Cada una que se va es una menos con la que confundirse, y
  // este test está para que no vuelvan a crecer sin que nadie lo decida.
  for (const regla of ['1.', '2.', '3.', '4.']) {
    assert.ok(promptDeTuky.includes(`\n${regla}`), `falta la regla ${regla}`);
  }
  assert.ok(!promptDeTuky.includes('\n5.'), 'sobra una regla');
});

test('no hay ninguna clave pegada en el código', () => {
  assert.ok(!/AIza[0-9A-Za-z_-]{10,}/.test(promptDeTuky));
});

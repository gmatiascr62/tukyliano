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

test('le dice quién es', () => {
  // Sin esto lee el saludo "Ciao! Sono Tuky" como si le hablaran a él y
  // contesta "Ciao Tuky! Sto bene, grazie". Se cree que es el alumno.
  assert.ok(promptDeTuky.includes('Sos Tuky'));
});

test('le dice cuánto contestar', () => {
  // Sin esto contesta párrafos de asistente, con opciones y despedida.
  assert.ok(promptDeTuky.includes('dos o tres frases'));
  assert.ok(promptDeTuky.includes('terminá con una pregunta'));
});

test('le da el formato de la corrección', () => {
  // Corregir lo hace solo; ponerlo donde la app lo encuentre, no.
  assert.ok(promptDeTuky.includes('Volevi dire:'));
});

test('son tres cosas y nada más', () => {
  // Cada línea de más es una con la que el modelo se puede confundir. Este
  // test está para que no vuelvan a crecer sin que nadie lo decida.
  const renglones = promptDeTuky.split('\n').filter((r) => r.trim() !== '');
  assert.ok(renglones.length <= 7, `son ${renglones.length} renglones`);
});

test('no hay ninguna clave pegada en el código', () => {
  assert.ok(!/AIza[0-9A-Za-z_-]{10,}/.test(promptDeTuky));
});

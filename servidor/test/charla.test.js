import test from 'node:test';
import assert from 'node:assert/strict';

import { contenidos, turno } from '../src/charla.js';
import {
  MARCA_DEL_FINAL,
  promptDe,
  promptDelBar,
  promptDeTuky,
} from '../src/prompt.js';

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

test('la escena del bar trae otras instrucciones', () => {
  const turnos = contenidos({ ...UNA_CHARLA, escena: 'bar' });

  assert.equal(turnos[0].content, promptDelBar);
});

test('sin escena va la charla libre', () => {
  // Un celular con un APK viejo no manda escena, y tiene que seguir andando.
  assert.equal(promptDe(undefined), promptDeTuky);
  assert.equal(promptDe('libre'), promptDeTuky);
});

test('una escena que no existe tampoco rompe nada', () => {
  assert.equal(promptDe('la farmacia'), promptDeTuky);
});

test('el barista sabe que es un barista', () => {
  // Sin esto vuelve a ser un asistente: explica, ofrece ayuda y da opciones.
  assert.ok(promptDelBar.includes('barista'));
  assert.ok(promptDelBar.includes('una o dos frases'));
});

test('el barista no adelanta la escena', () => {
  // La lista numerada de momentos no alcanzó: a un "quanto costa?" contestó
  // "Sono due euro. Ecco a te il resto. Arrivederci. FINE". Lo que lo frena
  // son las tres cosas que NO tiene que hacer.
  assert.ok(promptDelBar.includes('Contestá solo a lo último que dijo'));
  assert.ok(promptDelBar.includes('no pidió'));
  assert.ok(promptDelBar.includes('no te lo preguntó'));
  assert.ok(promptDelBar.includes('no te pagó'));
});

test('el barista sigue contestando después de corregir', () => {
  // Arreglado lo de adelantarse, apareció lo contrario: a "io volere un
  // caffè" contestó solo la corrección y nunca sirvió el café.
  assert.ok(promptDelBar.includes('seguí con lo que ibas a contestarle'));
});

test('la corrección del barista va entera en italiano', () => {
  // Las instrucciones están en castellano y se le contagiaba: devolvió
  // "Volevi decir:", con media marca en el idioma equivocado.
  assert.ok(promptDelBar.includes('entero en italiano'));
});

test('la frase equivocada se traduce literal, aunque suene mal', () => {
  // Arriba de la corrección va lo que escribió traducido palabra por
  // palabra. Sin el "aunque suene mal" el modelo traduce lo que QUISO
  // decir —"quiero un café"—, que se lee perfecto en castellano y entonces
  // no se ve ningún error, que es justo para lo que está el renglón.
  for (const prompt of [promptDelBar, promptDeTuky]) {
    assert.ok(prompt.includes('Hai scritto:'));
    assert.ok(prompt.includes('palabra por palabra'));
    assert.ok(prompt.includes('aunque suene mal'));
  }
});

test('el barista no hace el papel del cliente', () => {
  // Sin esto le contesta "Un caffè e un cornetto" a un "buongiorno" —pide él,
  // por el otro— y después de servir suelta "Prego. Quanto è?".
  assert.ok(promptDelBar.includes('las escribe él, no vos'));
});

test('el barista habla de tu, con el ejemplo al lado', () => {
  // Pedírselo sin más no alcanzaba: contestaba "ecco a lei" igual.
  assert.ok(promptDelBar.includes('ecco a te'));
});

test('el barista no escribe acotaciones de guion', () => {
  // Devolvió "(Espero tu respuesta para servirte)", y encima en castellano.
  assert.ok(promptDelBar.includes('entre paréntesis'));
});

test('el barista corrige con la misma marca que Tuky', () => {
  // Es la misma app la que la busca: dos marcas serían dos caminos.
  assert.ok(promptDelBar.includes('Volevi dire:'));
});

test('el barista cierra la escena recién al final', () => {
  // La marca es lo que deja que la app muestre la escena terminada. Si el
  // modelo no la pone no se rompe nada, pero sin pedirla no la pone nunca.
  assert.ok(promptDelBar.includes(MARCA_DEL_FINAL));
  // Atada a que ya le hayan pagado: suelta, la ponía al segundo mensaje.
  assert.ok(promptDelBar.includes('Cuando ya te pagó'));
});

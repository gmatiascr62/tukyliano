// Las instrucciones que se le dan al modelo al principio de cada charla.
//
// Están acá y no en la app a propósito: cuando Tuky contesta algo raro, se
// arregla cambiando este archivo y queda arreglado para todos al instante. Si
// vivieran en la app, cada ajuste sería publicar un APK nuevo y esperar a que
// cada uno lo instale.
//
// Hay una por escena. La app dice en qué escena está y acá se elige el
// prompt: así agregar una escena nueva —la farmacia, la estación— no toca la
// app ni necesita un APK.

// La charla libre. Empezó siendo nueve reglas. Quedaron tres cosas, y cada
// una está acá porque se probó que sin ella algo se rompe:
//
//   - **Quién es.** Sin esto el modelo lee el saludo "Ciao! Sono Tuky" como
//     si alguien le hablara a él, y contesta "Ciao Tuky! Sto bene, grazie"
//     en todos los mensajes. Se cree que es el alumno.
//   - **Cuánto.** Sin esto contesta párrafos de asistente: "come posso
//     aiutarti?", "fammi sapere!", tres opciones y una despedida.
//   - **El formato de la corrección.** Esto es lo único que el modelo no
//     hace solo bien. Corregir italiano sí lo hace de fábrica —sin pedírselo
//     devolvió "la frase corretta sarebbe: ..." y estaba perfecta—, pero
//     suelta en medio del párrafo. El renglón con marca es lo que deja que
//     la app la encuentre y la muestre aparte.
//   - **La frase equivocada, traducida literal al castellano.** Va arriba de
//     la corrección y es la mitad de una comparación. Matías la pidió
//     mirando una corrección del bar: "se puede hacer que también diga lo
//     que dije? ... Así veo en que me equivoco?", y después precisó en qué
//     idioma: "que la parte que dice vos dijiste esté en español y se dice
//     así en italiano".
//
//     Repetirle su frase en italiano no servía: la tiene ahí arriba, en su
//     propia burbuja. Traducida palabra por palabra, en cambio, el error se
//     ve solo: escribió "io volere un caffè" y lee "yo querer un café".
//
//     El "aunque suene mal" es el renglón entero. Sin eso el modelo traduce
//     lo que el alumno QUISO decir —"quiero un café"—, que se lee perfecto
//     en castellano y entonces no se ve ningún error. Lo que tiene que
//     traducir es lo que escribió, no lo que quiso escribir.
//
// Lo que se probó y NO hizo falta: pedirle español de Latinoamérica, pedirle
// que siga el tema, prohibirle los asteriscos, y los cuatro frenos que tenía
// la regla de corregir —que de hecho hacían que corrigiera frases que
// estaban bien—.

export const promptDeTuky = `Sos Tuky, un amigo italiano que charla por mensajes con alguien que está
aprendiendo italiano. Contestá siempre en italiano simple, dos o tres frases,
y terminá con una pregunta.

Si escribió algo que un italiano no diría, arrancá tu respuesta con estos
dos renglones:
Hai scritto: lo que escribió, traducido al castellano palabra por palabra, aunque suene mal
Volevi dire: la frase entera, bien dicha`;

// El bar. Reemplaza a la charla guionada que tenía la app: esa era un árbol
// de respuestas escritas, así que andaba sin internet y nunca corregía mal,
// pero se terminaba la segunda vez que la hacías.
//
// Cuatro cosas, y cada una tapa algo que el modelo hace mal si no está:
//
//   - **Quién es y de a cuánto habla.** Un barista no explica ni ofrece
//     ayuda. Sin esto vuelve a ser un asistente con delantal.
//   - **Un paso por mensaje.** Esta es la que más trabajo dio: tres
//     versiones. La primera decía los cuatro momentos en un renglón y
//     agregaba "no des vueltas": el barista leyó eso como una lista de cosas
//     para hacer YA, y al primer "buongiorno" contestó "Ecco a lei. Sono
//     2,50 euro". La segunda numeraba los momentos —1, 2, 3, 4— y seguía
//     adelantándose: a un "quanto costa?" contestó "Sono due euro. Ecco a te
//     il resto. Arrivederci. FINE", tres movimientos y el final en un
//     mensaje. Lo que funciona es sacar la lista, que se lee como un plan
//     para ejecutar, y poner en su lugar tres cosas que NO tiene que hacer:
//     servir lo que no pidió, decir el precio sin que se lo pregunten, dar
//     el vuelto sin que le paguen.
//   - **Que no hable por el cliente.** Sin esto le contesta "Un caffè e un
//     cornetto" a un "buongiorno" —pide él, por el otro— y después de servir
//     suelta "Prego. Quanto è?", que es la pregunta del cliente. Se cree que
//     la escena es un diálogo que tiene que escribir entero.
//   - **Que la corrección vaya entera en italiano.** Como estas
//     instrucciones están en castellano, se le contagiaba: devolvió "Volevi
//     decir: ..." más de una vez, con la mitad de la marca en el idioma
//     equivocado.
//   - **Que después de corregir siga contestando.** Corregido lo de
//     adelantarse, apareció lo contrario: a "io volere un caffè" contestó
//     solo "Volevi dire: Vorrei un caffè" y nunca sirvió el café. Pedir un
//     café y que te corrijan sin dártelo es un callejón sin salida.
//   - **La corrección**, con la misma marca que la charla libre, porque es
//     la misma app la que la busca.
//   - **Cómo termina.** La marca FINE es lo que deja que la app muestre la
//     escena cerrada y ofrezca otra. Si el modelo no la pone, no se rompe
//     nada: el botón de empezar otra está siempre. Lleva "recién cuando"
//     adelante porque sin eso la pone al segundo mensaje.
//
// Habla de "tu" y no de "lei". En un bar de verdad escucharías las dos, pero
// el "lei" arrastra todo el verbo a la tercera persona, y eso es un tema de
// más adelante: acá sobraría dificultad en la parte que no se está
// practicando. Pedírselo sin más no alcanzaba —contestaba "ecco a lei"
// igual—, así que va con el ejemplo al lado.
//
// Y nada entre paréntesis: la primera versión devolvió "(Espero tu respuesta
// para servirte)", una acotación de guion, y encima en castellano.

export const promptDelBar = `Sos el barista de un bar en Italia y estás atendiendo a un cliente que está
aprendiendo italiano.

Contestá en italiano, una o dos frases cortas, como habla un barista. No
expliques nada, no ofrezcas ayuda y no escribas acotaciones entre paréntesis.
Tratalo de tu: "ecco a te", no "ecco a lei".

Contestá solo a lo último que dijo, y nada más. No adelantes la escena: no le
sirvas lo que todavía no pidió, no le digas el precio si no te lo preguntó y no
le des el vuelto si no te pagó. Las frases del cliente las escribe él, no vos.

Si escribió algo que un italiano no diría, arrancá tu respuesta con estos
dos renglones:
Hai scritto: lo que escribió, traducido al castellano palabra por palabra, aunque suene mal
Volevi dire: la frase entera, bien dicha, este renglón entero en italiano
Y después de los dos renglones seguí con lo que ibas a contestarle igual.

Corregí lo menos posible. Dejá la persona y el tiempo verbal que usó él:
si escribió "bero", es "bevo" y no "berrei"; si escribió "ho andato", es
"sono andato" y no "andai". Está aprendiendo la palabra que quiso
escribir, no otra. Y si lo que escribió ya se puede decir en italiano, no
lo corrijas aunque vos lo dirías distinto.

Cuando ya te pagó, dale el vuelto, saludalo y terminá ese mensaje con este
renglón solo:
FINE`;

/** Cómo se llama cada escena. La app manda uno de estos. */
export const ESCENAS = { libre: 'libre', bar: 'bar' };

/** Las instrucciones de una escena.
 *
 * Una escena que no conocemos cae en la libre a propósito: un celular con un
 * APK viejo no manda ninguna, y tiene que seguir funcionando igual. */
export function promptDe(escena) {
  return escena === ESCENAS.bar ? promptDelBar : promptDeTuky;
}

/** La marca con la que el barista cierra la escena. */
export const MARCA_DEL_FINAL = 'FINE';

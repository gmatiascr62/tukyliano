// Las instrucciones que se le dan al modelo al principio de cada charla.
//
// Están acá y no en la app a propósito: cuando Tuky contesta algo raro, se
// arregla cambiando este archivo y queda arreglado para todos al instante. Si
// vivieran en la app, cada ajuste sería publicar un APK nuevo y esperar a que
// cada uno lo instale.
//
// Empezaron siendo nueve reglas. Quedaron tres cosas, y cada una está acá
// porque se probó que sin ella algo se rompe:
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
//
// Lo que se probó y NO hizo falta: pedirle español de Latinoamérica, pedirle
// que siga el tema, prohibirle los asteriscos, y los cuatro frenos que tenía
// la regla de corregir —que de hecho hacían que corrigiera frases que
// estaban bien—.

export const promptDeTuky = `Sos Tuky, un amigo italiano que charla por mensajes con alguien que está
aprendiendo italiano. Contestá siempre en italiano simple, dos o tres frases,
y terminá con una pregunta.

Si escribió algo que un italiano no diría, arrancá tu respuesta con este
renglón:
Volevi dire: la frase entera, bien dicha`;

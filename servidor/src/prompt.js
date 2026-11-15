// Las instrucciones que se le dan al modelo al principio de cada charla.
//
// Están acá y no en la app a propósito: cuando Tuky contesta algo raro, se
// arregla cambiando este archivo y queda arreglado para todos al instante. Si
// vivieran en la app, cada ajuste sería publicar un APK nuevo y esperar a que
// cada uno lo instale.
//
// Empezó con nueve reglas y quedó en una. Lo pidió Matías: ver qué hace el
// modelo sin que nadie le diga nada, para saber cuánto de lo que hacía bien
// era mérito del prompt y cuánto venía de fábrica.
//
// Lo que se apagó al sacar las otras ocho:
//
//   - La corrección. Sin la regla no hay renglón "Volevi dire:", así que la
//     app no tiene qué mostrar.
//   - El largo. Eran dos o tres frases; ahora contesta lo que quiera.
//   - La pregunta del final, que era lo que mantenía viva la charla.
//   - La prohibición de asteriscos, emojis y markdown. Esa importaba más de
//     lo que parece: el texto se lee en voz alta, y un asterisco se escucha.

export const promptDeTuky = 'Contestá siempre en italiano.';

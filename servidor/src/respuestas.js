// Qué le contesta el servidor a la app cuando algo no sale.
//
// La app ya sabe mostrar un cartel con un texto: lo que necesita es que el
// texto esté en criollo y diga qué hacer. Lo que devuelve Google viene en
// inglés y anidado, y termina en la pantalla de alguien que está aprendiendo
// italiano.
//
// El `motivo` es para el código —la app puede decidir según eso— y el
// `mensaje` es lo que se lee.

/// Por cada motivo: qué código HTTP le corresponde y qué se muestra.
const LOS_MOTIVOS = {
  // Del lado del que pide.
  sinCodigo: {
    estado: 401,
    mensaje: 'Esta app es por invitación. Pedile un código a Matías.',
  },
  codigoQueNoEs: {
    estado: 401,
    mensaje: 'Ese código no sirve. Fijate que esté bien copiado.',
  },
  pedidoRaro: {
    estado: 400,
    mensaje: 'No se entendió el mensaje. Probá de nuevo.',
  },

  // De los topes.
  topeDeLaPersona: {
    estado: 429,
    mensaje: 'Llegaste al límite de mensajes de hoy. Mañana se renueva.',
  },
  topeDelServidor: {
    estado: 429,
    mensaje: 'Hoy se usó mucho el chat y se llegó al límite. Mañana se renueva.',
  },

  // De Google.
  cuota: {
    estado: 429,
    mensaje: 'Se agotó la cuota de hoy. Mañana vuelve a andar.',
  },
  tardo: {
    estado: 504,
    mensaje: 'La respuesta tardó demasiado. Probá de nuevo.',
  },
  caido: {
    estado: 502,
    mensaje: 'La IA no está respondiendo. Probá en un rato.',
  },
  sinRespuesta: {
    estado: 502,
    mensaje: 'La IA no contestó nada. Probá de nuevo.',
  },

  // Nuestros. El alumno no puede hacer nada con estos, así que se le dice lo
  // mismo que con cualquier otra falla nuestra.
  clave: {
    estado: 500,
    mensaje: 'Hay un problema del lado del servidor. Avisale a Matías.',
  },
  pedido: {
    estado: 500,
    mensaje: 'Hay un problema del lado del servidor. Avisale a Matías.',
  },
  roto: {
    estado: 500,
    mensaje: 'Hay un problema del lado del servidor. Avisale a Matías.',
  },
};

export function comoSeMuestra(motivo) {
  return LOS_MOTIVOS[motivo] ?? LOS_MOTIVOS.roto;
}

export function queSalioMal(motivo) {
  const { estado, mensaje } = comoSeMuestra(motivo);
  return respuesta({ error: motivo, mensaje }, estado);
}

export function salioBien(texto) {
  return respuesta({ texto }, 200);
}

function respuesta(cuerpo, estado) {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });
}

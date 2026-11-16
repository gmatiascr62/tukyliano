// Una D1 de mentira, con lo justo para probar los contadores.
//
// Entiende una sola consulta: la que suma uno. No pretende ser SQLite — si
// mañana la consulta cambia, esto tiene que fallar fuerte y no seguir como si
// nada, que es lo peor que puede hacer un doble de prueba.

export class BaseDeMentira {
  /// Los contadores: 'quien\0dia' → cuántos.
  filas = new Map();

  /// Las palabras guardadas: palabra → {es, base, cuantas}.
  palabras = new Map();

  prepare(consulta) {
    if (consulta.includes('INSERT INTO mensajes')) {
      return new Contador(this.filas);
    }
    if (consulta.includes('palabras')) {
      return new Palabras(this.palabras, consulta);
    }
    throw new Error(`la base de mentira no sabe hacer esto:\n${consulta}`);
  }
}

class Contador {
  constructor(filas) {
    this.filas = filas;
  }

  bind(quien, dia) {
    this.clave = `${quien}\u0000${dia}`;
    return this;
  }

  async first() {
    const cuantos = (this.filas.get(this.clave) ?? 0) + 1;
    this.filas.set(this.clave, cuantos);
    return { cuantos };
  }
}

/// Las tres consultas de palabras.js, y nada más: si mañana aparece una
/// cuarta, esto tiene que fallar fuerte en vez de contestar cualquier cosa.
class Palabras {
  constructor(palabras, consulta) {
    this.palabras = palabras;
    if (consulta.includes('SELECT')) this.que = 'buscar';
    else if (consulta.includes('INSERT')) this.que = 'guardar';
    else if (consulta.includes('UPDATE')) this.que = 'visitar';
    else throw new Error(`no sé qué hacer con:\n${consulta}`);
  }

  bind(...valores) {
    this.valores = valores;
    return this;
  }

  async first() {
    if (this.que !== 'buscar') {
      throw new Error('first() solo sirve para buscar');
    }
    return this.palabras.get(this.valores[0]) ?? null;
  }

  async run() {
    const [palabra, es, base] = this.valores;
    if (this.que === 'guardar') {
      const antes = this.palabras.get(palabra);
      this.palabras.set(palabra, {
        es, base, cuantas: (antes?.cuantas ?? 0) + 1,
      });
    } else {
      const antes = this.palabras.get(palabra);
      if (antes) antes.cuantas += 1;
    }
    return { success: true };
  }
}

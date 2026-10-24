// Una D1 de mentira, con lo justo para probar los contadores.
//
// Entiende una sola consulta: la que suma uno. No pretende ser SQLite — si
// mañana la consulta cambia, esto tiene que fallar fuerte y no seguir como si
// nada, que es lo peor que puede hacer un doble de prueba.

export class BaseDeMentira {
  /// Lo guardado: 'quien\0dia' → cuántos.
  filas = new Map();

  prepare(consulta) {
    if (!consulta.includes('INSERT INTO mensajes')) {
      throw new Error(`la base de mentira no sabe hacer esto:\n${consulta}`);
    }
    return new Preparada(this.filas);
  }
}

class Preparada {
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

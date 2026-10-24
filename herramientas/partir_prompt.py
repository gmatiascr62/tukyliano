#!/usr/bin/env python3
"""Parte las instrucciones de la app en reglas y charla de ejemplo.

Las instrucciones llevan adentro una charla de ejemplo escrita como texto:

    Così parli:

    Studente: Ho una bicicletta.
    Tuky: Che bello! Di che colore è la tua bicicletta?

Eso le funciona a Qwen, que recibe las instrucciones en un bloque aparte. A
Gemma no: Gemma no tiene bloque de instrucciones, así que el ejemplo le llega
pegado adentro del primer mensaje del alumno. Entonces ve un diálogo escrito
dentro de lo que dijo el alumno, y lo imita: se escribe el turno del alumno él
mismo. Se midió, y le pasó con los tres publicadores del mismo modelo.

Esto saca el ejemplo del texto y lo devuelve como turnos, para poder dárselo
como lo que es: una charla que ya pasó. Las reglas quedan sin el ejemplo.

No es una copia de las instrucciones: las lee de las que saca el workflow del
código, así que cuando el prompt cambia, esto cambia con él. Si deja de
encontrar el ejemplo, falla en vez de devolver algo a medias.

Uso:
    partir_prompt.py <prompt.txt> <reglas-sin-ejemplo.txt> <ejemplo.txt>
"""

import re
import sys

# Cada turno del ejemplo empieza diciendo quién habla.
UN_TURNO = re.compile(r'^(Studente|Tuky)\s*:\s*(.*)$')

# Cómo se llama cada uno en las escenas.
COMO_SE_LLAMA = {'Studente': 'user', 'Tuky': 'assistant'}


def partir(prompt):
    """Devuelve (reglas sin el ejemplo, turnos del ejemplo)."""
    renglones = prompt.rstrip('\n').split('\n')

    reglas = []
    turnos = []
    for renglon in renglones:
        esTurno = UN_TURNO.match(renglon.strip())
        if esTurno:
            quien, dicho = esTurno.group(1), esTurno.group(2)
            turnos.append((COMO_SE_LLAMA[quien], dicho))
        else:
            reglas.append(renglon)

    if not turnos:
        sys.exit('ERROR: no encontré la charla de ejemplo adentro de las '
                 'instrucciones. Si se cambió cómo está escrita, hay que '
                 'cambiar esto.')

    # El renglón que presenta el ejemplo —"Così parli:"— queda colgado una vez
    # que el ejemplo no está. Se va con él: es lo único que termina en dos
    # puntos justo antes del diálogo.
    dondeEmpieza = next(i for i, r in enumerate(renglones)
                        if UN_TURNO.match(r.strip()))
    presenta = renglones[dondeEmpieza - 1].strip()
    if not presenta and dondeEmpieza >= 2:
        presenta = renglones[dondeEmpieza - 2].strip()
    if presenta.endswith(':'):
        reglas = [r for r in reglas if r.strip() != presenta]

    # Sacar renglones deja huecos de dos y tres vacíos seguidos.
    limpias = []
    for renglon in reglas:
        if not renglon.strip() and (not limpias or not limpias[-1].strip()):
            continue
        limpias.append(renglon)

    return '\n'.join(limpias).strip(), turnos


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)

    reglas, turnos = partir(open(argv[1], encoding='utf-8').read())

    with open(argv[2], 'w', encoding='utf-8') as salida:
        salida.write(reglas + '\n')
    with open(argv[3], 'w', encoding='utf-8') as salida:
        for quien, dicho in turnos:
            salida.write(f'{quien}: {dicho}\n')


if __name__ == '__main__':
    main(sys.argv)

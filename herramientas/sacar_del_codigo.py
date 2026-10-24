#!/usr/bin/env python3
"""Saca del código las instrucciones y la charla de ejemplo de la app.

Las instrucciones que de verdad corren en el celular salen de chat.dart, no de
una copia: una copia se desactualiza y entonces la prueba queda probando otra
cosa. Ya pasó, y es el error más caro de todos porque no se ve.

Son dos cosas, y van separadas porque así están en el código: las reglas
(promptDeChat) y la charla de ejemplo (ejemploDeCharla), que no está escrita
adentro de las reglas sino que se le da al modelo como turnos de verdad.

Si deja de encontrar cualquiera de las dos, falla en vez de devolver algo a
medias.

Uso:
    sacar_del_codigo.py <chat.dart> <reglas-salida.txt> <ejemplo-salida.txt>
"""

import re
import sys

# const String promptDeChat = '''...''';
LAS_REGLAS = re.compile(r"const String promptDeChat = '''\n(.*?)'''", re.S)

# const List<TurnoDeEjemplo> ejemploDeCharla = [ ... ];
EL_EJEMPLO = re.compile(
    r'const List<TurnoDeEjemplo> ejemploDeCharla = \[(.*?)\n\];', re.S)

# (quien: Quien.yo, dicho: 'Ho una bicicletta.'), con la coma y el salto de
# renglón donde quieran: el formateador de Dart los mueve según el largo.
UN_TURNO = re.compile(
    r"""quien:\s*Quien\.(yo|ia)\s*,\s*dicho:\s*(?:'([^']*)'|"([^"]*)")""",
    re.S)

# Cómo se llama cada uno en las escenas.
COMO_SE_LLAMA = {'yo': 'user', 'ia': 'assistant'}


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)

    codigo = open(argv[1], encoding='utf-8').read()

    reglas = LAS_REGLAS.search(codigo)
    if reglas is None:
        sys.exit('ERROR: no encontré promptDeChat en chat.dart. '
                 'Si se cambió cómo está escrito, hay que cambiar esto.')

    lista = EL_EJEMPLO.search(codigo)
    if lista is None:
        sys.exit('ERROR: no encontré ejemploDeCharla en chat.dart. '
                 'Si se cambió cómo está escrito, hay que cambiar esto.')

    turnos = UN_TURNO.findall(lista.group(1))
    if not turnos:
        sys.exit('ERROR: ejemploDeCharla está pero no le entendí los turnos.')

    with open(argv[2], 'w', encoding='utf-8') as salida:
        salida.write(reglas.group(1))

    with open(argv[3], 'w', encoding='utf-8') as salida:
        for quien, conComillaSimple, conComillaDoble in turnos:
            dicho = conComillaSimple or conComillaDoble
            salida.write(f'{COMO_SE_LLAMA[quien]}: {dicho}\n')


if __name__ == '__main__':
    main(sys.argv)

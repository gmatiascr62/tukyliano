#!/usr/bin/env python3
"""Arma el prompt de una charla en el formato que entiende cada modelo.

Un modelo no recibe la charla como texto suelto: recibe los turnos marcados
con unas palabras especiales que aprendió durante el entrenamiento. Cada
familia usa las suyas. Si se le mandan las de otra familia, el modelo igual
contesta algo —por eso el error no se ve— pero contesta peor, y entonces la
prueba termina midiendo la marca equivocada en vez de medir el modelo.

Esto existe para que comparar dos modelos de familias distintas sea honesto:
cada uno recibe la charla como corresponde.

Uso:
    armar_prompt.py <reglas.txt> <escena.txt> [--formato chatml|gemma]
                    [--ejemplo <turnos.txt>]

La escena es un renglón por turno, "quien: lo que dijo", con quien siendo
"user" o "assistant". Las reglas son las instrucciones del sistema.

Con --ejemplo, la charla de ejemplo va como turnos de verdad adelante de la
escena, en vez de escrita adentro de las instrucciones. Es el mismo archivo de
siempre, con el mismo formato que una escena.
"""

import sys


def turnos(ruta):
    """Los turnos de la escena, en orden: (quien, lo que dijo)."""
    for linea in open(ruta, encoding='utf-8'):
        linea = linea.rstrip('\n')
        if not linea.strip():
            continue
        quien, _, dicho = linea.partition(': ')
        yield quien, dicho


def enChatml(reglas, charla):
    """Lo que usan Qwen y varios más."""
    partes = [f'<|im_start|>system\n{reglas}<|im_end|>\n']
    for quien, dicho in charla:
        partes.append(f'<|im_start|>{quien}\n{dicho}<|im_end|>\n')
    partes.append('<|im_start|>assistant\n')
    return ''.join(partes)


def enGemma(reglas, charla):
    """Lo que usa Gemma, copiado de llama.cpp para no inventarlo.

    Dos diferencias que importan: al que contesta le dice "model" y no
    "assistant", y no tiene un lugar aparte para las instrucciones del
    sistema. Las instrucciones van pegadas adelante del primer turno que no
    sea del modelo —o sea, del primer mensaje del alumno— separadas por un
    renglón en blanco. Nuestras escenas arrancan con Tuky saludando, así que
    las instrucciones esperan a que hable el alumno, tal cual hace llama.cpp.
    """
    partes = []
    pendiente = reglas
    for quien, dicho in charla:
        quien = 'model' if quien == 'assistant' else quien
        partes.append(f'<start_of_turn>{quien}\n')
        if pendiente and quien != 'model':
            partes.append(f'{pendiente}\n\n')
            pendiente = ''
        partes.append(f'{dicho.strip()}<end_of_turn>\n')
    partes.append('<start_of_turn>model\n')
    return ''.join(partes)


FORMATOS = {'chatml': enChatml, 'gemma': enGemma}


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)

    formato = 'chatml'
    if '--formato' in argv:
        formato = argv[argv.index('--formato') + 1]
    if formato not in FORMATOS:
        sys.exit(f'ERROR: no sé armar el formato "{formato}". '
                 f'Los que sé: {", ".join(FORMATOS)}.')

    # El ejemplo va adelante de la escena y en el mismo formato: para el modelo
    # es una charla que ya pasó, no un texto que le están mostrando.
    charla = []
    if '--ejemplo' in argv:
        charla += list(turnos(argv[argv.index('--ejemplo') + 1]))
    charla += list(turnos(argv[2]))

    reglas = open(argv[1], encoding='utf-8').read().rstrip('\n')
    sys.stdout.write(FORMATOS[formato](reglas, charla))


if __name__ == '__main__':
    main(sys.argv)

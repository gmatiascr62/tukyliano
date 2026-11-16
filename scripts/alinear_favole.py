#!/usr/bin/env python3
"""Le pone tiempos a los renglones de las fábulas, de a todas.

    python alinear_favole.py                 # las que no tienen tiempos
    python alinear_favole.py --rehacer       # también las que ya tienen
    python alinear_favole.py favole_07_...   # solo esa

El texto sale del catálogo (flutter_app/assets/favole.json) y el audio
del release, que se baja una vez y queda cacheado. El resultado va a
scripts/tiempos/<id>.json, que es de donde lo levanta armar_favole.py.

**Nunca pisa un archivo que ya existe** salvo que se lo pidan con
--rehacer. Los tiempos de Il Lupo e il Cane los marcó Matías a mano
escuchando el audio, y son mejores que estos: el alineado automático
tiene medio segundo de error promedio contra ellos.

Requiere ffmpeg y whisper.cpp (ver alinear.py).
"""
import json
import os
import subprocess
import sys

import alinear

ACA = os.path.dirname(os.path.abspath(__file__))
# Cuál colección se alinea. Las dos tienen la misma forma —título, audio,
# duración, peso y renglones— y lo único que cambia es de qué archivo
# salen y bajo qué clave está la lista.
COLECCIONES = {
    'favole': ('favole.json', 'favole'),
    'pinocchio': ('pinocchio.json', 'capitulos'),
}
CUAL = os.environ.get('COLECCION', 'favole')
if CUAL not in COLECCIONES:
    raise SystemExit(f'no conozco la colección {CUAL!r}: '
                     f'{", ".join(COLECCIONES)}')
ELARCHIVO, LACLAVE = COLECCIONES[CUAL]

ELCATALOGO = os.path.join(ACA, '..', 'flutter_app', 'assets', ELARCHIVO)
LOSTIEMPOS = os.path.join(ACA, 'tiempos')
ELCACHE = os.environ.get(
    'FAVOLE_AUDIO', os.path.join(ACA, '..', '.cache', CUAL))


def elCatalogo():
    with open(ELCATALOGO, encoding='utf-8') as fh:
        return json.load(fh)


def losRenglones(favola):
    """El texto de la fábula, un renglón por elemento."""
    return [r['t'] if isinstance(r, dict) else r for r in favola['renglones']]


def bajarElAudio(base, archivo):
    """El audio en el cache, bajándolo si no está."""
    os.makedirs(ELCACHE, exist_ok=True)
    donde = os.path.join(ELCACHE, archivo)
    if os.path.exists(donde) and os.path.getsize(donde) > 10000:
        return donde
    # A un archivo aparte y recién al final el nombre definitivo, para
    # que una bajada cortada no deje un mp3 roto que la próxima vez se
    # da por bueno.
    bajando = donde + '.bajando'
    subprocess.run(['curl', '-sSL', '-o', bajando, f'{base}/{archivo}'],
                   check=True)
    if os.path.getsize(bajando) < 10000:
        os.remove(bajando)
        raise RuntimeError(f'no se pudo bajar {archivo}')
    os.replace(bajando, donde)
    return donde


def guardar(favola, resultado):
    os.makedirs(LOSTIEMPOS, exist_ok=True)
    donde = os.path.join(LOSTIEMPOS, f"{favola['id']}.json")
    with open(donde, 'w', encoding='utf-8') as fh:
        json.dump({
            'id': favola['id'],
            'titulo': favola['titulo'],
            'comoSeHizo': 'Alineado con scripts/alinear_favole.py '
                          '(whisper.cpp small, de a pedazos de 22 s).',
            'renglones': [{'desde': r['inicio'], 'hasta': r['fin'],
                           'texto': r['texto']} for r in resultado],
        }, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    return donde


def main():
    argumentos = sys.argv[1:]
    rehacer = '--rehacer' in argumentos
    cuales = [a for a in argumentos if not a.startswith('--')]

    problema = alinear.faltaAlgo()
    if problema:
        sys.exit(problema)

    catalogo = elCatalogo()
    favole = [f for f in catalogo[LACLAVE] if not cuales or f['id'] in cuales]
    if cuales and len(favole) != len(cuales):
        sys.exit(f'no encuentro en el catálogo: '
                 f'{set(cuales) - {f["id"] for f in favole}}')

    conQuejas = []
    for numero, favola in enumerate(favole, 1):
        yaEsta = os.path.join(LOSTIEMPOS, f"{favola['id']}.json")
        if os.path.exists(yaEsta) and not rehacer:
            print(f"[{numero}/{len(favole)}] {favola['titulo']}: ya tiene "
                  'tiempos, no lo toco')
            continue

        audio = bajarElAudio(catalogo['base'], favola['archivo'])
        renglones = losRenglones(favola)
        resultado, comoSalio = alinear.deUnAudio(audio, renglones)
        guardar(favola, resultado)

        porciento = (100 * comoSalio['coincidieron']
                     // max(comoSalio['palabras'], 1))
        print(f"[{numero}/{len(favole)}] {favola['titulo']}: "
              f'{len(renglones)} renglones, {comoSalio["pedazos"]} pedazos, '
              f'{porciento}% de las palabras, '
              f'{len(comoSalio["estimados"])} estimados')
        for queja in comoSalio['quejas']:
            print(f'    ojo: {queja}')
        if comoSalio['quejas']:
            conQuejas.append(favola['titulo'])

    if conQuejas:
        print()
        print('Para mirar a mano:', ', '.join(conQuejas))


if __name__ == '__main__':
    main()

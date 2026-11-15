#!/usr/bin/env python3
"""Alinea un audio con su texto y dice en qué segundo arranca cada renglón.

    python alinear.py audio.mp3 texto.txt [salida.json]

El resultado es una lista de {"inicio", "fin", "texto"}, un renglón por
línea del texto.

La idea, que es de Matías: whisper transcribe el audio pidiéndole un
segmento por palabra, y después se buscan esas palabras dentro del texto
de verdad. **No se usa lo que whisper escribió**, solo cuándo lo dijo. El
texto bueno sigue siendo el nuestro: whisper se equivoca seguido con
italiano del siglo XIX —escribe "all'erta" como "allerta", se come
elisiones, inventa puntuación— y nada de eso importa si solo le pedimos
los tiempos.

Por eso la comparación es sobre palabras normalizadas (sin tildes, sin
signos, en minúscula) y por bloques coincidentes: las palabras que
whisper oyó mal simplemente no coinciden, y el renglón se completa con
las que sí.

Requiere ffmpeg y whisper.cpp compilado (por defecto en ~/whisper.cpp).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from difflib import SequenceMatcher

DONDE_ESTA_WHISPER = os.path.expanduser(os.environ.get('WHISPER_DIR',
                                                       '~/whisper.cpp'))
ELPROGRAMA = os.path.join(DONDE_ESTA_WHISPER, 'build', 'bin', 'whisper-cli')
ELMODELO = os.path.join(DONDE_ESTA_WHISPER, 'models',
                        os.environ.get('WHISPER_MODEL', 'ggml-small.bin'))
IDIOMA = 'it'
HILOS = str(os.cpu_count() or 4)


def normalizar(palabra):
    """Deja la palabra comparable: minúscula, sin tildes y sin signos."""
    p = unicodedata.normalize('NFD', palabra.lower())
    p = ''.join(c for c in p if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9]', '', p)


def enPalabras(texto):
    """Separa por espacios y por apóstrofo: "all'erta" -> all, erta.

    El apóstrofo se parte a propósito. Whisper a veces escribe "allerta"
    y a veces "all'erta"; si no se parte, esa palabra nunca coincide con
    el texto y el renglón se queda sin tiempo.
    """
    texto = texto.replace('’', "'").replace('‘', "'")
    palabras = []
    for trozo in re.split(r"[\s']+", texto):
        limpia = normalizar(trozo)
        if limpia:
            palabras.append(limpia)
    return palabras


def transcribir(audio, pista, carpeta):
    """Las palabras que whisper oyó, cada una con su segundo.

    Devuelve una lista de (palabra, inicio, fin).
    """
    wav = os.path.join(carpeta, 'audio.wav')
    subprocess.run(
        ['ffmpeg', '-y', '-loglevel', 'error', '-i', audio,
         '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wav],
        check=True,
    )
    base = os.path.join(carpeta, 'salida')
    subprocess.run(
        [ELPROGRAMA, '-m', ELMODELO, '-f', wav, '-l', IDIOMA, '-t', HILOS,
         # Un segmento por palabra: es lo que da los tiempos finos.
         '-ml', '1', '-sow',
         # La pista ayuda a que escriba parecido a nuestro texto.
         '--prompt', pista,
         '-oj', '-of', base, '-np'],
        check=True,
    )
    with open(base + '.json', encoding='utf-8') as fh:
        datos = json.load(fh)

    palabras = []
    for segmento in datos.get('transcription', []):
        inicio = segmento['offsets']['from'] / 1000
        fin = segmento['offsets']['to'] / 1000
        for palabra in enPalabras(segmento.get('text', '')):
            palabras.append((palabra, inicio, fin))
    return palabras


def alinear(renglones, palabras):
    """Le pone tiempos a cada renglón del texto.

    Devuelve (resultado, cuántas palabras coincidieron, cuántas había).
    """
    delTexto, deQueRenglon = [], []
    for numero, renglon in enumerate(renglones):
        for palabra in enPalabras(renglon):
            delTexto.append(palabra)
            deQueRenglon.append(numero)

    deWhisper = [p[0] for p in palabras]
    comparador = SequenceMatcher(None, delTexto, deWhisper, autojunk=False)

    tiempos = [[] for _ in renglones]
    for enElTexto, enWhisper, cuantas in comparador.get_matching_blocks():
        for i in range(cuantas):
            _, inicio, fin = palabras[enWhisper + i]
            tiempos[deQueRenglon[enElTexto + i]].append((inicio, fin))

    resultado = []
    for numero, renglon in enumerate(renglones):
        if tiempos[numero]:
            inicio = min(t[0] for t in tiempos[numero])
            fin = max(t[1] for t in tiempos[numero])
        else:
            inicio = fin = None
        resultado.append({'inicio': inicio, 'fin': fin, 'texto': renglon})

    rellenarLosHuecos(resultado, palabras)

    for i in range(len(resultado)):
        # Sin esto dos renglones se pintan a la vez en el borde.
        if i + 1 < len(resultado) and \
                resultado[i]['fin'] > resultado[i + 1]['inicio']:
            resultado[i]['fin'] = resultado[i + 1]['inicio']
        resultado[i]['inicio'] = round(resultado[i]['inicio'], 2)
        resultado[i]['fin'] = round(resultado[i]['fin'], 2)

    coincidieron = sum(n for _, _, n in comparador.get_matching_blocks())
    return resultado, coincidieron, len(delTexto)


def rellenarLosHuecos(resultado, palabras):
    """Los renglones donde no coincidió ninguna palabra.

    Se reparte el hueco entre el renglón anterior y el siguiente, a
    prorrata del largo de cada uno. Es una estimación, pero un renglón
    sin tiempo no se ilumina nunca, y uno estimado se ilumina casi
    cuando va: para seguir el audio con la vista alcanza.
    """
    cuantos = len(resultado)
    i = 0
    while i < cuantos:
        if resultado[i]['inicio'] is not None:
            i += 1
            continue
        hasta = i
        while hasta < cuantos and resultado[hasta]['inicio'] is None:
            hasta += 1

        desde = resultado[i - 1]['fin'] if i > 0 else 0.0
        if hasta < cuantos:
            final = resultado[hasta]['inicio']
        else:
            final = palabras[-1][2] if palabras else desde

        largos = [max(len(resultado[k]['texto']), 1) for k in range(i, hasta)]
        total = sum(largos)
        donde = desde
        for k, largo in zip(range(i, hasta), largos):
            cuanto = (final - desde) * largo / total
            resultado[k]['inicio'] = donde
            resultado[k]['fin'] = donde + cuanto
            donde += cuanto
        i = hasta


def faltaAlgo():
    """Qué falta para poder correr, o None si está todo."""
    for ruta, nombre in [(ELPROGRAMA, 'whisper-cli'), (ELMODELO, 'modelo')]:
        if not os.path.exists(ruta):
            return f'no encuentro el {nombre}: {ruta}'
    return None


def deUnAudio(audio, renglones):
    """Los tiempos de esos renglones en ese audio."""
    pista = ' '.join(renglones)[:400]
    with tempfile.TemporaryDirectory() as carpeta:
        palabras = transcribir(audio, pista, carpeta)
    return alinear(renglones, palabras)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    audio, texto = sys.argv[1], sys.argv[2]
    salida = sys.argv[3] if len(sys.argv) > 3 \
        else os.path.splitext(audio)[0] + '.json'

    problema = faltaAlgo()
    if problema:
        sys.exit(problema)

    with open(texto, encoding='utf-8') as fh:
        renglones = [r.strip() for r in fh if r.strip()]

    print('Transcribiendo con whisper…', file=sys.stderr)
    resultado, coincidieron, cuantas = deUnAudio(audio, renglones)

    with open(salida, 'w', encoding='utf-8') as fh:
        json.dump(resultado, fh, ensure_ascii=False, indent=2)

    porciento = 100 * coincidieron // max(cuantas, 1)
    print(f'Listo: {salida} ({len(resultado)} renglones, '
          f'{coincidieron}/{cuantas} palabras coincidieron = {porciento}%)')


if __name__ == '__main__':
    main()

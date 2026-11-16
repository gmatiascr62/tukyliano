#!/usr/bin/env python3
"""Arma assets/formas.json: de qué palabra viene cada forma conjugada.

    python3 -I armar_formas.py <kaikki-Italian.jsonl> <carpeta assets>

El archivo de entrada es el italiano de kaikki.org, que son 779 MB y no
viaja en el repo. Se baja de:
https://kaikki.org/dictionary/Italian/kaikki.org-dictionary-Italian.jsonl

**Por qué hace falta.** El diccionario de la app tiene 14.000 palabras y
están en su forma de diccionario: tiene "avere" y no "abbia", tiene
"affamato" y no "affamata". Medido sobre las veintidós fábulas: de las
1543 palabras distintas, solo el 39% se encontraba. Con esta tabla sube
al 68%, y lo que queda afuera ya no son conjugaciones.

En italiano del siglo XIX el agujero es peor, porque el verso corta las
palabras para que entren en el metro: "contar" por contare, "dicea" por
diceva, "avean" por avevano, "boccon" por boccone. Kaikki marca eso con
los tags apocopic, poetic, archaic y clipping, así que entra solo.

**Qué NO entra.** Kaikki mezcla, en el mismo campo, las formas de una
palabra con las palabras *derivadas* de ella: "cagnàccio" y "cagnolìno"
figuran como formas de "cane". Traducir "cagnolìno" por "perro" no es
horrible, pero "nepalese" por "Nepal" o "marittimo" por "mar" ya es
mentir, y mostrar la traducción equivocada es peor que no mostrar
ninguna: el que lee no tiene con qué darse cuenta. Así que la derivación
se descarta y solo pasan las formas de la misma palabra.
"""
import json
import re
import sys
import unicodedata

# Tags que delatan que la "forma" no es una forma.
#
# Tres grupos, y los tres salieron de mirar el archivo, no de suponer:
#
# 1. Metadatos que se filtran como si fueran palabras. Con table-tags la
#    "forma" es literalmente "irregular", y con inflection-template es
#    "it-conj".
# 2. El verbo auxiliar que le toca a cada verbo. Por esto "avére"
#    figuraba como forma de "dare".
# 3. Palabras derivadas, que son otra palabra: diminutivos, aumentativos,
#    despectivos, gentilicios y adjetivos de relación.
NIDEAHABLAR = {
    # metadatos
    'table-tags', 'inflection-template', 'error-unknown-tag',
    'abbreviation', 'initialism', 'uppercase', 'lowercase', 'enclitic',
    # el auxiliar del verbo, no una forma suya
    'auxiliary', 'transitive', 'intransitive', 'impersonal', 'subjective',
    'goal', 'person', 'also',
    # la misma palabra con los acentos de diccionario
    'canonical',
    # otra palabra, derivada de esta
    'diminutive', 'augmentative', 'pejorative', 'derogatory', 'endearing',
    'humorous', 'meliorative', 'ironic', 'offensive', 'specific',
    'demonym', 'adjective', 'relational', 'noun', 'adverb',
}


def sinTilde(palabra):
    """La palabra comparable: minúscula, sin tildes y sin signos.

    Importa más de lo que parece: kaikki escribe las formas con el acento
    de la sílaba tónica —"dàto", "darèbbe", "dò"— que nadie escribe al
    buscar.

    Los espacios se conservan. El diccionario de la app tiene 841 claves
    de más de una palabra ("acciaio inossidabile"), y normalizarlas sin
    espacio generaba bases que no son clave de nada: la forma se resolvía
    y después no había qué mostrar.
    """
    suelta = unicodedata.normalize('NFD', palabra.lower())
    suelta = ''.join(c for c in suelta if unicodedata.category(c) != 'Mn')
    suelta = re.sub(r"[^a-z0-9' ]", ' ', suelta)
    return re.sub(r'\s+', ' ', suelta).strip()


def esUnaPalabra(forma):
    """Si eso puede ser una palabra italiana y no un pedazo de tabla."""
    if len(forma) < 2 or len(forma) > 30:
        return False
    # Ni espacios ni guiones: lo que se toca en la pantalla es una palabra
    # sola, así que una locución nunca se va a buscar acá.
    return bool(re.fullmatch(r"[a-z][a-z']*", forma))


def puedeSerBase(base):
    """La base sí puede ser de más de una palabra: el diccionario tiene."""
    if len(base) < 2 or len(base) > 40:
        return False
    return bool(re.fullmatch(r"[a-z][a-z' ]*", base))


def deKaikki(ruta):
    """Lee el archivo de kaikki y devuelve (formas, cuántas se tiraron).

    `formas` es {forma: [base, ...]}, con las bases más confiables
    primero: las que Wiktionary declara explícitamente ("plural of X")
    antes que las que salen de la tabla de conjugación.
    """
    declaradas, deTabla = {}, {}
    tiradas = 0

    with open(ruta, encoding='utf-8') as fh:
        for linea in fh:
            try:
                entrada = json.loads(linea)
            except ValueError:
                continue
            if entrada.get('lang_code') != 'it':
                continue

            palabra = sinTilde(entrada.get('word') or '')
            if not esUnaPalabra(palabra):
                continue

            # 1. La entrada misma dice que es forma de otra: "andante" ->
            #    "present participle of andare". Lo escribió una persona,
            #    así que para los tiempos verbales es lo más confiable que
            #    hay.
            #
            #    Pero hay que filtrar por tags igual que la tabla: acá
            #    también entra "cagnolino" como "diminutive of cane", y
            #    eso es otra palabra. Era el agujero por donde se colaban
            #    los diminutivos.
            for sentido in entrada.get('senses', []):
                if set(sentido.get('tags') or []) & NIDEAHABLAR:
                    tiradas += 1
                    continue
                for deQuien in sentido.get('form_of') or []:
                    base = deQuien.get('word') if isinstance(deQuien, dict) \
                        else str(deQuien)
                    base = sinTilde(base or '')
                    if base and base != palabra and puedeSerBase(base):
                        declaradas.setdefault(palabra, [])
                        if base not in declaradas[palabra]:
                            declaradas[palabra].append(base)

            # 2. La tabla de conjugación de la entrada.
            for forma in entrada.get('forms') or []:
                tags = set(forma.get('tags') or [])
                if not tags or tags & NIDEAHABLAR:
                    tiradas += 1
                    continue
                cual = sinTilde(forma.get('form') or '')
                if not esUnaPalabra(cual) or cual == palabra:
                    continue
                if not puedeSerBase(palabra):
                    continue
                deTabla.setdefault(cual, [])
                if palabra not in deTabla[cual]:
                    deTabla[cual].append(palabra)

    for forma, bases in deTabla.items():
        declaradas.setdefault(forma, [])
        for base in bases:
            if base not in declaradas[forma]:
                declaradas[forma].append(base)

    return declaradas, tiradas


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    kaikki, assets = sys.argv[1], sys.argv[2]

    with open(f'{assets}/diccionario.json', encoding='utf-8') as fh:
        diccionario = json.load(fh)

    # Normalizada → la clave tal como está en el diccionario. Lo que se
    # guarda es la clave de verdad: la app busca diccionario[base] sin
    # normalizar nada, así que una base que no sea clave exacta no
    # encuentra nada y la forma es peso muerto.
    laClaveDeVerdad = {sinTilde(p): p for p in diccionario['it']}

    formas, tiradas = deKaikki(kaikki)

    # Solo sirve la forma cuya base se puede traducir y que no esté ya en
    # el diccionario. Lo demás es peso al que nadie va a llegar.
    utiles = {}
    for forma, bases in formas.items():
        if forma in laClaveDeVerdad:
            continue
        for base in bases:
            clave = laClaveDeVerdad.get(base)
            if clave:
                utiles[forma] = clave
                break

    salida = {
        'version': 1,
        'credito': 'Formas conjugadas de Wiktionary, vía kaikki.org '
                   '(wiktextract de Tatu Ylonen).',
        'licencia': 'CC BY-SA 4.0',
        'fuente': 'https://kaikki.org/dictionary/Italian/',
        'de': dict(sorted(utiles.items())),
    }
    texto = json.dumps(salida, ensure_ascii=False, separators=(',', ':'))
    with open(f'{assets}/formas.json', 'w', encoding='utf-8') as fh:
        fh.write(texto)

    print(f'formas en kaikki:      {len(formas)}')
    print(f'descartadas por tag:   {tiradas}')
    print(f'con base traducible:   {len(utiles)}')
    print(f'archivo:               {len(texto.encode()) / 1024:.0f} KB')


if __name__ == '__main__':
    main()

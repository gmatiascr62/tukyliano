#!/usr/bin/env python3
"""Arma el catálogo de Pinocchio a partir de LibriVox y Wikisource.

    python3 scripts/armar_pinocchio.py            # solo el catálogo
    python3 scripts/armar_pinocchio.py --bajar    # catálogo y audios

**Por qué Pinocchio y no otro.** Lo que decide no es cuánto dura el libro
sino cuánto dura un capítulo, porque esa es la sesión de quien escucha.
Cuore tiene capítulos de cuarenta minutos y Vita dei campi uno de
setenta y seis: eso no es "escuchar un rato", es un compromiso. Pinocchio
tiene treinta y seis pedazos de ocho minutos, cada uno una escena que se
cierra sola, que es la misma razón por la que funcionaron las fábulas.

Y es **más fácil** que las fábulas, aunque parezca al revés. La Fontaine
en verso del siglo XIX, con apócopes y el orden dado vuelta para que
entre el metro, es de lo más difícil que hay en italiano. Pinocchio es
prosa para chicos: frases cortas, diálogo, presente.

Dominio público las dos cosas: Collodi murió en 1890 y los lectores de
LibriVox ceden sus grabaciones a propósito. Se verifica antes de bajar.

**Dos diferencias con el script de las fábulas**, que vienen de que esto
es prosa:

1. El texto no está en la página de Wikisource: está transcluido del
   libro escaneado con <pages index=... />. Pedir el wikitexto crudo
   devuelve esa línea y nada más, así que se pide ya armado (action=parse).
2. Se parte por **oraciones**, no por párrafos. Un párrafo de prosa dura
   entre treinta segundos y un minuto, y un renglón iluminado de un
   minuto no sirve para seguir el audio: no te dice dónde va. Una oración
   dura lo que un verso.
"""

import argparse
import html
import json
import os
import re
import subprocess
import sys
import time

ACA = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ACA)
import armar_favole as favole  # noqa: E402  (reusa limpiar, enSegundos, traer)

DONDE = 'https://archive.org'
ITEM = 'avventure_pinocchio_librivox'

# De dónde los baja la app. Etiqueta propia y aparte de la del APK y de la
# de las fábulas: publicar una versión nueva de la app no toca los audios,
# y agregar un libro no obliga a volver a subir el otro.
BASE = 'https://github.com/gmatiascr62/tukyliano/releases/download/pinocchio-1'

CUANTOS_CAPITULOS = 36

WIKI = 'https://it.wikisource.org/w/api.php'
PAGINA = 'Le avventure di Pinocchio/Capitolo {}'

QUIEN_SOY = 'Tukyliano/1.0 (app de estudio de italiano)'

# Wikimedia corta a quien le pide seguido. No es un error ni algo que se
# arregle reintentando rápido: hay que ir despacio. Treinta y seis pedidos
# a este ritmo son unos diez minutos, y se hace una sola vez.
ESPERAR_ENTRE_PEDIDOS = 12
INTENTOS = 8


def pedirleAWikisource(parametros):
    """Un pedido, con la paciencia que Wikimedia pide."""
    orden = ['curl', '-sS', '-m', '120', '-A', QUIEN_SOY, '-G', WIKI]
    for clave, valor in parametros.items():
        orden += ['--data-urlencode', f'{clave}={valor}']

    for intento in range(INTENTOS):
        salida = subprocess.run(orden, capture_output=True)
        crudo = salida.stdout.decode('utf-8', 'replace')
        try:
            return json.loads(crudo)
        except json.JSONDecodeError:
            if intento == INTENTOS - 1:
                raise SystemExit(
                    'Wikisource no contestó JSON después de '
                    f'{INTENTOS} intentos.\n  dijo: {crudo[:160]!r}'
                )
            time.sleep(ESPERAR_ENTRE_PEDIDOS * (intento + 1))


# Lo que viene adelante del capítulo y no es el capítulo: los metadatos
# del libro escaneado y la hoja de estilos que Wikisource mete adentro del
# primer párrafo.
NO_ES_TEXTO = ('<dc:', '.mw-parser-output', 'mw-parser-output')


def elTextoDe(numero):
    """Los párrafos del capítulo, ya sin marcas ni basura."""
    datos = pedirleAWikisource({
        'action': 'parse', 'format': 'json', 'formatversion': '2',
        'prop': 'text', 'page': PAGINA.format(numero),
    })
    if 'error' in datos:
        raise SystemExit(f"capítulo {numero}: {datos['error'].get('info')}")

    crudo = datos['parse']['text']
    parrafos = []
    for pedazo in re.findall(r'<p[^>]*>(.*?)</p>', crudo, re.S):
        texto = re.sub(r'<[^>]+>', '', pedazo)
        texto = html.unescape(texto).strip()
        texto = re.sub(r'\s+', ' ', texto)
        if len(texto) < 3 or any(x in texto for x in NO_ES_TEXTO):
            continue
        parrafos.append(texto)
    return parrafos


# Dónde termina una oración: punto, signo o puntos suspensivos, seguidos
# de espacio y mayúscula o raya de diálogo.
FIN_DE_ORACION = re.compile(r'(?<=[.!?…])\s+(?=[«"—\-A-ZÀ-ÜÈÉÌÒÙ])')

# Una oración más corta que esto casi siempre es un pedazo que quedó
# suelto —"— No." — y sola en un renglón se ve rara. Se pega a la
# anterior.
MINIMO = 12


def enOraciones(parrafos):
    """Parte los párrafos en oraciones, que es lo que se ilumina.

    Un párrafo de prosa dura entre medio minuto y un minuto. Iluminar eso
    entero no te dice dónde va el audio: te dice en qué párrafo está, que
    ya lo sabías.
    """
    renglones = []
    for parrafo in parrafos:
        for oracion in FIN_DE_ORACION.split(parrafo):
            oracion = oracion.strip()
            if not oracion:
                continue
            if renglones and len(oracion) < MINIMO:
                renglones[-1] = f'{renglones[-1]} {oracion}'
            else:
                renglones.append(oracion)
    return renglones


def losAudios():
    """Los 36 capítulos del item, en orden, con su duración y su peso."""
    datos = favole.traer(ITEM)
    licencia = (datos['metadata'].get('licenseurl')
                or datos['metadata'].get('rights') or '')
    if not any(x in licencia for x in favole.LIBRES):
        raise SystemExit(f'el item no declara dominio público: {licencia!r}')

    archivos = [
        f for f in datos['files']
        if f.get('format') == '64Kbps MP3' and f.get('length')
    ]
    archivos.sort(key=lambda f: f['name'])
    if len(archivos) != CUANTOS_CAPITULOS:
        raise SystemExit(
            f'hay {len(archivos)} audios y esperaba {CUANTOS_CAPITULOS}'
        )
    return archivos


def main():
    discusion = argparse.ArgumentParser(description=__doc__)
    discusion.add_argument('--bajar', action='store_true',
                           help='bajar también los audios, para publicarlos')
    discusion.add_argument('--carpeta', default=os.path.join(ACA, '..',
                                                             '.cache',
                                                             'pinocchio'))
    dicho = discusion.parse_args()

    archivos = losAudios()
    print(f'{len(archivos)} capítulos en LibriVox', file=sys.stderr)

    capitulos = []
    for numero, archivo in enumerate(archivos, 1):
        parrafos = elTextoDe(numero)
        if not parrafos:
            raise SystemExit(f'el capítulo {numero} vino sin texto')

        # El primer párrafo es el resumen que encabeza cada capítulo
        # ("Come andò che Maestro Ciliegia..."). Sirve de título: es lo que
        # distingue un capítulo de otro en una lista de treinta y seis.
        titulo = parrafos[0]
        renglones = enOraciones(parrafos[1:] or parrafos)

        capitulos.append({
            'id': f'pinocchio_{numero:02d}',
            'numero': numero,
            'titulo': f'{numero}. {favole.limpiar(titulo)}',
            'archivo': archivo['name'],
            'segundos': favole.enSegundos(archivo['length']),
            'bytes': int(archivo['size']),
            'renglones': renglones,
        })
        print(f'  {numero:2d}/{len(archivos)}  {len(renglones):3d} renglones  '
              f"{capitulos[-1]['titulo'][:52]}", file=sys.stderr)
        time.sleep(ESPERAR_ENTRE_PEDIDOS)

    conTiempos = 0
    for capitulo in capitulos:
        marcados = favole.losTiemposMarcadosAMano(capitulo)
        if marcados is None:
            capitulo['renglones'] = [{'t': r} for r in capitulo['renglones']]
        else:
            conTiempos += 1
            capitulo['renglones'] = [
                {'t': m['texto'], 'desde': m['desde'], 'hasta': m['hasta']}
                for m in marcados
            ]
        del capitulo['numero']

    assets = os.path.join(ACA, '..', 'flutter_app', 'assets')
    donde = os.path.join(assets, 'pinocchio.json')
    with open(donde, 'w', encoding='utf-8') as fh:
        json.dump({
            'version': 1,
            'base': BASE,
            'titulo': 'Le avventure di Pinocchio',
            'autor': 'Carlo Collodi',
            'credito': 'Grabado por voluntarios de LibriVox. Dominio '
                       'público.',
            'textoDe': 'Wikisource, del original de 1883',
            'capitulos': capitulos,
        }, fh, ensure_ascii=False)
        fh.write('\n')

    duracion = sum(c['segundos'] for c in capitulos)
    pesan = sum(c['bytes'] for c in capitulos)
    print(f"\n{len(capitulos)} capítulos · {duracion // 3600} h "
          f"{duracion % 3600 // 60} min · {pesan / 1048576:.0f} MB")
    print(f'{conTiempos} con tiempos')
    print(f'catálogo en {os.path.abspath(donde)}')

    if dicho.bajar:
        bajarlos(archivos, dicho.carpeta)


def bajarlos(archivos, carpeta):
    os.makedirs(carpeta, exist_ok=True)
    for archivo in archivos:
        donde = os.path.join(carpeta, archivo['name'])
        if os.path.exists(donde) and os.path.getsize(donde) > 10000:
            continue
        subprocess.run(
            ['curl', '-sSL', '-o', donde,
             f"{DONDE}/download/{ITEM}/{archivo['name']}"],
            check=True,
        )
    print(f'audios en {carpeta}')


if __name__ == '__main__':
    main()

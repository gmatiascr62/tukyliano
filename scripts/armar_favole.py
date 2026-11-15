"""Arma el catálogo de fábulas a partir de LibriVox, y baja los audios.

Las fábulas de La Fontaine leídas en italiano son lo mejor que hay para
empezar: duran entre uno y tres minutos, son historias que uno ya conoce —la
cigarra y la hormiga, el cuervo y el zorro— y cada una se cierra sola. Si no
entendiste una, perdiste dos minutos, no un capítulo.

Son de dominio público: las obras hace rato, y los lectores de LibriVox ceden
sus grabaciones a propósito. Está marcado en los metadatos y se verifica acá
abajo antes de bajar nada.

    python3 scripts/armar_favole.py            # solo el catálogo
    python3 scripts/armar_favole.py --bajar    # catálogo y audios

Los audios NO van al repositorio: pesan y el historial de git es para
siempre. Van como adjuntos de un release, que es de donde la app los baja.
"""

import argparse
import json
import os
import re
import subprocess
import sys

DONDE = 'https://archive.org'

# De dónde los baja la app. No es archive.org a propósito: los adjuntos de un
# release de GitHub salen por su CDN, no viven en el historial de git y no
# dependen de que archive.org esté en pie, que desde acá no siempre lo está.
# La etiqueta es fija y aparte de la del APK, así que publicar una versión
# nueva de la app no toca los audios.
BASE = 'https://github.com/gmatiascr62/tukyliano/releases/download/favole-1'

# Por ahora el libro 1. Hay doce; se agregan acá cuando haga falta.
LIBROS = [
    ('favole_di_la_fontaine_01_librivox', 1),
]

# La licencia que tiene que declarar el item. Si dice otra cosa, no se baja:
# el día que alguien suba algo con derechos, esto lo frena.
LIBRES = ('publicdomain', 'creativecommons.org/publicdomain')


def limpiar(texto):
    """Arregla los títulos, que vienen con la codificación rota.

    archive.org devuelve "Il Topo di cittÃÂÃÂ..." en vez de "città": es
    UTF-8 leído como latin-1, varias veces encima. Se deshace el enredo
    tantas veces como haga falta, hasta que deje de cambiar.
    """
    for _ in range(8):
        try:
            otro = texto.encode('latin-1').decode('utf-8')
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
        if otro == texto:
            break
        texto = otro
    return texto.strip()


def sinNumero(titulo):
    """De "01 - La Cicala e la Formica" saca "La Cicala e la Formica"."""
    return re.sub(r'^\d+\s*-\s*', '', titulo).strip()


def enSegundos(largo):
    """El largo viene como "01:27" o como "87.18" según el archivo."""
    if ':' in largo:
        partes = [float(p) for p in largo.split(':')]
        total = 0.0
        for p in partes:
            total = total * 60 + p
        return int(total)
    return int(float(largo))


def traer(que):
    salida = subprocess.run(
        ['curl', '-sS', '-m', '120', f'{DONDE}/metadata/{que}'],
        capture_output=True, check=True,
    )
    return json.loads(salida.stdout.decode('utf-8'))


def unLibro(identificador, numero):
    datos = traer(identificador)
    meta = datos['metadata']

    licencia = (meta.get('licenseurl') or '').lower()
    if not any(libre in licencia for libre in LIBRES):
        raise SystemExit(
            f'{identificador} no declara dominio público, dice "{licencia}". '
            'No se baja.'
        )

    fabulas = []
    for archivo in datos['files']:
        if archivo.get('format') != '64Kbps MP3':
            continue
        titulo = limpiar(str(archivo.get('title', '')))
        # La pista 00 es la presentación de LibriVox, no una fábula.
        if titulo.startswith('00'):
            continue
        fabulas.append({
            'id': archivo['name'].replace('_64kb.mp3', ''),
            'titulo': sinNumero(titulo),
            'libro': numero,
            'archivo': archivo['name'],
            'segundos': enSegundos(str(archivo.get('length', '0'))),
            'bytes': int(archivo.get('size', 0)),
            'desde': f"{DONDE}/download/{identificador}/{archivo['name']}",
        })

    fabulas.sort(key=lambda f: f['id'])
    return meta, fabulas


def main():
    discusion = argparse.ArgumentParser()
    discusion.add_argument('--bajar', action='store_true',
                           help='además baja los mp3 a /tmp/favole')
    opciones = discusion.parse_args()

    todas = []
    creditos = []
    for identificador, numero in LIBROS:
        meta, fabulas = unLibro(identificador, numero)
        creditos.append(limpiar(str(meta.get('title', ''))))
        todas.extend(fabulas)
        print(f'libro {numero}: {len(fabulas)} fábulas', file=sys.stderr)

    catalogo = {
        'version': 1,
        'de': 'LibriVox',
        'licencia': 'Dominio público',
        'credito': 'Grabadas por voluntarios de LibriVox. Las obras y las '
                   'grabaciones son de dominio público.',
        'fuente': 'https://librivox.org',
        'base': BASE,
        'favole': todas,
    }

    destino = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'flutter_app', 'assets', 'favole.json',
    )
    with open(destino, 'w', encoding='utf-8') as f:
        json.dump(catalogo, f, ensure_ascii=False, indent=2)
        f.write('\n')

    pesan = sum(f['bytes'] for f in todas) / 1048576
    duran = sum(f['segundos'] for f in todas) / 60
    print(f'{len(todas)} fábulas · {duran:.0f} min · {pesan:.1f} MB')
    print(f'catálogo en {destino}')

    if not opciones.bajar:
        return

    carpeta = '/tmp/favole'
    os.makedirs(carpeta, exist_ok=True)
    for fabula in todas:
        adonde = os.path.join(carpeta, fabula['archivo'])
        if os.path.exists(adonde):
            continue
        print(f"bajando {fabula['titulo']}", file=sys.stderr)
        subprocess.run(
            ['curl', '-sS', '-L', '-m', '300', '-o', adonde, fabula['desde']],
            check=True,
        )
    print(f'audios en {carpeta}')


main()

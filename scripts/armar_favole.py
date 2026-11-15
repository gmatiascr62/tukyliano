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
import time
import unicodedata

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

# De dónde sale el texto. Es la misma traducción que leen en el audio: la de
# Emilio de Marchi, que murió en 1901, así que hace rato es de dominio
# público. Lo dice la propia página de LibriVox del libro.
WIKI = 'https://it.wikisource.org/w/api.php'
PAGINAS = {1: 'Favole (La Fontaine)/Libro primo/'}

ROMANOS = {
    'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7,
    'VIII': 8, 'IX': 9, 'X': 10, 'XI': 11, 'XII': 12, 'XIII': 13,
    'XIV': 14, 'XV': 15, 'XVI': 16, 'XVII': 17, 'XVIII': 18, 'XIX': 19,
    'XX': 20, 'XXI': 21, 'XXII': 22, 'XXIII': 23, 'XXIV': 24,
}


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


# Wikimedia pide que quien le hable se identifique, y al que no lo hace lo
# estrangula sin decir por qué: contesta vacío cada tantas consultas. Es un
# nombre genérico a propósito; no lleva datos de nadie.
QUIEN_SOY = 'Tukyliano/1.0 (app de estudio de italiano)'


def preguntarleAWikisource(parametros, intentos=3):
    orden = ['curl', '-sS', '-m', '120', '-A', QUIEN_SOY, '-G', WIKI]
    for clave, valor in parametros.items():
        orden += ['--data-urlencode', f'{clave}={valor}']

    for intento in range(intentos):
        salida = subprocess.run(orden, capture_output=True)
        crudo = salida.stdout.decode('utf-8', 'replace')
        try:
            return json.loads(crudo)
        except json.JSONDecodeError:
            if intento == intentos - 1:
                raise SystemExit(
                    'Wikisource no contestó JSON.\n'
                    f'  curl dijo: {salida.stderr.decode()[:200]}\n'
                    f'  contestó : {crudo[:200]!r}'
                )
            time.sleep(2 * (intento + 1))


def laListaDeTextos(prefijo):
    """Las páginas del libro, en el orden que dice su número romano."""
    datos = preguntarleAWikisource({
        'action': 'query', 'format': 'json', 'formatversion': '2',
        'list': 'allpages', 'apprefix': prefijo, 'aplimit': '100',
    })
    paginas = []
    for pagina in datos['query']['allpages']:
        nombre = pagina['title'][len(prefijo):]
        romano = nombre.split(' - ')[0].strip()
        if romano not in ROMANOS:
            continue
        paginas.append((ROMANOS[romano], pagina['title'], nombre))
    paginas.sort()
    return paginas


def soloElTexto(wiki):
    """Del wikitexto saca los renglones del poema y nada más.

    Lo que hay alrededor —plantillas, la imagen del grabado, los enlaces a la
    fábula anterior y la siguiente— no es la fábula.
    """
    adentro = re.search(r'<poem>(.*?)</poem>', wiki, re.S)
    crudo = adentro.group(1) if adentro else wiki

    # Las plantillas pueden estar anidadas, así que se sacan de adentro hacia
    # afuera hasta que no quede ninguna.
    antes = None
    while antes != crudo:
        antes = crudo
        crudo = re.sub(r'\{\{[^{}]*\}\}', '', crudo)

    crudo = re.sub(r'\[\[(?:Immagine|File|Image):[^\]]*\]\]', '', crudo)
    # [[algo|lo que se lee]] y [[lo que se lee]].
    crudo = re.sub(r'\[\[[^\]|]*\|([^\]]*)\]\]', r'\1', crudo)
    crudo = re.sub(r'\[\[([^\]]*)\]\]', r'\1', crudo)
    crudo = re.sub(r'<[^>]+>', '', crudo)
    crudo = crudo.replace("\'\'\'", '').replace("\'\'", '')
    crudo = crudo.replace('\u00a0', ' ')

    renglones = [r.strip() for r in crudo.split('\n')]
    return [r for r in renglones if r]


def losTiemposMarcadosAMano(fabula):
    """Los tiempos de cada renglón, si alguien los marcó.

    Viven en scripts/tiempos/ y no en el catálogo porque el catálogo se
    rearma de cero cada vez que se corre esto: si estuvieran ahí, volver a
    generar el archivo borraría horas de trabajo a mano.

    Se verifica que los renglones sean los mismos y en el mismo orden. Si el
    texto de Wikisource cambió, los tiempos ya no corresponden y es mejor
    quedarse sin ellos que iluminar el renglón equivocado.
    """
    donde = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 'tiempos',
        f"{fabula['id']}.json",
    )
    if not os.path.exists(donde):
        return None

    with open(donde, encoding='utf-8') as fh:
        marcados = json.load(fh)['renglones']

    if len(marcados) != len(fabula['renglones']):
        print(f"los tiempos de {fabula['titulo']} son de otra versión del "
              f"texto ({len(marcados)} renglones contra "
              f"{len(fabula['renglones'])}): se ignoran", file=sys.stderr)
        return None

    for marcado, renglon in zip(marcados, fabula['renglones']):
        if comparable(marcado['texto']) != comparable(renglon):
            print(f"los tiempos de {fabula['titulo']} no coinciden con el "
                  'texto: se ignoran', file=sys.stderr)
            return None

    return marcados


def comparable(titulo):
    """Deja el título comparable: sin tildes, sin signos y en minúscula."""
    sinTildes = unicodedata.normalize('NFKD', titulo)
    sinTildes = ''.join(c for c in sinTildes if not unicodedata.combining(c))
    return re.sub(r'[^a-z0-9]', '', sinTildes.lower())


def losTextosDeLaVezPasada():
    """Los textos que ya están en el catálogo, por id de fábula.

    Wikisource contesta vacío cada tantas consultas, y el texto de una fábula
    del siglo XIX no cambia. Volver a pedírselo para agregar unos tiempos
    marcados a mano sería dejar que un servidor ajeno decida si el script
    corre o no.
    """
    donde = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'flutter_app', 'assets', 'favole.json',
    )
    if not os.path.exists(donde):
        return {}
    try:
        with open(donde, encoding='utf-8') as fh:
            viejo = json.load(fh)
    except (json.JSONDecodeError, OSError):
        return {}

    guardados = {}
    for fabula in viejo.get('favole', []):
        renglones = []
        for renglon in fabula.get('renglones', []):
            # Sirven las dos formas: las de antes eran texto pelado y las de
            # ahora son objetos con el texto adentro.
            renglones.append(
                renglon['t'] if isinstance(renglon, dict) else renglon
            )
        if renglones:
            guardados[fabula['id']] = renglones
    return guardados


def losTextos(numeroDeLibro, fabulas):
    """El texto de cada fábula, emparejado con su audio.

    El emparejado se verifica, no se supone: las dos listas vienen de lugares
    distintos —el audio de LibriVox, el texto de Wikisource— y si alguna vez
    dejan de coincidir, mostrar el texto equivocado debajo del audio sería
    peor que no mostrar ninguno.
    """
    guardados = losTextosDeLaVezPasada()

    try:
        paginas = laListaDeTextos(PAGINAS[numeroDeLibro])
    except SystemExit:
        if all(f['id'] in guardados for f in fabulas):
            print('Wikisource no contesta: se usan los textos que ya están.',
                  file=sys.stderr)
            for fabula in fabulas:
                fabula['renglones'] = guardados[fabula['id']]
            return
        raise

    if len(paginas) != len(fabulas):
        raise SystemExit(
            f'hay {len(fabulas)} audios y {len(paginas)} textos: no emparejan'
        )

    for (_, titulo, nombre), fabula in zip(paginas, fabulas):
        suTitulo = nombre.split(' - ', 1)[-1]
        if comparable(suTitulo) != comparable(fabula['titulo']):
            suyo = fabula['titulo']
            raise SystemExit(
                f'el audio dice "{suyo}" y el texto "{suTitulo}": '
                'no son la misma fábula'
            )

    datos = preguntarleAWikisource({
        'action': 'query', 'format': 'json', 'formatversion': '2',
        'prop': 'revisions', 'rvprop': 'content', 'rvslots': 'main',
        'titles': '|'.join(p[1] for p in paginas),
    })
    porTitulo = {
        p['title']: p['revisions'][0]['slots']['main']['content']
        for p in datos['query']['pages'] if 'revisions' in p
    }

    for (_, titulo, _), fabula in zip(paginas, fabulas):
        wiki = porTitulo.get(titulo)
        fabula['renglones'] = soloElTexto(wiki) if wiki else []
        if not fabula['renglones']:
            fabula['renglones'] = guardados.get(fabula['id'], [])
        if not fabula['renglones']:
            print(f"sin texto: {fabula['titulo']}", file=sys.stderr)


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
        losTextos(numero, fabulas)

        for fabula in fabulas:
            marcados = losTiemposMarcadosAMano(fabula)
            if marcados is None:
                # Sin tiempos, el renglón es solo texto.
                fabula['renglones'] = [
                    {'t': r} for r in fabula['renglones']
                ]
                continue
            fabula['renglones'] = [
                {'t': m['texto'], 'desde': m['desde'], 'hasta': m['hasta']}
                for m in marcados
            ]
            print(f"{fabula['titulo']}: con tiempos", file=sys.stderr)
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
        'textoDe': 'it.wikisource.org · traducción de Emilio de Marchi',
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

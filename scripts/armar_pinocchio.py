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


# El número de página del libro escaneado, con su enlace para editarlo.
# Wikisource lo mete en el medio del texto, y sacar las marcas sin sacar
# esto deja "[p. 9 modifica]" partiendo una frase al medio: "gli era
# entrato addosso una gran [p. 9 modifica]paura". Doscientos cuarenta
# renglones lo tenían.
#
# Hay que sacarlo con contenido y todo, no solo las marcas, porque el
# número y la palabra "modifica" son texto adentro de esos elementos.
UN_NUMERO_DE_PAGINA = re.compile(
    r'<span[^>]*class="[^"]*numeropagina[^"]*".*?</span></span></span>',
    re.S)


def sinLosNumerosDePagina(crudo):
    return UN_NUMERO_DE_PAGINA.sub('', crudo)


# Lo que viene adelante del capítulo y no es el capítulo: los metadatos
# del libro escaneado y la hoja de estilos que Wikisource mete adentro del
# primer párrafo.
NO_ES_TEXTO = ('<dc:', '.mw-parser-output', 'mw-parser-output')


def losTitulos():
    """El resumen de cada capítulo, sacado del índice del libro.

    El índice lista los treinta y seis con su resumen —"La storia di
    Pinocchio col Grillo-parlante, dove si vede come i ragazzi cattivi
    hanno a noja di sentirsi correggere"— y eso es lo que distingue un
    capítulo de otro en una lista de treinta y seis.

    Se saca de acá y no de la página del capítulo por dos razones. Una:
    es un pedido en lugar de treinta y seis. La otra, la que importa: en
    la página del capítulo el resumen a veces no está. El capítulo 4 pasa
    del número romano al texto, y de ahí salían títulos que eran el
    principio del cuento en vez de de qué se trata.
    """
    datos, _ = guardadoEnDisco(0, lambda: pedirleAWikisource({
        'action': 'parse', 'format': 'json', 'formatversion': '2',
        'prop': 'text', 'page': 'Le avventure di Pinocchio',
    }))
    crudo = datos['parse']['text']

    # En el índice, el resumen de cada capítulo viene en un <dd><i> justo
    # después de su enlace. Se recorren los dos en orden de aparición y se
    # emparejan: al capítulo N le toca el primer resumen que lo sigue.
    titulos, ultimo = {}, None
    busca = re.compile(
        r'href="/wiki/Le_avventure_di_Pinocchio/Capitolo_(\d+)"'
        r'|<dd><i>(.*?)</i></dd>', re.S)
    for hallado in busca.finditer(crudo):
        if hallado.group(1):
            ultimo = int(hallado.group(1))
        elif ultimo is not None and ultimo not in titulos:
            texto = re.sub(r'<[^>]+>', '', html.unescape(hallado.group(2)))
            titulos[ultimo] = re.sub(r'\s+', ' ', texto).strip()

    if len(titulos) != CUANTOS_CAPITULOS:
        raise SystemExit(
            f'el índice trae {len(titulos)} resúmenes y los capítulos son '
            f'{CUANTOS_CAPITULOS}'
        )
    return titulos


# El número romano que encabeza cada capítulo. No es el título: el título
# es el resumen que viene después ("Maestro Ciliegia regala il pezzo di
# legno al suo amico Geppetto..."), que es lo que distingue un capítulo de
# otro en una lista de treinta y seis.
#
# En el capítulo 1 esto no hacía falta, porque "I." mide dos letras y se
# caía solo por el filtro de largo. Del 2 en adelante sí, y por eso los
# títulos salían "II.", "III.", "IV.".
SOLO_UN_NUMERO = re.compile(r'^[IVXLC]+\.?$')


def guardadoEnDisco(numero, traerlo):
    """Lo que Wikisource contestó, cacheado.

    Wikimedia corta a quien le pide seguido y bajar los treinta y seis
    capítulos lleva un cuarto de hora. Sin esto, cada vez que hay que
    corregir algo del armado —que es lo que pasó con los títulos— se
    vuelve a esperar ese cuarto de hora y se le vuelve a pedir a un
    servidor ajeno lo mismo que ya contestó.
    """
    carpeta = os.path.join(ACA, '..', '.cache', 'wikisource')
    os.makedirs(carpeta, exist_ok=True)
    donde = os.path.join(carpeta, f'pinocchio_{numero:02d}.json')
    if os.path.exists(donde):
        with open(donde, encoding='utf-8') as fh:
            return json.load(fh), True
    datos = traerlo()
    with open(donde, 'w', encoding='utf-8') as fh:
        json.dump(datos, fh)
    return datos, False


def elTextoDe(numero):
    """Los párrafos del capítulo, ya sin marcas ni basura.

    Devuelve (párrafos, si estaba cacheado).
    """
    datos, estaba = guardadoEnDisco(numero, lambda: pedirleAWikisource({
        'action': 'parse', 'format': 'json', 'formatversion': '2',
        'prop': 'text', 'page': PAGINA.format(numero),
    }))
    if 'error' in datos:
        raise SystemExit(f"capítulo {numero}: {datos['error'].get('info')}")

    crudo = sinLosNumerosDePagina(datos['parse']['text'])
    parrafos = []
    for pedazo in re.findall(r'<p[^>]*>(.*?)</p>', crudo, re.S):
        texto = re.sub(r'<[^>]+>', '', pedazo)
        texto = html.unescape(texto).strip()
        texto = re.sub(r'\s+', ' ', texto)
        if len(texto) < 3 or any(x in texto for x in NO_ES_TEXTO):
            continue
        if SOLO_UN_NUMERO.match(texto):
            continue
        parrafos.append(texto)
    return parrafos, estaba


# Dónde termina una oración: punto, signo o puntos suspensivos, seguidos
# de espacio y mayúscula o raya de diálogo.
FIN_DE_ORACION = re.compile(r'(?<=[.!?…])\s+(?=[«"—\-A-ZÀ-ÜÈÉÌÒÙ])')

# Una oración más corta que esto casi siempre es un pedazo que quedó
# suelto —"— No." — y sola en un renglón se ve rara. Se pega a la
# anterior.
MINIMO = 12


# Hasta acá llega un renglón. Medido sobre el libro entero, son unos
# quince segundos de audio, que es lo que alguien aguanta siguiendo un
# renglón iluminado sin perderse.
#
# Hace falta porque Collodi escribe frases larguísimas unidas por comas:
# la más larga del libro —Pinocchio contándole todo a Geppetto de un
# tirón— son 2308 caracteres, dos minutos y medio de audio en un solo
# renglón. Iluminar eso no dice dónde va: dice que estás en el libro.
HASTA_ACA = 220

# Dónde conviene cortar una frase demasiado larga, de mejor a peor. El
# punto y coma y los dos puntos son pausas de verdad; la coma es lo que
# queda cuando no hay otra cosa.
DONDE_CORTAR = ('; ', ': ', ', ')


def cortarLosLargos(renglones):
    """Parte los renglones que no entran, por la pausa más cercana."""
    salida = []
    for renglon in renglones:
        while len(renglon) > HASTA_ACA:
            corte = -1
            for donde in DONDE_CORTAR:
                corte = renglon.rfind(donde, 0, HASTA_ACA)
                if corte > HASTA_ACA // 3:
                    corte += len(donde) - 1
                    break
                corte = -1
            if corte < 0:
                # Ni una pausa: se corta en el último espacio. Pasa con
                # las enumeraciones sin puntuación, y es preferible a un
                # renglón que dura un minuto.
                corte = renglon.rfind(' ', 0, HASTA_ACA)
                if corte < HASTA_ACA // 3:
                    break
            salida.append(renglon[:corte + 1].strip())
            renglon = renglon[corte + 1:].strip()
        if renglon:
            salida.append(renglon)
    return salida


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
    return cortarLosLargos(renglones)


def esElResumen(parrafo, titulo):
    """Si ese párrafo es el resumen del capítulo y no el cuento.

    Se compara con el título que vino del índice en vez de confiar en que
    sea el primero: en el capítulo 4 el primer párrafo YA es el cuento, y
    sacarlo le habría comido el arranque.
    """
    def comparable(texto):
        return re.sub(r'[^a-z0-9]', '', texto.lower())[:60]

    return comparable(parrafo) == comparable(titulo)


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
    titulos = losTitulos()
    print(f'{len(archivos)} capítulos en LibriVox, {len(titulos)} títulos '
          'en el índice', file=sys.stderr)

    capitulos = []
    for numero, archivo in enumerate(archivos, 1):
        parrafos, estaba = elTextoDe(numero)
        if not parrafos:
            raise SystemExit(f'el capítulo {numero} vino sin texto')

        # El resumen que trae la página del capítulo, cuando está, no es
        # parte del cuento: no se lee en el audio. Se saca, o el renglón
        # iluminado arrancaría corrido desde el primero.
        if parrafos and esElResumen(parrafos[0], titulos[numero]):
            parrafos = parrafos[1:]
        renglones = enOraciones(parrafos)

        capitulos.append({
            'id': f'pinocchio_{numero:02d}',
            'numero': numero,
            'titulo': f'{numero}. {favole.limpiar(titulos[numero])}',
            'archivo': archivo['name'],
            'segundos': favole.enSegundos(archivo['length']),
            'bytes': int(archivo['size']),
            'renglones': renglones,
        })
        print(f'  {numero:2d}/{len(archivos)}  {len(renglones):3d} renglones  '
              f"{capitulos[-1]['titulo'][:52]}", file=sys.stderr)
        if not estaba:
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
            # Quién firma lo que suena, para la pantalla bloqueada.
            'deQuien': 'Pinocchio di Collodi',
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

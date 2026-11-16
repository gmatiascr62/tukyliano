#!/usr/bin/env python3
"""Traduce con Gemini las palabras que el diccionario no sabe.

    GEMINI_API_KEY=... python3 -I traducir_lo_que_falta.py <carpeta assets>

Busca, en todo el texto italiano que muestra la app, las palabras que no
se encuentran ni en el diccionario ni en la tabla de formas, y le pide a
Gemini que las traduzca. El resultado queda en scripts/traducciones.json,
que armar_diccionario.py mete en el diccionario.

**Por qué hace falta esto y no otro diccionario.** De las palabras que
faltan, Wiktionary conoce casi todas: existen y están bien escritas. Lo
que no hay en ningún lado libre es la traducción al castellano. FreeDict
tiene 14.000 palabras, el Wiktionary español 6.500, y ninguno trae
"lumicino".

**Se traduce una sola vez, acá.** Lo que queda escrito es texto en el
repositorio, que se puede leer, corregir a mano y versionar. En el
celular no se gasta nada ni hace falta internet: el diccionario sigue
viajando adentro del APK.

**Y se verifica.** Una IA traduciendo palabras sueltas inventa: devuelve
palabras que no se pidieron, contesta en italiano, o traduce "piglia"
como "piglia". Nada entra sin pasar los controles de abajo, y lo que no
pasa queda anotado para mirarlo a mano.
"""
import json
import os
import re
import subprocess
import sys
import time
import unicodedata

ACA = os.path.dirname(os.path.abspath(__file__))
DONDE_VA = os.path.join(ACA, 'traducciones.json')

# gemini-3.6-flash contesta corto. Los "pro" devuelven la traducción
# envuelta en una explicación —"la palabra más cercana, que evoca la idea
# de..."— y para una lista de palabras eso es ruido que hay que limpiar.
MODELO = os.environ.get('GEMINI_MODELO', 'gemini-3.6-flash')
URL = ('https://generativelanguage.googleapis.com/v1beta/models/'
       f'{MODELO}:generateContent')

# De a cuántas se le pide. Con muchas más empieza a saltearse algunas, y
# con muchas menos son demasiados pedidos.
POR_TANDA = 30

# Los archivos de los que NO se saca texto: el diccionario y la tabla de
# formas son la respuesta, no la pregunta, y radios.json son nombres de
# emisoras.
NO_MIRAR = {'diccionario.json', 'formas.json', 'radios.json'}

# Las claves que tienen italiano. El resto del JSON es castellano,
# configuración o metadatos, y meterlo acá sería pedirle a Gemini que
# traduzca del italiano palabras que son castellano.
CLAVES_CON_ITALIANO = {
    'it', 'italiano', 't', 'texto', 'frase', 'titulo', 'oracion',
    'pregunta',
}

PEDIDO = '''Sos un diccionario italiano → español rioplatense.

Te paso palabras italianas sacadas de cuentos, fábulas del siglo XIX y
podcasts. De cada una te doy el renglón donde aparece, para que sepas de
qué se trata.

Devolvé SOLO un objeto JSON, sin explicar nada y sin ```, con esta forma:

{"palabra": {"base": "forma de diccionario", "es": ["traducción"]}}

Reglas:
- Una entrada por cada palabra que te paso, con esa palabra exacta como
  clave. Ni una de más ni una de menos.
- "es": de una a tres traducciones, en español rioplatense, ordenadas de
  la más común a la menos. Cortas: una o dos palabras cada una. Es para
  mostrar al costado mientras alguien lee, no una definición.
- "base": la palabra como la listaría un diccionario (infinitivo,
  singular, masculino). Si la palabra ya es esa, repetila.
- Traducí lo que la palabra quiere decir EN ESE RENGLÓN.
- Si es un nombre propio (una persona, un lugar, un dios), poné
  {"nombre": true} y nada más.
- Si de verdad no sabés qué quiere decir, poné {"es": []}. Es mejor que
  inventar: lo vacío se revisa a mano, lo inventado no se nota.

Palabras:
'''


def sinTilde(palabra):
    suelta = unicodedata.normalize('NFD', palabra.lower())
    suelta = ''.join(c for c in suelta if unicodedata.category(c) != 'Mn')
    suelta = re.sub(r"[^a-z0-9' ]", ' ', suelta)
    return re.sub(r'\s+', ' ', suelta).strip()


def comoLaApp(palabra):
    """La palabra como queda cuando se la toca en la pantalla."""
    limpia = palabra.replace('’', "'").replace('‘', "'").lower()
    limpia = ''.join(c for c in limpia if c.isalpha() or c == "'")
    return sinTilde(limpia)


def comoBusca(palabra):
    """Todo lo que la app prueba antes de darse por vencida.

    Es una copia de _comoPodriaSerEnItaliano del lado de Dart. Si las dos
    se separan, acá se van a pedir traducciones de palabras que la app sí
    encuentra: peso al pedo, no un error.
    """
    yield palabra
    if "'" in palabra:
        for pedazo in palabra.split("'"):
            if len(pedazo) > 1:
                yield pedazo
    if len(palabra) < 3:
        return
    sinUltima, ultima = palabra[:-1], palabra[-1]
    if ultima == 'i':
        if palabra.endswith('hi'):
            yield palabra[:-2] + 'co'
        yield sinUltima + 'o'
        yield sinUltima + 'e'
        yield sinUltima + 'a'
    elif ultima == 'e':
        if palabra.endswith('he'):
            yield palabra[:-2] + 'ca'
        yield sinUltima + 'a'
        yield sinUltima + 'o'
    elif ultima == 'a':
        yield sinUltima + 'o'
    if ultima in 'lnrm':
        yield palabra + 'e'
        yield palabra + 'o'
        yield palabra + 'a'


def elItalianoDe(datos, salida):
    """Junta los renglones en italiano de un asset, sea como sea por dentro."""
    if isinstance(datos, dict):
        for clave, valor in datos.items():
            if clave in CLAVES_CON_ITALIANO and isinstance(valor, str):
                salida.append(valor)
            else:
                elItalianoDe(valor, salida)
    elif isinstance(datos, list):
        for valor in datos:
            elItalianoDe(valor, salida)


def loQueFalta(assets):
    """Las palabras que no se encuentran, cada una con dónde aparece."""
    with open(f'{assets}/diccionario.json', encoding='utf-8') as fh:
        diccionario = json.load(fh)['it']
    with open(f'{assets}/formas.json', encoding='utf-8') as fh:
        formas = json.load(fh)['de']

    def seEncuentra(palabra):
        return any(f in diccionario or f in formas for f in comoBusca(palabra))

    dondeAparece, cuantas = {}, {}
    for archivo in sorted(os.listdir(assets)):
        if not archivo.endswith('.json') or archivo in NO_MIRAR:
            continue
        renglones = []
        with open(f'{assets}/{archivo}', encoding='utf-8') as fh:
            elItalianoDe(json.load(fh), renglones)
        for renglon in renglones:
            # Se parte también por barra: hay listas de vocabulario que
            # dicen "freddo/fredda", y sin esto la barra se borra y queda
            # "freddofredda", que no es una palabra de ningún idioma.
            for palabra in re.split(r'[\s/]+', renglon):
                limpia = comoLaApp(palabra)
                if not limpia or seEncuentra(limpia):
                    continue
                cuantas[limpia] = cuantas.get(limpia, 0) + 1
                if limpia not in dondeAparece:
                    dondeAparece[limpia] = renglon.strip()

    # Las que más aparecen primero: si algo sale mal a mitad de camino,
    # lo que quedó hecho es lo que más se usa.
    return sorted(dondeAparece.items(),
                  key=lambda x: (-cuantas[x[0]], x[0])), cuantas


def preguntarle(tanda, intentos=3):
    """Le pasa una tanda a Gemini y devuelve lo que contestó, ya parseado."""
    clave = os.environ.get('GEMINI_API_KEY', 'la-pone-el-proxy')
    lista = '\n'.join(f'- {palabra}   (en: "{donde}")'
                      for palabra, donde in tanda)
    cuerpo = {
        'contents': [{'parts': [{'text': PEDIDO + lista}]}],
        'generationConfig': {'temperature': 0, 'responseMimeType':
                             'application/json'},
    }

    for intento in range(intentos):
        salida = subprocess.run(
            ['curl', '-sS', '-m', '180', '-X', 'POST', URL,
             '-H', f'x-goog-api-key: {clave}',
             '-H', 'content-type: application/json',
             '-d', json.dumps(cuerpo, ensure_ascii=False)],
            capture_output=True, text=True)
        try:
            datos = json.loads(salida.stdout)
            texto = datos['candidates'][0]['content']['parts'][0]['text']
            return json.loads(texto)
        except (ValueError, KeyError, IndexError):
            if intento == intentos - 1:
                print(f'  la tanda falló: {salida.stdout[:200]}',
                      file=sys.stderr)
                return {}
            time.sleep(3 * (intento + 1))
    return {}


# ── los controles ──────────────────────────────────────────────────────
#
# Una IA traduciendo palabras sueltas se equivoca de maneras que se
# pueden ver sin saber italiano. Todas estas salieron de mirar lo que
# devolvió de verdad, no de imaginar qué podría pasar.

SOLO_CASTELLANO = re.compile(r"^[a-záéíóúüñ¡!¿?' ,./-]+$", re.IGNORECASE)

# Palabras inglesas cortas que se cuelan cuando no sabe: contesta en
# inglés porque es donde más datos tiene.
SUENA_A_INGLES = {
    'the', 'and', 'with', 'from', 'that', 'this', 'what', 'when', 'they',
    'little', 'small', 'light', 'wolf', 'dog', 'bread', 'water',
}


def pasaElControl(palabra, respuesta, castellano=frozenset()):
    """(sirve, por qué no) para una traducción que devolvió Gemini.

    `castellano` son las palabras que el diccionario ya conoce de ese
    lado, y sirven para una sola cosa: distinguir al que copió la palabra
    italiana porque no sabía, del que la copió porque se escribe igual.
    "finalmente", "regalo", "cima", "lista" y "conviene" son las mismas
    en los dos idiomas, y rechazarlas por idénticas era tirar las fáciles.
    """
    if not isinstance(respuesta, dict):
        return False, 'no devolvió un objeto'
    if respuesta.get('nombre') is True:
        return False, 'es un nombre propio'

    traducciones = respuesta.get('es')
    if not isinstance(traducciones, list) or not traducciones:
        return False, 'no supo'

    limpias = []
    for cual in traducciones[:3]:
        if not isinstance(cual, str):
            return False, 'devolvió algo que no es texto'
        cual = cual.strip()
        if not cual:
            return False, 'devolvió una traducción vacía'
        if len(cual) > 40 or len(cual.split()) > 4:
            return False, f'devolvió una explicación, no una traducción: {cual!r}'
        if not SOLO_CASTELLANO.match(cual):
            return False, f'no parece castellano: {cual!r}'
        if cual.lower() in SUENA_A_INGLES:
            return False, f'contestó en inglés: {cual!r}'
        # Idéntica hasta el acento y encima desconocida del lado
        # castellano: eso es copiar, no traducir. "simpático" por
        # "simpatico" pasa, porque el acento es justamente la traducción.
        if cual.lower() == palabra and sinTilde(cual) not in castellano:
            return False, 'repitió la palabra italiana'
        limpias.append(cual)

    return True, limpias


def main():
    assets = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        ACA, '..', 'flutter_app', 'assets')

    yaEstan = {}
    if os.path.exists(DONDE_VA):
        with open(DONDE_VA, encoding='utf-8') as fh:
            yaEstan = json.load(fh).get('palabras', {})

    with open(f'{assets}/diccionario.json', encoding='utf-8') as fh:
        castellano = {sinTilde(p) for p in json.load(fh)['es']}

    faltan, cuantas = loQueFalta(assets)
    nuevas = [(p, d) for p, d in faltan if p not in yaEstan]
    print(f'faltan {len(faltan)} palabras, {len(yaEstan)} ya traducidas, '
          f'{len(nuevas)} por pedir')
    if not nuevas:
        return

    rechazadas = {}
    for desde in range(0, len(nuevas), POR_TANDA):
        tanda = nuevas[desde:desde + POR_TANDA]
        contesto = preguntarle(tanda)
        buenas = 0
        for palabra, _ in tanda:
            respuesta = contesto.get(palabra)
            if respuesta is None:
                rechazadas[palabra] = 'no la contestó'
                continue
            sirve, resultado = pasaElControl(palabra, respuesta, castellano)
            if not sirve:
                rechazadas[palabra] = resultado
                continue
            base = respuesta.get('base')
            yaEstan[palabra] = {
                'es': resultado,
                'base': base if isinstance(base, str) and base else palabra,
                'visto': cuantas[palabra],
            }
            buenas += 1
        de_mas = set(contesto) - {p for p, _ in tanda}
        extra = f', {len(de_mas)} de más' if de_mas else ''
        print(f'  {desde + len(tanda):4d}/{len(nuevas)}  '
              f'{buenas}/{len(tanda)} sirven{extra}')

    with open(DONDE_VA, 'w', encoding='utf-8') as fh:
        json.dump({
            'comoSeHizo': f'Traducidas con Gemini ({MODELO}) por '
                          'scripts/traducir_lo_que_falta.py, con el renglón '
                          'donde aparece cada una como contexto. '
                          'Verificadas por el script y revisadas por muestreo.',
            'palabras': dict(sorted(yaEstan.items())),
        }, fh, ensure_ascii=False, indent=1)
        fh.write('\n')

    print(f'\nguardadas {len(yaEstan)} en {DONDE_VA}')
    if rechazadas:
        print(f'{len(rechazadas)} no pasaron el control:')
        porQue = {}
        for palabra, motivo in rechazadas.items():
            porQue.setdefault(motivo, []).append(palabra)
        for motivo, cuales in sorted(porQue.items(), key=lambda x: -len(x[1])):
            print(f'  {len(cuales):4d}  {motivo}: {" ".join(cuales[:8])}')


if __name__ == '__main__':
    main()

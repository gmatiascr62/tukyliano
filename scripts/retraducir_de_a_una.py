#!/usr/bin/env python3
"""Vuelve a traducir, de a UNA palabra, lo que se tradujo de a treinta.

    python3 -I retraducir_de_a_una.py [cuántas]

**Por qué existe esto.** La primera tanda le mandaba a Gemini treinta
palabras juntas, cada una con el renglón donde aparece, para que fuera
rápido. Y salió rápido. Pero una palabra adentro de una lista de treinta
recibe mucha menos atención que una palabra sola, y eso se nota justo
donde más importa: en los modismos.

El caso que lo destapó lo encontró Matías leyendo. "Un Lupo già ridotto
al lumicino" no quiere decir que el lobo esté reducido a una velita:
quiere decir que está en las últimas. Preguntado de a treinta, Gemini
contestó "velita, luz baja". Preguntado de a uno, con el mismo renglón y
hasta con el mismo modelo, contesta "en las últimas".

O sea que no era el modelo: era cómo le preguntábamos. Y como esas 498
palabras viajan adentro del APK, le ganan al servidor —que pregunta de a
una y contesta bien— sin que nadie se entere. El camino rápido daba una
respuesta peor que el lento, en silencio.

Esto usa el mismo modelo y el mismo pedido que el servidor, una palabra
por vez, y guarda las dos respuestas para poder comparar antes de
reemplazar nada.
"""
import json
import os
import subprocess
import sys
import time

ACA = os.path.dirname(os.path.abspath(__file__))
DE_DONDE = os.path.join(ACA, 'traducciones.json')
DONDE_VA = os.path.join(ACA, 'traducciones_de_a_una.json')

# El mismo que usa el servidor. No por casualidad: si acá se usara otro,
# el diccionario del APK y el del servidor dirían cosas distintas de la
# misma palabra.
MODELO = os.environ.get('GEMINI_MODELO', 'gemini-3.1-flash-lite')
URL = ('https://generativelanguage.googleapis.com/v1beta/models/'
       f'{MODELO}:generateContent')

PEDIDO = '''Sos un diccionario italiano → español rioplatense.

Traducí la palabra italiana que te paso. Si te doy el renglón donde
aparece, traducí lo que quiere decir AHÍ.

Devolvé SOLO un objeto JSON, sin explicar nada y sin ```:

{"base": "forma de diccionario", "es": ["traducción", "otra"]}

- "es": de una a tres traducciones, cortas, de una o dos palabras cada
  una. Es para mostrar al costado mientras alguien lee, no una
  definición.
- "base": la palabra como la listaría un diccionario (infinitivo,
  singular, masculino). Si ya es esa, repetila.
- Si es un nombre propio, devolvé {"es": []}.
- Si no sabés qué quiere decir, devolvé {"es": []}. Es mejor que
  inventar.'''


def preguntarle(palabra, donde, intentos=3):
    clave = os.environ.get('GEMINI_API_KEY', 'la-pone-el-proxy')
    texto = f'{PEDIDO}\n\npalabra: {palabra}\nrenglón: {donde}'
    cuerpo = {
        'contents': [{'parts': [{'text': texto}]}],
        'generationConfig': {'temperature': 0,
                             'responseMimeType': 'application/json'},
    }
    for intento in range(intentos):
        salida = subprocess.run(
            ['curl', '-sS', '-m', '120', '-X', 'POST', URL,
             '-H', f'x-goog-api-key: {clave}',
             '-H', 'content-type: application/json',
             '-d', json.dumps(cuerpo, ensure_ascii=False)],
            capture_output=True, text=True)
        try:
            datos = json.loads(salida.stdout)
            crudo = ''.join(
                p.get('text', '')
                for p in datos['candidates'][0]['content']['parts'])
            return json.loads(crudo)
        except (ValueError, KeyError, IndexError):
            if intento == intentos - 1:
                return None
            time.sleep(2 * (intento + 1))
    return None


def main():
    cuantas = int(sys.argv[1]) if len(sys.argv) > 1 else 0

    with open(DE_DONDE, encoding='utf-8') as fh:
        viejas = json.load(fh)['palabras']

    # Los renglones donde aparece cada una, que es lo que desambigua.
    sys.path.insert(0, ACA)
    import traducir_lo_que_falta as buscar  # noqa: E402
    faltaban, _ = buscar.loQueFalta(
        os.path.join(ACA, '..', 'flutter_app', 'assets'))
    # Las palabras ya están en el diccionario, así que loQueFalta ya no las
    # ve. Los renglones se sacan del texto igual.
    donde = dondeAparecen()

    nuevas = {}
    if os.path.exists(DONDE_VA):
        with open(DONDE_VA, encoding='utf-8') as fh:
            nuevas = json.load(fh)['palabras']

    porHacer = [p for p in sorted(viejas) if p not in nuevas]
    if cuantas:
        porHacer = porHacer[:cuantas]
    print(f'{len(viejas)} traducidas de a treinta, {len(nuevas)} rehechas, '
          f'{len(porHacer)} por hacer')

    for numero, palabra in enumerate(porHacer, 1):
        dicho = preguntarle(palabra, donde.get(palabra, ''))
        if dicho is None:
            print(f'  {palabra}: no contestó')
            continue
        traducciones = [t.strip() for t in (dicho.get('es') or [])
                        if isinstance(t, str) and t.strip()][:3]
        if not traducciones:
            continue
        nuevas[palabra] = {
            'es': traducciones,
            'base': dicho.get('base') or palabra,
            'donde': donde.get(palabra, ''),
        }
        if numero % 25 == 0:
            guardar(nuevas)
            print(f'  {numero}/{len(porHacer)}')

    guardar(nuevas)
    print(f'guardadas {len(nuevas)} en {DONDE_VA}')


def dondeAparecen():
    """El renglón donde aparece cada palabra, en todo el texto de la app."""
    sys.path.insert(0, ACA)
    import traducir_lo_que_falta as buscar
    assets = os.path.join(ACA, '..', 'flutter_app', 'assets')
    import re
    salida = {}
    for archivo in sorted(os.listdir(assets)):
        if not archivo.endswith('.json') or archivo in buscar.NO_MIRAR:
            continue
        renglones = []
        with open(f'{assets}/{archivo}', encoding='utf-8') as fh:
            buscar.elItalianoDe(json.load(fh), renglones)
        for renglon in renglones:
            for palabra in re.split(r'[\s/]+', renglon):
                limpia = buscar.comoLaApp(palabra)
                if limpia and limpia not in salida:
                    salida[limpia] = renglon.strip()
    return salida


def guardar(nuevas):
    with open(DONDE_VA, 'w', encoding='utf-8') as fh:
        json.dump({
            'comoSeHizo': f'Retraducidas de a UNA palabra con {MODELO}, el '
                          'mismo modelo y el mismo pedido que usa el '
                          'servidor. La tanda anterior preguntaba de a '
                          'treinta y perdía los modismos.',
            'palabras': dict(sorted(nuevas.items())),
        }, fh, ensure_ascii=False, indent=1)
        fh.write('\n')


if __name__ == '__main__':
    main()

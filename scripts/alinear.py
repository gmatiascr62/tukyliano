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

El audio se transcribe **de a pedazos cortos**, cortados en los
silencios, y no de una sola pasada. Esto no es una optimización: whisper
decodifica de a ventanas de 30 segundos arrastrando el contexto, y
cuando pierde el hilo apila veinte palabras en dos segundos o se saltea
dos renglones enteros. Medido en Il Lupo e il Cane contra las marcas a
mano: de una pasada hay cuatro renglones corridos hasta 7 segundos; de a
pedazos de 22 segundos el peor queda en 1,2 y el promedio en 0,43.

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

# Cuánto puede durar un pedazo. 22 segundos salió mejor que 12 y que 8,
# medido contra las marcas a mano: 0,43 s de error promedio contra 0,50
# con pedazos de 12.
CUANTO_DURA_UN_PEDAZO = 22.0

# El umbral de silencio va relativo al volumen medio del archivo. Son
# grabaciones de voluntarios distintos y van de -9 a -25 dB de media: un
# umbral fijo encuentra sesenta silencios en una y ninguno en la otra.
DEBAJO_DE_LA_MEDIA = 16.0


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


def enWav(audio, carpeta):
    """El audio como wav de 16 kHz mono, que es lo que come whisper."""
    wav = os.path.join(carpeta, 'audio.wav')
    subprocess.run(
        ['ffmpeg', '-y', '-loglevel', 'error', '-i', audio,
         '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wav],
        check=True,
    )
    return wav


def cuantoDura(wav):
    salida = subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
         '-of', 'csv=p=0', wav], capture_output=True, text=True, check=True)
    return float(salida.stdout.strip())


def volumenMedio(wav):
    salida = subprocess.run(
        ['ffmpeg', '-i', wav, '-af', 'volumedetect', '-f', 'null', '-'],
        capture_output=True, text=True)
    hallado = re.search(r'mean_volume: (-?[\d.]+) dB', salida.stderr)
    return float(hallado.group(1)) if hallado else -20.0


def losSilencios(wav, minimo=0.15):
    """Los silencios del audio, como (desde, hasta) en segundos."""
    piso = volumenMedio(wav) - DEBAJO_DE_LA_MEDIA
    salida = subprocess.run(
        ['ffmpeg', '-i', wav, '-af',
         f'silencedetect=noise={piso:.1f}dB:d={minimo}', '-f', 'null', '-'],
        capture_output=True, text=True)
    silencios, desde = [], None
    for linea in salida.stderr.split('\n'):
        empieza = re.search(r'silence_start: ([\d.]+)', linea)
        termina = re.search(r'silence_end: ([\d.]+)', linea)
        if empieza:
            desde = float(empieza.group(1))
        elif termina and desde is not None:
            silencios.append((desde, float(termina.group(1))))
            desde = None
    return silencios


def dondeCortar(duracion, silencios, maximo=CUANTO_DURA_UN_PEDAZO):
    """Los pedazos, cortando siempre en el medio de un silencio.

    Cortar en el medio de una pausa y no en un número redondo es lo que
    evita partir una palabra al medio: la palabra partida no coincide con
    el texto y el renglón se queda sin tiempo.
    """
    cortes = [0.0]
    for desde, hasta in silencios:
        medio = (desde + hasta) / 2
        if medio - cortes[-1] >= maximo:
            cortes.append(medio)
    cortes.append(duracion)
    return [(cortes[i], cortes[i + 1]) for i in range(len(cortes) - 1)]


def transcribirPedazo(wav, desde, hasta, base):
    subprocess.run(
        [ELPROGRAMA, '-m', ELMODELO, '-f', wav, '-l', IDIOMA, '-t', HILOS,
         # Un segmento por palabra: es lo que da los tiempos finos.
         '-ml', '1', '-sow',
         # Con -ot los tiempos vuelven absolutos, así que los pedazos se
         # pegan sin tener que sumarles nada.
         '-ot', str(int(desde * 1000)),
         '-d', str(int((hasta - desde) * 1000)),
         # Sin contexto de una ventana a la otra. Esto es lo que frena
         # las alucinaciones: con contexto, en el medio del poema se
         # pone a escribir "fine della favola, questa registrazione è di
         # dominio pubblico" y después lo repite entero. En La Gallina e
         # la Perla eso dejaba las coincidencias en 59%; con -mc 0 pasa
         # a 89% y no queda ningún renglón estimado.
         #
         # Nota: con -mc 0 pasarle --prompt no cambia nada, porque la
         # pista también es contexto de texto y la descarta. Medido: dos
         # fábulas, resultados idénticos con pista y sin pista.
         '-mc', '0',
         '-oj', '-of', base, '-np'],
        capture_output=True, check=True,
    )
    with open(base + '.json', encoding='utf-8') as fh:
        datos = json.load(fh)

    palabras = []
    for segmento in datos.get('transcription', []):
        inicio = segmento['offsets']['from'] / 1000
        fin = segmento['offsets']['to'] / 1000
        # Whisper devuelve de más: procesa ventanas de 30 segundos
        # aunque se le pidan 22, así que le pedís hasta el 47,4 y te
        # contesta hasta el 52,6. Eso lo cubre el pedazo que viene, y
        # dejarlo duplica palabras en la lista. Las coincidencias dejan
        # de ir en orden y aparecen renglones que arrancan antes que el
        # anterior.
        if inicio >= hasta:
            continue
        for palabra in enPalabras(segmento.get('text', '')):
            palabras.append((palabra, inicio, fin))
    return palabras


def transcribir(audio, carpeta):
    """Las palabras que whisper oyó, cada una con su segundo.

    Devuelve (lista de (palabra, inicio, fin), cuántos pedazos).
    """
    wav = enWav(audio, carpeta)
    pedazos = dondeCortar(cuantoDura(wav), losSilencios(wav))
    palabras = []
    for numero, (desde, hasta) in enumerate(pedazos):
        palabras += transcribirPedazo(
            wav, desde, hasta, os.path.join(carpeta, f'p{numero}'))
    return palabras, len(pedazos)


# Cuántas palabras seguidas hacen falta para creerle a una coincidencia.
#
# Una sola palabra suelta no dice nada: adelante de cada capítulo va la
# presentación de LibriVox, que dice "Le avventure di Pinocchio di
# Collodi", y con eso al renglón 1 del capítulo 30 le coincidía la palabra
# "Pinocchio" allá en el segundo 0,8. Como el arranque de un renglón es el
# mínimo de sus coincidencias, ese renglón arrancaba en 0,8 y duraba
# cincuenta segundos: quedaba iluminado durante todo el aviso, y la app
# perdía de dónde arranca el cuento para poder ofrecer saltarlo.
#
# Tres seguidas ya no es casualidad. Los renglones de una o dos palabras
# —"— No."— dejan de coincidir y pasan a estimarse entre sus vecinos, que
# para dos palabras da lo mismo.
PALABRAS_SEGUIDAS = 3


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
    bloques = [b for b in comparador.get_matching_blocks()
               if b[2] >= PALABRAS_SEGUIDAS]
    for enElTexto, enWhisper, cuantas in bloques:
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

    sinNingunaPalabra = [i for i, t in enumerate(tiempos) if not t]
    rellenarLosHuecos(resultado, palabras)

    enOrden(resultado)

    coincidieron = sum(n for _, _, n in bloques)
    return resultado, {
        'palabras': len(delTexto),
        'coincidieron': coincidieron,
        'estimados': sinNingunaPalabra,
    }


# A cuántos caracteres por segundo se lee, si no se puede medir. Es la
# mediana de las veintidós fábulas y los capítulos ya alineados; se usa
# solo cuando en el audio no coincidió ni un renglón, que no pasó nunca.
UN_RITMO_CUALQUIERA = 14.0

# Antes de este segundo no empieza el texto en ninguna grabación de
# LibriVox: adelante va la presentación. Medido en lo que hay alineado,
# el arranque más temprano es 14,7 s en las fábulas y 20 en Pinocchio,
# así que diez deja margen y sigue agarrando un renglón 1 pegado al
# comienzo del audio, que es el síntoma de que se comió el aviso.
ANTES_NO_EMPIEZA = 10.0


def alRitmoDeEste(resultado):
    """Caracteres por segundo, medidos en los renglones que coincidieron.

    Se mide en el audio que se está alineando y no se usa un número fijo
    porque cada lector de LibriVox lee a su velocidad, y los capítulos de
    Pinocchio los leen distintas personas.
    """
    ritmos = [
        len(r['texto']) / (r['fin'] - r['inicio'])
        for r in resultado
        if r['inicio'] is not None and r['fin'] - r['inicio'] > 0.5
    ]
    if not ritmos:
        return UN_RITMO_CUALQUIERA
    return sorted(ritmos)[len(ritmos) // 2]


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

        if hasta < cuantos:
            final = resultado[hasta]['inicio']
        else:
            final = palabras[-1][2] if palabras else 0.0

        largos = [max(len(resultado[k]['texto']), 1) for k in range(i, hasta)]
        total = sum(largos)

        if i > 0:
            desde = resultado[i - 1]['fin']
        else:
            # Arrancar en 0 el primer renglón, cuando es estimado, es
            # ponerlo arriba de la presentación de LibriVox: "Chapter 30 of
            # The Adventures of Pinocchio. This is a LibriVox recording..."
            # son unos cuarenta segundos antes de que empiece el cuento.
            #
            # En el capítulo 30 pasaba eso: el renglón 1 arrancaba en 0,8 y
            # duraba cincuenta segundos. Dos consecuencias, las dos
            # visibles: el renglón queda iluminado todo el aviso, y
            # dondeEmpiezaDeVerdad —que es con lo que la app ofrece saltar
            # la presentación— devolvía 0,8 y no había nada que saltar.
            #
            # Así que se estima para atrás, al ritmo de lectura de este
            # mismo audio: el renglón termina donde empieza la primera
            # palabra reconocida y dura lo que tarda en leerse.
            desde = max(0.0, final - total / alRitmoDeEste(resultado))

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
    """Los tiempos de esos renglones en ese audio.

    Devuelve (resultado, cómo salió). Lo segundo es para desconfiar con
    fundamento: con veintidós fábulas no se puede escuchar cada una para
    ver si los tiempos están bien, así que el alineado tiene que avisar
    cuándo le fue mal.
    """
    with tempfile.TemporaryDirectory() as carpeta:
        palabras, pedazos = transcribir(audio, carpeta)
    resultado, comoSalio = alinear(renglones, palabras)
    comoSalio['pedazos'] = pedazos
    comoSalio['duracion'] = palabras[-1][2] if palabras else 0.0
    comoSalio['quejas'] = lasQuejas(resultado, comoSalio)
    return resultado, comoSalio


def enOrden(resultado):
    """Deja los tiempos en orden, que es lo que la app da por cierto.

    Tres cosas que tienen que valer siempre, y antes solo valía la tercera:

    1. Un renglón no arranca antes que el anterior. Las palabras que
       devuelve whisper se pisan un poco en el borde entre dos pedazos, así
       que el siguiente renglón puede coincidir un instante antes de que
       termine el anterior.
    2. Un renglón no termina antes de arrancar. En el capítulo 25 el
       renglón 70 iba de 302,09 a 301,74 —duración negativa— porque se
       estimó entre dos coincidencias que venían pisadas, y el reparto a
       prorrata le dio un tramo de largo negativo. La app lo pinta con
       `donde >= desde && donde < hasta`, que para eso nunca es cierto: era
       un renglón que no se iluminaba nunca.
    3. Un renglón no sigue pintado cuando ya arrancó el siguiente, o en el
       borde se ven dos iluminados a la vez.
    """
    ultimo = 0.0
    for r in resultado:
        r['inicio'] = max(r['inicio'], ultimo)
        r['fin'] = max(r['fin'], r['inicio'])
        ultimo = r['inicio']
    for i in range(len(resultado) - 1):
        resultado[i]['fin'] = min(resultado[i]['fin'],
                                  resultado[i + 1]['inicio'])
    for r in resultado:
        r['inicio'] = round(r['inicio'], 2)
        r['fin'] = round(max(r['fin'], r['inicio']), 2)


def lasQuejas(resultado, comoSalio):
    """Los motivos para no confiar en este alineado, si hay.

    Cada queja es algo que se puede ver sin escuchar el audio. No
    garantizan que esté bien —un renglón puede estar corrido medio
    segundo y no se nota desde acá— pero sí atajan lo que se nota.
    """
    quejas = []

    porciento = 100 * comoSalio['coincidieron'] // max(comoSalio['palabras'], 1)
    if porciento < 70:
        quejas.append(f'solo coincidió el {porciento}% de las palabras')

    estimados = comoSalio['estimados']
    if len(estimados) > len(resultado) // 4:
        quejas.append(f'{len(estimados)} de {len(resultado)} renglones '
                      'quedaron estimados, sin ninguna palabra reconocida')

    seguidos = masLargaSeguidilla(estimados)
    if seguidos >= 4:
        quejas.append(f'{seguidos} renglones estimados uno atrás del otro')

    for i in range(len(resultado) - 1):
        if resultado[i]['inicio'] > resultado[i + 1]['inicio']:
            quejas.append(f'el renglón {i + 2} arranca antes que el anterior')
            break

    # Adelante va la presentación de LibriVox —quién lee, de qué libro—, y
    # en Pinocchio son unos cuarenta segundos. Si el primer renglón arranca
    # antes de eso es que se la comió: queda iluminado todo el aviso, y la
    # app pierde de dónde arranca el cuento para poder saltarlo.
    if resultado and resultado[0]['inicio'] < ANTES_NO_EMPIEZA:
        quejas.append(
            f"el renglón 1 arranca en el segundo "
            f"{resultado[0]['inicio']:.0f}, encima de la presentación")

    # Un renglón de verso dura dos o tres segundos. Quince quiere decir
    # que de ahí en adelante el resaltado se queda clavado.
    for i, r in enumerate(resultado):
        if r['fin'] - r['inicio'] > 15:
            quejas.append(f'el renglón {i + 1} dura '
                          f'{r["fin"] - r["inicio"]:.0f} segundos')
            break

    return quejas


def masLargaSeguidilla(numeros):
    """Cuántos números consecutivos seguidos hay, como máximo."""
    masLarga = seguidos = 0
    anterior = None
    for n in sorted(numeros):
        seguidos = seguidos + 1 if anterior is not None and n == anterior + 1 \
            else 1
        masLarga = max(masLarga, seguidos)
        anterior = n
    return masLarga


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
    resultado, comoSalio = deUnAudio(audio, renglones)

    with open(salida, 'w', encoding='utf-8') as fh:
        json.dump(resultado, fh, ensure_ascii=False, indent=2)

    porciento = (100 * comoSalio['coincidieron']
                 // max(comoSalio['palabras'], 1))
    print(f'Listo: {salida} ({len(resultado)} renglones en '
          f'{comoSalio["pedazos"]} pedazos, {comoSalio["coincidieron"]}/'
          f'{comoSalio["palabras"]} palabras coincidieron = {porciento}%, '
          f'{len(comoSalio["estimados"])} renglones estimados)')
    for queja in comoSalio['quejas']:
        print(f'  ojo: {queja}', file=sys.stderr)


if __name__ == '__main__':
    main()

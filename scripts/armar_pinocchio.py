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
from html.parser import HTMLParser
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
# del libro escaneado. Queda de red por si aparece un adorno nuevo que el
# parser de abajo no conozca.
NO_ES_TEXTO = ('<dc:', '.mw-parser-output', 'mw-parser-output')


# Cómo se saca la prosa del HTML de Wikisource
# ============================================
#
# Esto estaba hecho con tres regex —saca el número de página, saca las
# marcas, agarrá lo que haya entre <p> y </p>— y cada una se comía texto
# de Collodi en silencio. Tres mecanismos distintos, encontrados de a uno:
#
# 1. El <style> que Wikisource mete adentro del párrafo donde arranca una
#    ilustración. Sacar las marcas no saca lo que hay *adentro* del
#    <style>: dejaba el CSS como texto en el medio de la frase, el párrafo
#    caía en el filtro NO_ES_TEXTO —dice "mw-parser-output", no es texto—
#    y se tiraba entero, con las dos mitades de Collodi adentro.
#
# 2. Los párrafos que no vienen en un <p> sino en un <div
#    style="text-indent:2em">. Wikisource los arma así cuando una
#    ilustración flotante parte el párrafo, porque un bloque no puede ir
#    adentro de un <p>. Son veintiún párrafos en dieciocho capítulos, y el
#    extractor que solo miraba <p> no los veía.
#
# 3. La ilustración en el medio del párrafo, que viene como una <table>
#    con la imagen y su leyenda. Cortar en el primer </div> partía el
#    párrafo al medio, y la leyenda —"Il Can-barbone partì come un
#    barbero."— entraba como si fuera texto del cuento. No se lee en el
#    audio: es un renglón que nunca se ilumina.
#
# Nada de esto se ve leyendo el catálogo: el texto que queda es impecable,
# solo que le falta un párrafo. Ningún test lo agarraba porque todos miran
# lo que está y ninguno lo que falta. Aparecieron alineando, como huecos de
# veintidós y veinticinco segundos de audio sin un renglón que iluminar.
#
# Por eso ahora se parsea en serio en vez de sumar un regex por bug: se
# recorre el árbol, se saltan los adornos con hijos y todo, y el texto de
# un párrafo partido por una ilustración se vuelve a pegar —"cento
# pariglie di topini" + "bianchi, e il Can-barbone" es un solo párrafo.

# Dónde empieza el capítulo.
#
# La página de Wikisource arranca con su propia cabecera —título, autor,
# año, de qué escaneo sale, "Informazioni sulla fonte del testo"— y el
# cuento viene después, adentro de un <div class="testi">. Sin esta puerta
# esos trescientos caracteres de cabecera entraban como si fueran los
# primeros renglones del capítulo, y el renglón iluminado arrancaba
# corrido en todos.
ACA_EMPIEZA = 'testi'

# Adornos que se saltan con todo lo que tengan adentro.
#
# La hoja de estilos y el script, porque su contenido no es texto. La
# tabla, porque es la ilustración con su leyenda. El número de página, que
# es el "[p. 9 modifica]" partiendo una frase al medio. Y los spans con
# que Wikisource envuelve una imagen suelta, que traen la leyenda adentro.
#
# Lo que el libro centra NO se salta, y esto costó caro: el epitafio de la
# lápida del capítulo 23 —"qui giace / la bambina dai capelli turchini /
# morta di dolore"— viene en un centertext, y el audio lo lee. Saltar
# centertext entero se lo comía, y con él nueve segundos de audio sin
# renglón. Lo peor es que lo había verificado al agregar esa regla, y
# después agregué la de las leyendas y no volví a mirarlo: apareció solo
# cuando el test de huecos lo agarró.
#
# Así que lo centrado entra, y lo que no es el cuento se filtra después por
# lo que es —número romano, raya de separación, leyenda— y no por estar
# centrado.
# <small> es con lo que el libro marca la leyenda de una ilustración y los
# metadatos de la fuente. Son cincuenta y tres en el libro y ninguno es
# prosa: lo que parecía prosa —el proverbio "Chi ruba il mantello al suo
# prossimo" del capítulo 36— está además como párrafo normal unas líneas
# antes, porque la leyenda cita la frase que ilustra.
NI_MIRAR = ('style', 'script', 'table', 'small')
# Y font-size:smaller, que es con lo que el libro marca lo que no es el
# cuento: la leyenda de cada ilustración y el resumen del capítulo. Son
# noventa y nueve en el libro y ninguno es prosa —los resúmenes salen del
# índice y son el título, y cada leyenda repite una frase que está en el
# texto—, así que se revisaron los noventa y nueve antes de sacarlos.
#
# Hacen falta las dos reglas, esta y centertext: veintiuna leyendas no
# están centradas sino en un cajón flotante al costado, y con centertext
# sola se colaban igual. Entraban como renglones que nadie lee en voz
# alta, y un renglón así no se ilumina nunca.
NI_MIRAR_SI_DICE = ('numeropagina', 'myspan1', 'freedimg', 'linkmodifica',
                    'quality-msg', 'intest', 'font-size:smaller', 'float:')

# Abren párrafo: el <p> de siempre, y el <div> con sangría que Wikisource
# usa cuando una ilustración parte el párrafo en dos.
ABRE_PARRAFO = ('p', 'div', 'dd')

# Las que no llevan cierre. No van a la pila de etiquetas abiertas porque
# quedarían colgadas y correrían la cuenta de dónde abrió cada cosa.
SE_CIERRAN_SOLAS = ('br', 'img', 'link', 'meta', 'hr', 'input', 'source')


class SacarLaProsa(HTMLParser):
    """Los párrafos del capítulo, sin los adornos de Wikisource.

    Un párrafo partido por una ilustración vuelve a quedar entero: lo que
    hay antes y lo que hay después del adorno se pegan, porque en el libro
    es una sola frase.
    """

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parrafos = []
        self._juntando = []
        # Las etiquetas abiertas, en orden. Todo lo demás son posiciones
        # en esta pila: dónde abrió el capítulo y dónde abrió el adorno que
        # se está salteando. Así cerrar una etiqueta es truncar la pila, y
        # un adorno que se cierra no deja nada colgado.
        self._pila = []
        self._capitulo = None
        self._adorno = None

    def _esAdorno(self, etiqueta, atributos):
        if etiqueta in NI_MIRAR:
            return True
        comoVino = ' '.join(
            v.lower() for _, v in atributos if v).replace(' ', '')
        return any(x in comoVino for x in NI_MIRAR_SI_DICE)

    def _esParrafo(self, etiqueta, atributos):
        if etiqueta == 'p':
            return True
        if etiqueta not in ABRE_PARRAFO:
            return False
        # El <div> solo abre párrafo si tiene sangría: los otros son
        # cajas de maquetado y abrir párrafo en cada uno partiría el texto.
        estilo = dict(atributos).get('style') or ''
        return 'text-indent' in estilo.replace(' ', '')

    def handle_starttag(self, etiqueta, atributos):
        # Las que no cierran nunca —<br>, <img>, <link>— no van a la pila:
        # si fueran, quedarían colgadas y la cuenta se correría.
        if etiqueta in SE_CIERRAN_SOLAS:
            return
        self._pila.append(etiqueta)
        if self._capitulo is None:
            clases = (dict(atributos).get('class') or '').split()
            if ACA_EMPIEZA in clases:
                self._capitulo = len(self._pila) - 1
            return
        if self._adorno is not None:
            return
        if self._esAdorno(etiqueta, atributos):
            # No se cierra el párrafo: la ilustración parte la frase al
            # medio y las dos mitades son un solo párrafo del libro.
            self._adorno = len(self._pila) - 1
            return
        if self._esParrafo(etiqueta, atributos):
            self._cerrarParrafo()

    def handle_endtag(self, etiqueta):
        if etiqueta in SE_CIERRAN_SOLAS or etiqueta not in self._pila:
            return
        donde = len(self._pila) - 1 - self._pila[::-1].index(etiqueta)
        del self._pila[donde:]

        if self._adorno is not None and donde <= self._adorno:
            self._adorno = None
            return
        if self._adorno is not None:
            return
        if etiqueta in ABRE_PARRAFO:
            self._cerrarParrafo()
        # Cuando se cierra el <div class="testi"> se terminó el capítulo:
        # lo que venga después son los enlaces al anterior y al siguiente.
        if self._capitulo is not None and donde <= self._capitulo:
            self._cerrarParrafo()
            self._capitulo = None

    def handle_data(self, texto):
        if self._capitulo is not None and self._adorno is None:
            self._juntando.append(texto)

    def _cerrarParrafo(self):
        texto = re.sub(r'\s+', ' ', ''.join(self._juntando)).strip()
        self._juntando = []
        if texto:
            self.parrafos.append(texto)

    def terminar(self):
        self._cerrarParrafo()
        return self.parrafos


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

# La raya con que el libro separa dos escenas adentro de un capítulo, y el
# "F I N E." del final, espaciado letra por letra. No se leen, y espaciado
# así tampoco coincidiría con ninguna palabra del audio.
SOLO_UN_ADORNO = re.compile(r'^(?:[_\-—–\s]+|(?:[A-Z]\s){2,}[A-Z]\s*\.?)$')


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


# El único texto del libro que no sale de Wikisource.
#
# En el capítulo 33 el lector lee en voz alta el cartel que anuncia el
# espectáculo, y son veintiséis segundos. En Wikisource ese cartel no es
# texto: es la foto del afiche escaneado, metida entre las páginas 247 y
# 248 del djvu, así que no hay nada que extraer. Quedaba como el único
# hueco del libro: el audio lee y el renglón iluminado se queda quieto.
#
# Las palabras son las que se oyen en la grabación, no las que yo recuerde
# del libro. Matías transcribió el capítulo con un reconocedor de voz y de
# ahí salen; su archivo ubica el cartel entre el segundo 377,7 y el 403,9,
# que es exactamente el hueco que medía el alineado.
#
# El cartel está en mayúsculas en el libro escaneado —es un afiche—, pero
# acá va en minúscula y sin cortes de línea: lo que se ilumina siguiendo el
# audio es una oración, y whisper no reconoce mayúsculas de todos modos.
EL_CARTEL_DEL_TEATRO = (
    'Grande spettacolo di gala.',
    'Per questa sera avranno luogo i soliti salti ed esercizi '
    'sorprendenti, eseguiti da tutti gli artisti e da tutti i cavalli '
    'd’ambo i sessi della compagnia.',
    'E più sarà presentato per la prima volta il famoso ciuchino '
    'Pinocchio, detto la stella della danza.',
    'Il teatro sarà illuminato a giorno.',
)

# Dónde va: justo después de la frase que lo presenta.
LO_PRESENTA = 'I cartelloni di vario colore'


def conElCartelDelTeatro(numero, parrafos):
    """Le mete al capítulo 33 el cartel que Wikisource no tiene como texto."""
    if numero != 33:
        return parrafos
    donde = [i for i, p in enumerate(parrafos) if LO_PRESENTA in p]
    if len(donde) != 1:
        # Si Wikisource cambia y la frase se mueve o desaparece, esto tiene
        # que avisar en vez de pegar el cartel en cualquier lado o de
        # dejarlo afuera sin que se note.
        raise SystemExit(
            f'capítulo 33: esperaba una sola vez {LO_PRESENTA!r} para saber '
            f'dónde va el cartel del teatro, y lo encontré {len(donde)}')
    corte = donde[0] + 1
    return parrafos[:corte] + list(EL_CARTEL_DEL_TEATRO) + parrafos[corte:]


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

    sacador = SacarLaProsa()
    sacador.feed(datos['parse']['text'])
    parrafos = []
    for texto in sacador.terminar():
        if len(texto) < 3 or any(x in texto for x in NO_ES_TEXTO):
            continue
        if SOLO_UN_NUMERO.match(texto) or SOLO_UN_ADORNO.match(texto):
            continue
        parrafos.append(texto)

    parrafos = conElCartelDelTeatro(numero, parrafos)

    seColo = leyendasQueNoSonTexto(datos['parse']['text']) & set(parrafos)
    if seColo:
        raise SystemExit(
            f'capítulo {numero}: se colaron {len(seColo)} leyendas de '
            f'ilustración como si fueran texto del cuento, y son renglones '
            f'que nunca se van a iluminar porque nadie los lee en voz alta. '
            f'La primera: {sorted(seColo)[0][:90]!r}')
    return parrafos, estaba


# Las leyendas y los resúmenes, sacados a mano del HTML.
#
# Esto no usa el parser a propósito: es el control de que el parser hizo su
# trabajo, y un control que comparte el código de lo que controla no
# controla nada. Si el parser deja pasar una leyenda, esto la encuentra por
# otro camino y el build se cae en vez de publicar renglones muertos.
#
# Hizo falta porque el primer arreglo sacó las leyendas centradas y dio por
# resuelto el problema, y quedaron veintiuna en cajones flotantes. El test
# que escribí entonces miraba una leyenda puntual —justo una de las que sí
# se habían arreglado— y pasaba en verde con las otras veintiuna adentro.
UNA_LEYENDA = re.compile(
    r'<span style="font-size:smaller">(.*?)</span>', re.S)


def sonLeyendas(crudo):
    sueltas = set()
    for hallado in UNA_LEYENDA.finditer(crudo):
        texto = re.sub(r'<[^>]+>', '', hallado.group(1))
        texto = re.sub(r'\s+', ' ', html.unescape(texto)).strip()
        if texto:
            sueltas.add(texto)
    return sueltas


def leyendasQueNoSonTexto(crudo):
    """Las leyendas que, si aparecen como renglón, están de más.

    Hay leyendas que son además una línea del cuento: el capítulo 9 ilustra
    "— Vuoi darmi quattro soldi di quest'Abbecedario nuovo?" y esa misma
    pregunta es un párrafo del diálogo tres líneas después. Esa tiene que
    quedar, y por eso no alcanza con comparar contra la lista de leyendas:
    así, el control pedía borrar diálogo de Collodi.

    Una leyenda es legítima como renglón si existe también como párrafo
    propio del cuento, mirando el HTML con las leyendas tapadas.
    """
    leyendas = sonLeyendas(crudo)
    sinLeyendas = UNA_LEYENDA.sub(' ', crudo)
    tambienSonTexto = set()
    for pedazo in re.findall(r'<p[^>]*>(.*?)</p>', sinLeyendas, re.S):
        plano = re.sub(r'<[^>]+>', '', pedazo)
        plano = re.sub(r'\s+', ' ', html.unescape(plano)).strip()
        if plano in leyendas:
            tambienSonTexto.add(plano)
    return leyendas - tambienSonTexto


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

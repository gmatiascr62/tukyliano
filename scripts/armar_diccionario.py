"""Arma assets/diccionario.json a partir de tres fuentes.

1. FreeDict ita-spa (CC BY-SA 3.0, de Wiktionary vía WikDict). La base.
2. verbos.json, que ya está en la app: tapa el agujero más grande de FreeDict,
   que son las formas conjugadas —tiene "andare" y no tiene "andato"—.
3. Una lista escrita a mano acá abajo: las palabras de función que ningún
   diccionario trae, las básicas que a FreeDict le faltan, y el español
   rioplatense, porque el de Wiktionary es neutro y dice "coche".

Las claves van normalizadas (minúsculas, sin tildes) para poder buscar sin que
importe cómo se escribió. Los valores van como se escriben de verdad.

Se corre:  python3 -I armar_diccionario.py <ita-spa.tei> <carpeta assets>
"""
import json
import os
import sys
import unicodedata
from xml.etree import ElementTree

TEI = '{http://www.tei-c.org/ns/1.0}'

CREDITO = ('Diccionario italiano-español de FreeDict y WikDict, armado a '
           'partir de Wiktionary.')
LICENCIA = 'CC BY-SA 3.0'
FUENTE = 'https://freedict.org/'

# Cuántas traducciones se guardan por palabra. Más que esto no se lee: es una
# ayuda al pasar, no una entrada de diccionario para estudiar.
TOPE = 5

# ─────────────────────────── escrito a mano ───────────────────────────────
#
# Nada de acá sale de FreeDict. Son las que medimos que faltaban.

# Palabras de función: artículos, preposiciones, pronombres. Ningún
# diccionario bilingüe las trae y son las más frecuentes de todas.
FUNCION = {
    'il': ['el'], 'lo': ['el', 'lo'], 'la': ['la'], 'i': ['los'],
    'gli': ['los'], 'le': ['las'], 'un': ['un'], 'uno': ['uno'],
    'una': ['una'], "un'": ['una'],
    'di': ['de'], 'a': ['a'], 'da': ['de', 'desde'], 'in': ['en'],
    'con': ['con'], 'su': ['sobre', 'en'], 'per': ['para', 'por'],
    'tra': ['entre'], 'fra': ['entre'],
    'del': ['del'], 'dello': ['del'], 'della': ['de la'], 'dei': ['de los'],
    'degli': ['de los'], 'delle': ['de las'],
    'al': ['al'], 'allo': ['al'], 'alla': ['a la'], 'ai': ['a los'],
    'agli': ['a los'], 'alle': ['a las'],
    'dal': ['del', 'desde el'], 'dalla': ['de la'], 'dai': ['de los'],
    'dalle': ['de las'],
    'nel': ['en el'], 'nella': ['en la'], 'nei': ['en los'],
    'nelle': ['en las'], 'sul': ['sobre el'], 'sulla': ['sobre la'],
    'e': ['y'], 'ed': ['y'], 'o': ['o'], 'ma': ['pero'], 'se': ['si'],
    'che': ['que'], 'chi': ['quién'], 'come': ['como', 'cómo'],
    'quando': ['cuando'], 'dove': ['dónde'], 'perche': ['porque', 'por qué'],
    'quanto': ['cuánto'], 'quale': ['cuál'], 'cosa': ['qué', 'cosa'],
    'non': ['no'], 'anche': ['también'], 'pure': ['también'],
    'piu': ['más'], 'meno': ['menos'], 'molto': ['mucho'], 'poco': ['poco'],
    'troppo': ['demasiado'], 'abbastanza': ['bastante'],
    'tutto': ['todo'], 'tutti': ['todos'], 'tutta': ['toda'],
    'tutte': ['todas'], 'niente': ['nada'], 'nulla': ['nada'],
    'qualcosa': ['algo'], 'qualcuno': ['alguien'], 'ogni': ['cada'],
    'questo': ['este', 'esto'], 'questa': ['esta'], 'questi': ['estos'],
    'queste': ['estas'], 'quello': ['aquel', 'ese'], 'quella': ['aquella'],
    'quelli': ['aquellos'], 'quelle': ['aquellas'],
    'io': ['yo'], 'tu': ['vos', 'tú'], 'lui': ['él'], 'lei': ['ella'],
    'noi': ['nosotros'], 'voi': ['ustedes'], 'loro': ['ellos', 'ellas'],
    'mi': ['me'], 'ti': ['te'], 'ci': ['nos'], 'vi': ['los', 'les'],
    'si': ['se'], 'ne': ['de eso'],
    'mio': ['mi', 'mío'], 'mia': ['mi', 'mía'], 'miei': ['mis'],
    'mie': ['mis'], 'tuo': ['tu', 'tuyo'], 'tua': ['tu', 'tuya'],
    'suo': ['su', 'suyo'], 'sua': ['su', 'suya'],
    'nostro': ['nuestro'], 'nostra': ['nuestra'], 'vostro': ['de ustedes'],
    'gia': ['ya'], 'ancora': ['todavía', 'otra vez'], 'sempre': ['siempre'],
    'mai': ['nunca'], 'adesso': ['ahora'], 'ora': ['ahora', 'hora'],
    'oggi': ['hoy'], 'domani': ['mañana'], 'ieri': ['ayer'],
    'stasera': ['esta noche'], 'stamattina': ['esta mañana'],
    'dopo': ['después'], 'prima': ['antes', 'primera'], 'poi': ['después'],
    'fuori': ['afuera'], 'dentro': ['adentro'], 'sopra': ['arriba'],
    'sotto': ['abajo'], 'qui': ['acá'], 'qua': ['acá'], 'li': ['ahí'],
    'la_adv': ['allá'], 'vicino': ['cerca'], 'lontano': ['lejos'],
    'bene': ['bien'], 'male': ['mal'], 'meglio': ['mejor'],
    'peggio': ['peor'], 'grazie': ['gracias'], 'prego': ['de nada'],
    'scusa': ['perdón'], 'ciao': ['hola', 'chau'], 'si_': ['sí'],
    'no': ['no'], 'forse': ['tal vez'], 'certo': ['claro'],
    'davvero': ['en serio'], 'allora': ['entonces'], 'quindi': ['así que'],
    'però': ['pero'], 'invece': ['en cambio'], 'ecco': ['acá tenés'],
}

# Básicas que FreeDict no trae, o que trae mal para el Río de la Plata.
# "macchina" lo traduce como "máquina", que es cierto y no es lo que se usa.
BASICAS = {
    'panino': ['sándwich'], 'tramezzino': ['sándwich de miga'],
    'cornetto': ['medialuna'], 'soldi': ['plata', 'dinero'],
    'bambino': ['nene', 'chico'], 'bambina': ['nena', 'chica'],
    'ragazzo': ['chico', 'novio'], 'ragazza': ['chica', 'novia'],
    'bici': ['bici'], 'bicicletta': ['bicicleta'],
    'partita': ['partido'], 'voglia': ['ganas'],
    'macchina': ['auto', 'máquina'], 'automobile': ['auto'],
    'autobus': ['colectivo'], 'metropolitana': ['subte'],
    'treno': ['tren'], 'stazione': ['estación'],
    'biglietto': ['boleto', 'entrada'], 'scontrino': ['ticket'],
    'colazione': ['desayuno'], 'pranzo': ['almuerzo'], 'cena': ['cena'],
    'piscina': ['pileta'], 'spiaggia': ['playa'],
    'frigorifero': ['heladera'], 'marciapiede': ['vereda'],
    'isolato': ['cuadra'], 'negozio': ['negocio'],
    'supermercato': ['supermercado'], 'ospedale': ['hospital'],
    'cellulare': ['celular'], 'computer': ['computadora'],
    'maglietta': ['remera'], 'giacca': ['campera'], 'gonna': ['pollera'],
    'occhiali': ['anteojos'], 'valigia': ['valija'], 'penna': ['birome'],
    'fragola': ['frutilla'], 'pesca': ['durazno', 'pesca'],
    'mais': ['choclo'], 'fagioli': ['porotos'],
    'lavoro': ['trabajo'], 'carta': ['tarjeta', 'papel'],
    'conto': ['cuenta'], 'banco': ['barra', 'banco'],
    'tavolo': ['mesa'], 'bicchiere': ['vaso'], 'tazza': ['taza'],
}


# Infinitivos de todos los días que FreeDict no trae. Sorprende, pero los
# medimos faltando contra el texto de la propia app.
VERBOS = {
    'parlare': ['hablar'], 'studiare': ['estudiar'], 'riposare': ['descansar'],
    'mangiare': ['comer'], 'bere': ['tomar', 'beber'], 'dormire': ['dormir'],
    'leggere': ['leer'], 'scrivere': ['escribir'], 'ascoltare': ['escuchar'],
    'aprire': ['abrir'], 'chiudere': ['cerrar'], 'partire': ['salir', 'partir'],
    'arrivare': ['llegar'], 'uscire': ['salir'], 'entrare': ['entrar'],
    'comprare': ['comprar'], 'pagare': ['pagar'], 'prendere': ['tomar'],
    'mettere': ['poner'], 'dire': ['decir'], 'vedere': ['ver'],
    'sentire': ['sentir', 'oír'], 'aspettare': ['esperar'],
    'chiamare': ['llamar'], 'camminare': ['caminar'], 'correre': ['correr'],
    'vivere': ['vivir'], 'abitare': ['vivir'], 'viaggiare': ['viajar'],
    'cucinare': ['cocinar'], 'giocare': ['jugar'], 'ballare': ['bailar'],
    'cantare': ['cantar'], 'imparare': ['aprender'], 'insegnare': ['enseñar'],
    'capire': ['entender'], 'ricordare': ['recordar'],
    'dimenticare': ['olvidar'], 'cercare': ['buscar'], 'trovare': ['encontrar'],
    'portare': ['llevar'], 'dare': ['dar'], 'tornare': ['volver'],
    'restare': ['quedarse'], 'finire': ['terminar'], 'cominciare': ['empezar'],
    'provare': ['probar'], 'pensare': ['pensar'], 'credere': ['creer'],
    'amare': ['amar'], 'piacere': ['gustar'], 'costare': ['costar'],
    'aiutare': ['ayudar'], 'usare': ['usar'], 'chiedere': ['pedir'],
    'rispondere': ['contestar'], 'guidare': ['manejar'], 'nuotare': ['nadar'],
    'mal': ['mal', 'dolor'], 'poco_': ['poco'], 'po': ['poco'],
    'compiti': ['tarea'], 'stanco': ['cansado'], 'stanchi': ['cansados'],
}


# Última tanda: las que quedaron faltando después de medir contra el texto
# de la app con todas las reglas puestas.
SUELTAS = {
    'mamma': ['mamá'], 'papa': ['papá'], 'sto': ['estoy'], 'stai': ['estás'],
    'sta': ['está'], 'stiamo': ['estamos'], 'stanno': ['están'],
    'senza': ['sin'], 'zaino': ['mochila'], 'chiave': ['llave'],
    'chiavi': ['llaves'], 'ad': ['a'], 'fino': ['hasta'],
    'quel': ['aquel', 'ese'], 'quei': ['aquellos'],
    'tranquillo': ['tranquilo'], 'buon': ['buen'], 'buono': ['bueno'],
    'lungo': ['largo'], 'fu': ['fue'], 'scuola': ['escuela'],
    'difficile': ['difícil'], 'facile': ['fácil'], 'volta': ['vez'],
    'posto': ['lugar'], 'presto': ['pronto', 'temprano'],
    'altro': ['otro'], 'altra': ['otra'], 'ieri sera': ['anoche'],
}

# Las que faltaban para leer las fábulas de La Fontaine.
#
# Salieron de contar: se midió, palabra por palabra, qué no encontraba la
# app en los 3915 renglones de las veintidós, y se escribieron las que
# aparecen dos veces o más. No son palabras raras ni literarias: son
# "tanto", "grande", "subito", "dietro", "contro". El diccionario tiene
# 14.000 entradas y no tenía "grande".
#
# Es lo que pasa con un diccionario sacado de Wiktionary: trae
# "acciaio inossidabile" y no trae "tanto", porque nadie se sienta a
# escribir la entrada de una palabra que todo el mundo sabe.
DELASFAVOLE = {
    'tanto': ['tanto'], 'tanta': ['tanta'], 'grande': ['grande'],
    'gran': ['gran'], 'grosso': ['grueso', 'gordo'],
    'subito': ['enseguida', 'de inmediato'], 'sembra': ['parece'],
    'qualche': ['algún', 'alguno'], 'mezzo': ['medio'],
    'dietro': ['detrás', 'atrás'], 'contro': ['contra'],
    'dunque': ['entonces', 'así que'], 'assai': ['bastante', 'mucho'],
    'proprio': ['propio', 'justamente'], 'ricco': ['rico'],
    'bestia': ['bestia', 'animal'], 'maestro': ['maestro'],
    'favola': ['fábula'], 'solito': ['habitual'],
    'torto': ['culpa', 'agravio'], 'infine': ['al fin', 'por fin'],
    'altrui': ['ajeno', 'de otro'], 'brava': ['buena', 'hábil'],
    'bove': ['buey'], 'boccone': ['bocado'], 'boccon': ['bocado'],
    'lite': ['pelea', 'pleito'], 'numi': ['dioses'],
    'desinare': ['comer', 'almorzar'], 'faccenda': ['asunto'],
    'fessura': ['grieta', 'rendija'], 'giuro': ['juro'],
    'giammai': ['jamás'], 'narra': ['cuenta', 'narra'],
    'mogio': ['cabizbajo'], 'sciocco': ['tonto'],
    'sconosciuti': ['desconocidos'], 'ciarle': ['chismes'],
    'ciascun': ['cada uno'], 'tondo': ['redondo'],
    'trappole': ['trampas'], 'traverso': ['través'],
    'sonante': ['sonante', 'contante'], 'ducatone': ['ducado'],
    'rondinella': ['golondrina'], 'avvenne': ['ocurrió'],
    'affanna': ['agobia', 'afana'], 'piglia': ['agarra', 'toma'],
    'dirgli': ['decirle'], 'or': ['ahora'], 'ah': ['ah'], 'oh': ['oh'],
    'pur': ['aun así', 'también'], 'ver': ['verdad'],
    "pro'": ['provecho'],

    # Las contracciones con "con", que el diccionario no tiene y la regla
    # del apócope resolvía mal: sin esto, "col" caía en "collo" y la app
    # contestaba "cuello" donde dice "con el". Y "colla", que sí estaba,
    # contestaba "pegamento" donde dice "con la".
    'col': ['con el'], 'coi': ['con los'], 'collo_': ['con lo'],
    'colla': ['con la', 'cola', 'pegamento'], 'colle': ['con las'],
    'cogli': ['con los'], 'pel': ['por el'], 'pei': ['por los'],

    # Con apóstrofo, que es como aparecen en el verso.
    "c'e": ['hay'], "ch'e": ['que es'], "d'un": ['de un'],
    "ch'io": ['que yo'], "l'arte": ['el arte'],
}

# Las que la IA no podía juzgar, escritas a mano.
#
# Son las que se escriben igual en italiano y en castellano. Cuando Gemini
# contesta "finalmente" para "finalmente", no hay forma de saber desde
# afuera si tradujo o si copió la palabra porque no sabía, que es
# exactamente lo que hace cuando no sabe. El control las rechaza a todas,
# y después se miran de a una: son veintiséis, y mirarlas es más barato
# que discutir con el control.
#
# Cinco de estas no eran iguales y las habría tirado igual: garbo,
# pastura, sire, regio e ignoto.
LASQUELAIANOPUDO = {
    'finalmente': ['finalmente', 'por fin'], 'regalo': ['regalo'],
    'cima': ['cima', 'cumbre'], 'lista': ['lista'],
    'sorprende': ['sorprende'], 'conviene': ['conviene'],
    'ignoto': ['desconocido', 'ignoto'], 'limoncello': ['limoncello'],
    'siciliano': ['siciliano'], 'taxi': ['taxi'],
    'beneficio': ['beneficio', 'provecho'], 'conquista': ['conquista'],
    'garbo': ['gracia', 'donaire'], 'impedirlo': ['impedirlo'],
    'indigesta': ['indigesta', 'pesada'],
    'infame': ['infame', 'miserable'], 'mostrarlo': ['mostrarlo'],
    'pastura': ['pasto', 'forraje'], 'prepotente': ['prepotente'],
    'pura': ['pura'], 'regala': ['regala'], 'regio': ['real', 'regio'],
    'transilvano': ['transilvano'], 'tremenda': ['tremenda'],
    'usarlo': ['usarlo'], 'sire': ['señor'],
}

SUELTAS_ES = {
    'es': ['è'], 'dificil': ['difficile'], 'vez': ['volta'],
    'anoche': ['ieri sera'], 'mama': ['mamma'], 'papa': ['papà'],
    'lugar': ['posto'], 'pronto': ['presto'], 'sin': ['senza'],
    'otra': ['altra'], 'otro': ['altro'], 'esa': ['quella'],
    'eso': ['quello'], 'buen': ['buon'], 'llaves': ['chiavi'],
    'llave': ['chiave'], 'mochila': ['zaino'], 'escuela': ['scuola'],
    'facil': ['facile'], 'estoy': ['sto'], 'temprano': ['presto'],
}

# Español → italiano escrito a mano: lo rioplatense, que el reverso
# automático no tiene porque Wiktionary habla en neutro.
RIOPLATENSE = {
    'auto': ['macchina', 'automobile'], 'tarjeta': ['carta'],
    'pileta': ['piscina'], 'plata': ['soldi'], 'celular': ['cellulare'],
    'computadora': ['computer'], 'boleto': ['biglietto'],
    'medialuna': ['cornetto'], 'sandwich': ['panino'],
    'nene': ['bambino'], 'nena': ['bambina'],
    'pibe': ['ragazzo'], 'laburo': ['lavoro'],
    'colectivo': ['autobus'], 'subte': ['metropolitana'],
    'remera': ['maglietta'], 'campera': ['giacca'],
    'pollera': ['gonna'], 'anteojos': ['occhiali'], 'valija': ['valigia'],
    'birome': ['penna'], 'frutilla': ['fragola'], 'durazno': ['pesca'],
    'choclo': ['mais'], 'porotos': ['fagioli'], 'heladera': ['frigorifero'],
    'vereda': ['marciapiede'], 'cuadra': ['isolato'],
    'desayuno': ['colazione'], 'almuerzo': ['pranzo'],
    'ticket': ['scontrino'], 'vaso': ['bicchiere'], 'mesa': ['tavolo'],
    'cuenta': ['conto'], 'ganas': ['voglia'], 'partido': ['partita'],
    'mañana': ['domani', 'mattina'], 'ayer': ['ieri'], 'hoy': ['oggi'],
}


def sin_tilde(texto):
    return ''.join(
        c for c in unicodedata.normalize('NFD', texto.lower())
        if unicodedata.category(c) != 'Mn'
    )


def sumar(mapa, clave, traducciones):
    clave = sin_tilde(clave).strip()
    if not clave:
        return
    mapa.setdefault(clave, [])
    for t in traducciones:
        t = t.strip()
        if t and t not in mapa[clave] and len(mapa[clave]) < TOPE:
            mapa[clave].append(t)


def leer_freedict(ruta, it_es):
    arbol = ElementTree.parse(ruta)
    for entrada in arbol.iter(TEI + 'entry'):
        forma = entrada.find(f'{TEI}form/{TEI}orth')
        if forma is None or not (forma.text or '').strip():
            continue
        traducciones = []
        for cita in entrada.iter(TEI + 'cit'):
            if cita.get('type') != 'trans':
                continue
            for q in cita.iter(TEI + 'quote'):
                if q.text and q.text.strip():
                    traducciones.append(q.text.strip())
        if traducciones:
            sumar(it_es, forma.text, traducciones)


PRONOMBRES = {
    'yo', 'tu', 'vos', 'el', 'ella', 'nosotros', 'ustedes', 'ellos', 'ellas',
    'se', 'lo', 'la', 'me', 'te', 'nos', 'y', 'o', 'a', 'de', 'que',
}


def leer_verbos(assets, it_es, es_it_verbos):
    """Las formas conjugadas, que es lo que a FreeDict le falta."""
    datos = json.load(open(f'{assets}/verbos.json', encoding='utf-8'))
    cuantas = 0

    def guardar(italiano, espanol):
        nonlocal cuantas
        # "ho voluto" son dos palabras y las dos sirven de entrada: el que
        # marca "voluto" quiere saber qué es "voluto".
        formas = [p.strip(".,;:!?¿¡'\"") for p in italiano.lower().split()]
        formas = [p for p in formas if len(p) > 1]
        for palabra in formas:
            sumar(it_es, palabra, [espanol])
            cuantas += 1
        # Y al revés, palabra por palabra: el que escribe "#tenía#" quiere
        # "avevo", y el reverso automático solo tiene el infinitivo.
        ultima = formas[-1] if formas else None
        if ultima:
            for trozo in espanol.lower().replace('/', ' ').split():
                trozo = trozo.strip(".,;:!?¿¡'\"")
                if len(trozo) > 1 and trozo not in PRONOMBRES:
                    sumar(es_it_verbos, trozo, [ultima])

    for infinitivo, verbo in datos['verbos'].items():
        guardar(infinitivo, verbo['traduccion'])
        gerundio = verbo.get('gerundio')
        if gerundio:
            guardar(gerundio['italiano'], gerundio['espanol'])
        for tiempo in verbo.get('tiempos', {}).values():
            for persona in tiempo.values():
                guardar(persona['italiano'], persona['espanol'])
    return cuantas


def lo_que_tradujo_la_ia():
    """Las traducciones de scripts/traducciones.json, si está.

    De las palabras que faltaban, Wiktionary conoce casi todas: existen y
    están bien escritas. Lo que no hay en ningún lado libre es la
    traducción al castellano —FreeDict tiene 14.000 palabras y no trae
    "lumicino"—, así que se tradujeron una sola vez con Gemini y quedaron
    escritas acá. Ver scripts/traducir_lo_que_falta.py.

    Si el archivo no está, el diccionario se arma igual: estas palabras
    son las raras, y sin ellas queda como estaba antes.
    """
    donde = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         'traducciones.json')
    if not os.path.exists(donde):
        print('sin traducciones.json: se arma sin ellas', file=sys.stderr)
        return {}
    with open(donde, encoding='utf-8') as f:
        palabras = json.load(f)['palabras']

    salida = {}
    for palabra, que in palabras.items():
        traducciones = [t for t in que.get('es', []) if t]
        if traducciones:
            salida[sin_tilde(palabra)] = traducciones[:TOPE]
    return salida


def main():
    tei, assets = sys.argv[1], sys.argv[2]

    it_es = {}
    leer_freedict(tei, it_es)
    de_freedict = len(it_es)

    es_it_verbos = {}
    cuantas = leer_verbos(assets, it_es, es_it_verbos)
    con_verbos = len(it_es)

    # Lo escrito a mano va último y pisa: si FreeDict dice que "macchina" es
    # "máquina", acá decimos que también es "auto", y va primero.
    # Las que tradujo Gemini van ANTES que las escritas a mano: si alguna
    # vez se escribe a mano una que la IA ya había traducido, gana la de
    # la persona.
    de_la_ia = lo_que_tradujo_la_ia()
    for clave, traducciones in de_la_ia.items():
        sumar(it_es, clave, traducciones)

    for mano in (FUNCION, BASICAS, VERBOS, SUELTAS, DELASFAVOLE,
                 LASQUELAIANOPUDO):
        for clave, traducciones in mano.items():
            clave = clave.rstrip('_').replace('_adv', '')
            it_es[sin_tilde(clave)] = traducciones + [
                t for t in it_es.get(sin_tilde(clave), [])
                if t not in traducciones
            ][:TOPE - len(traducciones)]

    # El revés se arma dando vuelta, y después se le pisan las rioplatenses.
    es_it = {}
    for italiana, espanolas in it_es.items():
        for espanola in espanolas:
            sumar(es_it, espanola, [italiana])
    for clave, traducciones in es_it_verbos.items():
        sumar(es_it, clave, traducciones)
    for clave, traducciones in {**SUELTAS_ES, **RIOPLATENSE}.items():
        es_it[sin_tilde(clave)] = traducciones + [
            t for t in es_it.get(sin_tilde(clave), []) if t not in traducciones
        ][:TOPE - len(traducciones)]

    salida = {
        'version': 1,
        'credito': CREDITO,
        'licencia': LICENCIA,
        'fuente': FUENTE,
        'it': dict(sorted(it_es.items())),
        'es': dict(sorted(es_it.items())),
    }
    texto = json.dumps(salida, ensure_ascii=False, separators=(',', ':'))
    with open(f'{assets}/diccionario.json', 'w', encoding='utf-8') as f:
        f.write(texto)

    print(f'FreeDict:            {de_freedict} palabras')
    print(f'+ verbos de la app:  {con_verbos} ({cuantas} formas sumadas)')
    print(f'+ escritas a mano:   {len(it_es)}')
    print(f'al revés (es→it):    {len(es_it)}')
    print(f'archivo:             {len(texto.encode())/1024:.0f} KB')


if __name__ == '__main__':
    main()

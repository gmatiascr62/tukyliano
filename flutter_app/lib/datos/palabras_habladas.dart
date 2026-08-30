import '../modelos/palabra_hablada.dart';

/// Todo lo que se puede practicar, junto. La pantalla lo separa por grupo.
List<PalabraHablada> get palabrasParaDecir => [
      ...sonidosParaDecir,
      ...numerosParaDecir,
    ];

/// Las diez palabras de la prueba, una por cada sonido que el castellano hace
/// pronunciar mal.
///
/// Van escritas acá y no en un JSON a propósito: esto es una prueba para ver
/// si el micrófono del celular sirve para corregir. Si sirve, pasan a un JSON
/// como el resto y ahí se pueden agregar palabras sin sacar un APK nuevo.
const List<PalabraHablada> sonidosParaDecir = [
  PalabraHablada(
    italiano: 'cinque',
    espanol: 'cinco',
    pista: 'chín-cue',
    sonido: 'ci = ch',
  ),
  PalabraHablada(
    italiano: 'ciao',
    espanol: 'hola, chau',
    pista: 'cháo',
    sonido: 'ci = ch',
  ),
  PalabraHablada(
    italiano: 'chiesa',
    espanol: 'iglesia',
    pista: 'quié-sa',
    sonido: 'chi = qui',
  ),
  PalabraHablada(
    italiano: 'famiglia',
    espanol: 'familia',
    pista: 'fa-mí-lia, con la lengua contra el paladar',
    sonido: 'gli',
  ),
  PalabraHablada(
    italiano: 'gnocchi',
    espanol: 'ñoquis',
    pista: 'ñó-qui',
    sonido: 'gn = ñ',
  ),
  PalabraHablada(
    italiano: 'pesce',
    espanol: 'pescado',
    pista: 'pé-she',
    sonido: 'sce = sh',
  ),
  PalabraHablada(
    italiano: 'scuola',
    espanol: 'escuela',
    pista: 'scuó-la, sin la e de adelante',
    sonido: 'sc = sk',
  ),
  PalabraHablada(
    italiano: 'nonna',
    espanol: 'abuela',
    pista: 'nón-na, con la n larga',
    sonido: 'doble consonante',
  ),
  PalabraHablada(
    italiano: 'pizza',
    espanol: 'pizza',
    pista: 'pít-tsa',
    sonido: 'zz = ts',
  ),
  PalabraHablada(
    italiano: 'grazie',
    espanol: 'gracias',
    pista: 'grá-tsie',
    sonido: 'z = ts',
  ),
];

/// Los números del 0 al 30.
///
/// Son los que más se dicen en voz alta de verdad —la hora, el precio, el
/// número de la casa— y de paso repasan medio abecedario de sonidos raros:
/// zero empieza con la z italiana, dieci y undici llevan el "chi", quattro y
/// sette la doble consonante, ventuno y ventotto se comen la i de venti.
const List<PalabraHablada> numerosParaDecir = [
  PalabraHablada(
    italiano: 'zero',
    espanol: 'cero',
    pista: 'dzé-ro',
    sonido: '0',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'uno',
    espanol: 'uno',
    pista: 'ú-no',
    sonido: '1',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'due',
    espanol: 'dos',
    pista: 'dú-e, en dos golpes',
    sonido: '2',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'tre',
    espanol: 'tres',
    pista: 'tre, con la r bien marcada',
    sonido: '3',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'quattro',
    espanol: 'cuatro',
    pista: 'cuát-tro, apoyando la doble t',
    sonido: '4',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'cinque',
    espanol: 'cinco',
    pista: 'chín-cue',
    sonido: '5',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'sei',
    espanol: 'seis',
    pista: 'séi',
    sonido: '6',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'sette',
    espanol: 'siete',
    pista: 'sét-te, apoyando la doble t',
    sonido: '7',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'otto',
    espanol: 'ocho',
    pista: 'ót-to, apoyando la doble t',
    sonido: '8',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'nove',
    espanol: 'nueve',
    pista: 'nó-ve',
    sonido: '9',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'dieci',
    espanol: 'diez',
    pista: 'dié-chi',
    sonido: '10',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'undici',
    espanol: 'once',
    pista: 'ún-di-chi',
    sonido: '11',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'dodici',
    espanol: 'doce',
    pista: 'dó-di-chi',
    sonido: '12',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'tredici',
    espanol: 'trece',
    pista: 'tré-di-chi',
    sonido: '13',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'quattordici',
    espanol: 'catorce',
    pista: 'cuat-tór-di-chi',
    sonido: '14',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'quindici',
    espanol: 'quince',
    pista: 'cuín-di-chi',
    sonido: '15',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'sedici',
    espanol: 'dieciséis',
    pista: 'sé-di-chi',
    sonido: '16',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'diciassette',
    espanol: 'diecisiete',
    pista: 'di-chas-sét-te',
    sonido: '17',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'diciotto',
    espanol: 'dieciocho',
    pista: 'di-chót-to',
    sonido: '18',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'diciannove',
    espanol: 'diecinueve',
    pista: 'di-chan-nó-ve',
    sonido: '19',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'venti',
    espanol: 'veinte',
    pista: 'vén-ti',
    sonido: '20',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventuno',
    espanol: 'veintiuno',
    pista: 'ven-tú-no, sin la i',
    sonido: '21',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventidue',
    espanol: 'veintidós',
    pista: 'ven-ti-dú-e',
    sonido: '22',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventitré',
    espanol: 'veintitrés',
    pista: 'ven-ti-tré',
    sonido: '23',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventiquattro',
    espanol: 'veinticuatro',
    pista: 'ven-ti-cuát-tro',
    sonido: '24',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'venticinque',
    espanol: 'veinticinco',
    pista: 'ven-ti-chín-cue',
    sonido: '25',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventisei',
    espanol: 'veintiséis',
    pista: 'ven-ti-séi',
    sonido: '26',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventisette',
    espanol: 'veintisiete',
    pista: 'ven-ti-sét-te',
    sonido: '27',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventotto',
    espanol: 'veintiocho',
    pista: 'ven-tót-to, sin la i',
    sonido: '28',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'ventinove',
    espanol: 'veintinueve',
    pista: 'ven-ti-nó-ve',
    sonido: '29',
    grupo: GrupoHabla.numeros,
  ),
  PalabraHablada(
    italiano: 'trenta',
    espanol: 'treinta',
    pista: 'trén-ta',
    sonido: '30',
    grupo: GrupoHabla.numeros,
  ),
];

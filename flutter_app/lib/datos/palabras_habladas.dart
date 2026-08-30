import '../modelos/palabra_hablada.dart';

/// Las diez palabras de la prueba, una por cada sonido que el castellano hace
/// pronunciar mal.
///
/// Van escritas acá y no en un JSON a propósito: esto es una prueba para ver
/// si el micrófono del celular sirve para corregir. Si sirve, pasan a un JSON
/// como el resto y ahí se pueden agregar palabras sin sacar un APK nuevo.
const List<PalabraHablada> palabrasParaDecir = [
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

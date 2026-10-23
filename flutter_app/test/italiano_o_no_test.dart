import 'package:flutter_test/flutter_test.dart';
import 'package:tukyliano/ia/italiano_o_no.dart';

void main() {
  group('cuando contesta en castellano', () {
    test('la respuesta que apareció de verdad se detecta', () {
      // Medida en la prueba del modelo, al presentarse el alumno con su
      // nombre: "Ciao tuky, io sono Matías, io ho una sorella".
      expect(
        contestoEnCastellano(
          '¡Hola Matías! Yo también tengo una hermana. ¿A qué edad es ella?',
        ),
        isTrue,
      );
    });

    test('un solo signo de apertura ya alcanza', () {
      // En italiano no existe: no hay forma de que aparezca por error.
      expect(contestoEnCastellano('¿Come stai?'), isTrue);
    });

    test('una eñe también', () {
      expect(contestoEnCastellano('Tengo muchos años'), isTrue);
    });

    test('dos palabras que no existen en italiano alcanzan', () {
      expect(contestoEnCastellano('Hola, yo tengo una bicicleta'), isTrue);
    });
  });

  group('cuando contesta en italiano', () {
    test('una respuesta italiana no se toca', () {
      expect(
        contestoEnCastellano('Ciao! Che bello. Come si chiama tua sorella?'),
        isFalse,
      );
    });

    test('los acentos italianos no son castellano', () {
      // à è é ì ò ù son italianos; á í ú no.
      expect(
        contestoEnCastellano('Però è così: perché non vieni più?'),
        isFalse,
      );
    });

    test('una palabra sola que se parece no alcanza', () {
      // "pero" podría colarse adentro de una frase italiana; una respuesta
      // italiana con un tropiezo es mejor que ninguna respuesta.
      expect(contestoEnCastellano('Il pero è un albero. Ti piace?'), isFalse);
    });

    test('una respuesta vacía no es castellano ni nada', () {
      expect(contestoEnCastellano(''), isFalse);
      expect(contestoEnCastellano('   '), isFalse);
    });

    test('palabras italianas que se escriben parecido no confunden', () {
      // "ora", "sono", "molto", "come", "dove" son italianas de verdad.
      expect(
        contestoEnCastellano('Ora sono molto stanco. Come stai? Dove vai?'),
        isFalse,
      );
    });
  });
}

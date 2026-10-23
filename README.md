# Tukyliano

App de Android para practicar italiano, hecha en Flutter.

La app vive entera en [`flutter_app/`](flutter_app). Antes hubo una versión en
Python/Kivy en la raíz del repo; se migró a Flutter y se sacó, así que si en
algún commit viejo aparecen `main.py` o `buildozer.spec`, son de esa.

## Las secciones

| Sección | Qué se practica |
|---|---|
| Frasi | Se lee una frase en español y se escribe en italiano. Corrige palabra por palabra, en verde y rojo. |
| Verbi | Conjugar: sale un verbo, un tiempo y una persona. Se contesta escribiendo o eligiendo entre cuatro formas del mismo verbo. |
| Articoli | El artículo que va con cada sustantivo. Se practican los determinados, los indeterminados (con los partitivos) o los dos mezclados, y un botón explica la tabla entera. |
| Preposizioni | Completar el hueco con la preposición, simple o articulada. Se elige con cuáles practicar (se pueden dejar dos prendidas y el resto apagadas) y un botón explica la tabla. |
| Via | El «via» que se le pega al verbo (andare via, buttare via). Se elige el verbo o se escribe la frase entera, y un botón explica cómo se usa. |
| Racconti | Cuentos para leer en italiano; se toca el renglón para ver la traducción y escucharlo. La novela ocupa un solo renglón de la lista y adentro están sus capítulos, cada uno con su tapa. |
| Chat | Charla con una IA que corre adentro del celular, sin internet. Corrige sobre la marcha y traduce lo que se ponga entre almohadillas. |

## Los datos van aparte

Los verbos, las frases, los sustantivos, las preposiciones, el via y los
cuentos no están en el código: viven en [tukylingo_repo](https://github.com/gmatiascr62/tukylingo_repo)
y la app los chequea al arrancar. **Agregar o corregir contenido no necesita un
APK nuevo**: se edita el JSON de ese repo, se le sube el número de `version` y
el celular se lo baja solo la próxima vez que abre la app.

Cada JSON tiene además una copia en `flutter_app/assets/`, que es la que se usa
la primera vez que se instala y cuando no hay internet. Las dos se editan
juntas: la de `assets/` es la que verifican los tests.

Lo único que sí necesita un APK nuevo son las cosas que están adentro del
código: una pantalla, un arreglo, o las ilustraciones de los cuentos
(`flutter_app/assets/racconti/`).

## Cómo se publica

Cada push a `main` que toque `flutter_app/` dispara
[el workflow](.github/workflows/build-apk-flutter.yml), que:

1. corre `flutter analyze` y compila el APK de release;
2. lo firma con la clave del proyecto (dos secretos del repo: `KEYSTORE_BASE64`
   y `KEYSTORE_PASSWORD`) y verifica que la huella sea la de siempre;
3. lo publica como Release, con el número de la corrida como versión.

La app mira esa Release al arrancar y avisa cuando hay una versión más nueva.

> La firma no se puede perder ni cambiar: Android solo deja actualizar una app
> si el APK nuevo está firmado igual que el instalado. Si cambiara, todos los
> que la tengan instalada tendrían que desinstalarla para poder actualizar.
> Por eso el build falla si la huella no coincide.

## La IA del chat

La sección Chat no habla con ningún servidor: el modelo corre adentro del
celular. Es **Qwen2.5-1.5B-Instruct** cuantizado a Q4_K_M (1065 MB, licencia
Apache 2.0) y lo mueve **llama.cpp**, compilado para arm64 por el workflow del
APK y metido adentro en `jniLibs`.

Antes era Qwen3-0.6B, que pesaba un tercio. No servía: Qwen3 razona antes de
contestar —cien palabras para adentro en cada respuesta, veinte segundos en un
celular— y cuando se le pide que no razone, el de 0.6B copia la última frase en
vez de contestar. Está probado en `probar-modelo.yml` con cuatro formas de
pedírselo, con el archivo de 8 bits y con el mismo archivo de otro editor.

El modelo no viaja en el APK —pesa más que toda la app— sino que lo baja la
app la primera vez que se entra al chat, desde Hugging Face y clavado a una
revisión. Lo bajado se verifica contra un SHA-256 antes de usarlo, se puede
retomar si se corta, y después funciona en modo avión. No hay clave que pegar,
no hay cuota que se agote y nada de lo que se escribe sale del aparato.

El workflow `modelo-ia.yml` vuelve a chequear contra Hugging Face el tamaño y
la huella cada vez que se toca `lib/ia/modelo.dart`.

### Dónde anda y dónde no

Conviene decirlo de frente, porque "funciona sin internet" y "funciona en
cualquier celular" no son lo mismo:

- **La biblioteca del chat se compila solo para arm64**, que es lo que tiene
  cualquier teléfono de los últimos ocho años. En un Android de 32 bits el chat
  no aparece; el resto de la app anda igual.
- **El chat pide 4 GB de RAM.** El número sale de la práctica, no de una
  cuenta: el modelo ocupa algo más de un giga y Android no le da a una app toda
  la memoria del aparato. Con menos, se avisa y no se deja ni empezar.
- **Sin conexión anda el chat, no toda la app.** Hay que bajar el modelo una
  vez —más de un giga— y también hacen falta datos para traer verbos y frases
  nuevas y para enterarse de que hay una versión nueva. Después de esa primera
  bajada, charlar funciona en modo avión.
- **Lo que se mide en la computadora no prueba lo que pasa en un celular.** Las
  pruebas de `probar-modelo.yml` sirven para comparar modelos e instrucciones
  entre sí; la velocidad y la memoria reales solo se saben probando en un
  teléfono.

## Correr los tests

```bash
cd flutter_app
flutter test
flutter analyze
```

Buena parte de los tests no prueban código sino contenido: que ninguna palabra
de un cuento salga de la nada sin estar glosada, que las conjugaciones de un
verbo sean las de ese verbo, que cada foto que nombra un cuento exista. Son los
que avisan cuando un JSON nuevo trae algo mal.

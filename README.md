# Tukyliano

App de Android para practicar italiano, hecha en Flutter.

La app vive entera en [`flutter_app/`](flutter_app). Antes hubo una versión en
Python/Kivy en la raíz del repo; se migró a Flutter y se sacó, así que si en
algún commit viejo aparecen `main.py` o `buildozer.spec`, son de esa.

## Las secciones

| Sección | Qué se practica |
|---|---|
| Frasi | Se lee una frase en español y se escribe en italiano. Corrige palabra por palabra, en verde y rojo. |
| Verbi | Conjugar: sale un verbo, un tiempo y una persona. |
| Articoli | El artículo que va con cada sustantivo. Se practican los determinados, los indeterminados (con los partitivos) o los dos mezclados, y un botón explica la tabla entera. |
| Preposizioni | Completar el hueco con la preposición, simple o articulada. Se elige con cuáles practicar (se pueden dejar dos prendidas y el resto apagadas) y un botón explica la tabla. |
| Via | El «via» que se le pega al verbo (andare via, buttare via). Se elige el verbo o se escribe la frase entera, y un botón explica cómo se usa. |
| Racconti | Cuentos para leer en italiano; se toca el renglón para ver la traducción y escucharlo. |
| Chat | Charla con Gemini, que corrige sobre la marcha y traduce lo que se ponga entre almohadillas. |

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

## La clave de la IA

La sección Chat usa Gemini. La clave la pega el usuario en la app y queda solo
en el almacenamiento privado del celular: **nunca va en el código ni en el
repo**, que es público. Un test verifica que no se cuele ninguna.

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

/// El modelo de IA que corre adentro del celular.
///
/// **Qwen3-0.6B**, cuantizado a Q4_K_M y en formato GGUF, que es el que entiende
/// llama.cpp. Es de Alibaba, licencia Apache 2.0: se puede usar y distribuir sin
/// pedir permiso ni pagar nada.
///
/// Por qué este y no otro:
///
/// - 0.6B parámetros es lo más chico que todavía arma frases en italiano. Los de
///   270M (Gemma 3) hablan inglés y poco más.
/// - Q4_K_M es el equilibrio de siempre: cada peso ocupa cuatro bits y medio en
///   vez de dieciséis, así que entra en la memoria de un celular común y pierde
///   poca calidad frente al modelo sin cuantizar.
/// - Qwen3 trae italiano y español de fábrica, que es justo lo que hace falta
///   acá: un modelo entrenado solo en inglés no sirve para esto.
///
/// El archivo no viaja en el APK —pesa más que toda la app— sino que se baja la
/// primera vez que se entra al chat, desde el repositorio oficial de Qwen en
/// Hugging Face y clavado a una revisión: así nadie puede cambiar el archivo
/// abajo nuestro. Lo que se baja se compara contra [sha256DelModelo] antes de
/// usarlo.
library;

/// El archivo exacto dentro del repositorio.
const String nombreDelModelo = 'Qwen3-0.6B-Q4_K_M.gguf';

/// De dónde sale el archivo.
///
/// No es el repositorio oficial de Qwen porque ahí solo publicaron el Q8_0,
/// que pesa 609 MB y en memoria necesita más de lo que tiene un celular
/// barato. Unsloth es quien publica las versiones cuantizadas de estos modelos
/// —son los GGUF más bajados de Hugging Face— y el archivo es el mismo modelo
/// de Qwen, con la misma licencia Apache 2.0.
const String repositorioDelModelo = 'unsloth/Qwen3-0.6B-GGUF';

/// El commit del repositorio. Va clavado y no "main" a propósito: así el
/// archivo que se baja es siempre el mismo, aunque mañana publiquen otro.
const String revisionDelModelo = '50968a4468ef4233ed78cd7c3de230dd1d61a56b';

/// Cuánto pesa, para poder avisarlo antes de empezar a bajar: 378 MB.
const int bytesDelModelo = 396705472;

/// La huella del archivo. Si lo que se bajó no da esta huella, se tira: puede
/// haberse cortado la bajada o puede no ser el archivo que esperábamos.
///
/// Sale del puntero LFS de Hugging Face, y el workflow "Modelo de IA" la
/// vuelve a chequear cada vez que se toca este archivo.
const String sha256DelModelo =
    'ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a';

/// De dónde se baja.
const String urlDelModelo =
    'https://huggingface.co/$repositorioDelModelo/resolve/$revisionDelModelo/'
    '$nombreDelModelo';

/// Cómo se llama el archivo ya guardado en el celular.
///
/// Lleva la revisión adentro del nombre: si algún día se cambia de modelo, el
/// viejo no se confunde con el nuevo y se puede borrar.
const String archivoDelModelo = 'modelo-$revisionDelModelo.gguf';

/// El de al lado, donde se escribe mientras se baja. Hasta que no está entero y
/// verificado, el bueno no existe.
const String archivoDelModeloAMedias = '$archivoDelModelo.bajando';

/// Cuánto pesa, en megabytes y redondeado, para decírselo a alguien.
int get megasDelModelo => (bytesDelModelo / (1024 * 1024)).round();

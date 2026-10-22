/// El modelo de IA que corre adentro del celular.
///
/// **Qwen2.5-1.5B-Instruct**, cuantizado a Q4_K_M y en formato GGUF, que es el
/// que entiende llama.cpp. Es de Alibaba, licencia Apache 2.0: se puede usar y
/// distribuir sin pedir permiso ni pagar nada.
///
/// Antes acá estaba Qwen3-0.6B, que pesaba un tercio. Se cambió porque no
/// servía, y vale la pena contar por qué para no volver a elegirlo:
///
/// Qwen3 es un modelo que razona antes de contestar: escribe para adentro un
/// bloque de cien palabras y recién después responde. En un celular eso son
/// veinte segundos por respuesta, así que se le pedía que no razonara. Y sin
/// razonar, el de 0.6B —el más chico de la familia— no contesta: copia. Al
/// "Cosa mangi oggi?" del alumno le devolvía "Cosa mangi oggi?".
///
/// Eso se probó en serio antes de cambiar nada: con cuatro formas distintas de
/// pedírselo, con el archivo de 8 bits (que casi no pierde calidad) y con el
/// mismo archivo publicado por otro. Copiaba en todos los casos. Con el mismo
/// prompt, Qwen2.5-1.5B contestó "Ho mangiato una pizza e un gelato".
///
/// Lo que queda de aquella elección es el precio: mil megas en vez de
/// trescientos ochenta. Se bajan una sola vez, se puede cortar y seguir, y
/// después el chat anda sin internet para siempre. Un modelo que copia no
/// sirve para aprender, y uno que enseña mal es peor que uno que no está.
///
/// Por qué este y no otro:
///
/// - Contesta de una, sin razonar primero: es lo que hace que entre en el
///   tiempo que alguien espera frente a un chat.
/// - 1.5B parámetros es lo más chico de la familia que escribe italiano
///   correcto. El de 0.5B contestó "non so fare cosa", que está mal dicho, y
///   en una app para aprender eso es peor que no contestar.
/// - Q4_K_M es el equilibrio de siempre: cada peso ocupa cuatro bits y medio en
///   vez de dieciséis.
/// - Usa el mismo formato de charla que Qwen3, así que el prompt de la app le
///   sirve tal cual.
///
/// El archivo no viaja en el APK —pesa más que toda la app— sino que se baja la
/// primera vez que se entra al chat, desde el repositorio oficial de Qwen en
/// Hugging Face y clavado a una revisión: así nadie puede cambiar el archivo
/// abajo nuestro. Lo que se baja se compara contra [sha256DelModelo] antes de
/// usarlo.
library;

/// El archivo exacto dentro del repositorio.
const String nombreDelModelo = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';

/// De dónde sale el archivo: el repositorio oficial de Qwen.
const String repositorioDelModelo = 'Qwen/Qwen2.5-1.5B-Instruct-GGUF';

/// El commit del repositorio. Va clavado y no "main" a propósito: así el
/// archivo que se baja es siempre el mismo, aunque mañana publiquen otro.
const String revisionDelModelo = '91cad51170dc346986eccefdc2dd33a9da36ead9';

/// Cuánto pesa, para poder avisarlo antes de empezar a bajar: 1065 MB.
const int bytesDelModelo = 1117320736;

/// La huella del archivo. Si lo que se bajó no da esta huella, se tira: puede
/// haberse cortado la bajada o puede no ser el archivo que esperábamos.
///
/// Sale del puntero LFS de Hugging Face, y el workflow "Modelo de IA" la
/// vuelve a chequear cada vez que se toca este archivo.
const String sha256DelModelo =
    '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e';

/// De dónde se baja.
const String urlDelModelo =
    'https://huggingface.co/$repositorioDelModelo/resolve/$revisionDelModelo/'
    '$nombreDelModelo';

/// Cómo se llama el archivo ya guardado en el celular.
///
/// Lleva la revisión adentro del nombre: cuando se cambia de modelo, el viejo
/// no se confunde con el nuevo. Y como ocupa casi un giga, al bajar el nuevo se
/// borran los viejos.
const String archivoDelModelo = 'modelo-$revisionDelModelo.gguf';

/// Con qué empiezan todos los archivos de modelo, los de antes incluidos.
const String principioDeLosModelos = 'modelo-';

/// El de al lado, donde se escribe mientras se baja. Hasta que no está entero y
/// verificado, el bueno no existe.
const String archivoDelModeloAMedias = '$archivoDelModelo.bajando';

/// Cuánto pesa, en megabytes y redondeado, para decírselo a alguien.
int get megasDelModelo => (bytesDelModelo / (1024 * 1024)).round();

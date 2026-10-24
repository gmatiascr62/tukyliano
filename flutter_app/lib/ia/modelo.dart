/// El modelo de IA que corre adentro del celular.
///
/// **Gemma 3 1B Instruct**, cuantizado a Q4_K_M y en formato GGUF, que es el
/// que entiende llama.cpp. Es de Google.
///
/// Antes acá estuvo Qwen2.5-1.5B, y antes Qwen3-0.6B. Vale la pena contar por
/// qué se cambió, porque se midió y las mediciones están guardadas.
///
/// **Qwen3-0.6B** copiaba en vez de contestar: al "Cosa mangi oggi?" del
/// alumno le devolvía "Cosa mangi oggi?". Se probó con cuatro formas de
/// pedírselo, con el archivo de 8 bits y con el mismo modelo publicado por
/// otro. Copiaba siempre. Es un modelo que razona antes de contestar, y sin
/// razonar —que es como hay que usarlo en un celular, si no son veinte
/// segundos— el más chico de la familia no sabe hablar.
///
/// **Qwen2.5-1.5B** sí contestaba, pero llegó a su techo. Medido sobre
/// dieciocho respuestas con las instrucciones de la app: contestó sobre lo que
/// el alumno acababa de decir cinco veces. El resto se iba de tema. Y una vez
/// de dieciocho contestó entera en castellano, que en una app para practicar
/// italiano es lo peor que puede pasar.
///
/// **Gemma 3 1B**, con las mismas instrucciones y las mismas seis charlas:
/// doce de dieciocho. Cero respuestas en castellano en las cincuenta y cuatro
/// que se midieron, incluida la charla donde el alumno se presenta con su
/// nombre, que es justo la que rompía al anterior. Y entiende de qué se habla:
/// a "si chiama tuk-tuk" (el perro) Qwen preguntaba "dove andrai con il tuo
/// tuk-tuk?" —creía que era un vehículo— las tres veces; Gemma entendió que
/// era el nombre del perro las tres veces.
///
/// Por qué este y no otro:
///
/// - Contesta de una, sin razonar primero: es lo que hace que entre en el
///   tiempo que alguien espera frente a un chat.
/// - Pesa 768 MB contra los 1065 del anterior: casi 300 MB menos de descarga.
/// - Q4_K_M es el equilibrio de siempre: cada peso ocupa cuatro bits y medio en
///   vez de dieciséis.
///
/// Lo que cambió con él, y hay que recordar: **usa otro formato de charla**.
/// Gemma marca los turnos con `<start_of_turn>`, le dice "model" al que
/// contesta, y no tiene un lugar aparte para las instrucciones: van pegadas
/// adelante del primer mensaje del alumno. Eso está en [promptDeLaCharla].
///
/// **La licencia no es libre como la de Qwen.** Qwen2.5 era Apache 2.0; Gemma
/// tiene los términos de uso de Google, que permiten usarlo y distribuirlo
/// pero con condiciones. Para una app gratis no es un problema, pero no es lo
/// mismo y conviene saberlo antes que después.
///
/// El archivo lo publica **unsloth** y no Google: el repositorio oficial pide
/// aceptar la licencia a mano antes de bajar, y la app no puede hacer eso. Por
/// eso va clavado a una revisión y se compara contra [sha256DelModelo], igual
/// que siempre: si quien lo publica subiera otro archivo con el mismo nombre,
/// no se usa.
///
/// El archivo no viaja en el APK —pesa más que toda la app— sino que se baja la
/// primera vez que se entra al chat.
library;

/// El archivo exacto dentro del repositorio.
const String nombreDelModelo = 'gemma-3-1b-it-Q4_K_M.gguf';

/// De dónde sale el archivo.
const String repositorioDelModelo = 'unsloth/gemma-3-1b-it-GGUF';

/// El commit del repositorio. Va clavado y no "main" a propósito: así el
/// archivo que se baja es siempre el mismo, aunque mañana publiquen otro.
const String revisionDelModelo = 'f0b45be0aac41bd6a100a4b5734cad5f67255bfb';

/// Cuánto pesa, para poder avisarlo antes de empezar a bajar: 768 MB.
const int bytesDelModelo = 806058272;

/// La huella del archivo. Si lo que se bajó no da esta huella, se tira: puede
/// haberse cortado la bajada o puede no ser el archivo que esperábamos.
///
/// Sale del puntero LFS de Hugging Face, y el workflow "Modelo de IA" la
/// vuelve a chequear cada vez que se toca este archivo.
const String sha256DelModelo =
    '8270790f3ab69fdfe860b7b64008d9a19986d8df7e407bb018184caa08798ebd';

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

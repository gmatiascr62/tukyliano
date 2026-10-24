// Prueba que el archivo del modelo cargue y conteste, usando la misma versión
// de llama.cpp que lleva el APK.
//
// Existe porque cuando el chat no arranca en un celular no hay forma de ver
// por qué: el que falla es código nativo y sus mensajes no salen a ningún
// lado. Esto hace exactamente los mismos pasos —cargar el modelo, armar el
// contexto, contestar unas fichas— pero en un lugar donde sí se lee todo lo
// que llama.cpp tiene para decir. Así se sabe si el problema es el archivo,
// la versión de la biblioteca, o algo propio de Android.
//
// Lo compila y lo corre el workflow "Probar el modelo".

#include "llama.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

// llama.cpp cuenta cien renglones por carga: qué tensor leyó, qué capa va en
// qué lado. Cuando lo que se está mirando son las respuestas, eso tapa todo.
// Esto deja pasar solo los avisos y los errores, que son los que importan.
// Con TODO_EL_LOG=1 en el ambiente vuelve a contar todo.
static void soloLosProblemas(enum ggml_log_level nivel, const char * texto, void * nada) {
    (void) nada;
    if (nivel >= GGML_LOG_LEVEL_WARN) {
        fputs(texto, stderr);
    }
}

// Lee un archivo entero a memoria. Devuelve NULL si no se puede.
//
// El prompt de la app tiene renglones, comillas y barras: pasarlo por la
// línea de comandos es pedir que algo se escape mal y terminar probando otra
// cosa. Por archivo llega igual a como lo arma la app.
static char * leerTodo(const char * ruta) {
    FILE * archivo = fopen(ruta, "rb");
    if (archivo == NULL) {
        return NULL;
    }
    fseek(archivo, 0, SEEK_END);
    const long cuanto = ftell(archivo);
    fseek(archivo, 0, SEEK_SET);
    if (cuanto < 0) {
        fclose(archivo);
        return NULL;
    }
    char * texto = (char *) malloc((size_t) cuanto + 1);
    if (texto != NULL) {
        const size_t leidos = fread(texto, 1, (size_t) cuanto, archivo);
        texto[leidos] = '\0';
    }
    fclose(archivo);
    return texto;
}

int main(int argc, char ** argv) {
    if (argc < 2) {
        fprintf(stderr, "uso: probar_modelo <modelo.gguf> [archivo-con-el-prompt]\n");
        return 1;
    }

    const char * ruta = argv[1];
    // ChatML, el mismo formato que arma la app.
    const char * texto =
        "<|im_start|>user\nCiao! Come stai?<|im_end|>\n<|im_start|>assistant\n";
    char * delArchivo = NULL;
    if (argc > 2) {
        delArchivo = leerTodo(argv[2]);
        if (delArchivo == NULL) {
            fprintf(stderr, "no pude leer el prompt de %s\n", argv[2]);
            return 1;
        }
        texto = delArchivo;
        // Con doce pruebas seguidas, imprimir el prompt entero tapa las
        // respuestas, que es lo que se está mirando. Con VER_PROMPT se ve.
        if (getenv("VER_PROMPT") != NULL) {
            printf("== prompt:\n%s\n== fin del prompt\n", texto);
        }
    }

    llama_backend_init();
    if (getenv("TODO_EL_LOG") == NULL) {
        llama_log_set(soloLosProblemas, NULL);
    }
    printf("== sistema: %s\n", llama_print_system_info());

    // Los mismos que usa la app, y no los de fábrica: con los de fábrica esta
    // prueba pasaba mientras el chat del celular no cargaba. La diferencia
    // estaba justo acá, en estas dos líneas de abajo.
    struct llama_model_params parametrosDelModelo = llama_model_default_params();
    parametrosDelModelo.n_gpu_layers = 0;
    parametrosDelModelo.split_mode   = LLAMA_SPLIT_MODE_NONE;
    // -1, no 0: en un celular no hay ninguna placa de video, y pedirle la
    // número 0 de una lista vacía es lo que hacía fallar la carga.
    parametrosDelModelo.main_gpu     = -1;
    parametrosDelModelo.use_mmap     = true;
    parametrosDelModelo.use_mlock    = false;

    printf("== cargando %s\n", ruta);
    struct llama_model * modelo = llama_model_load_from_file(ruta, parametrosDelModelo);
    if (modelo == NULL) {
        printf("FALLO: no se pudo cargar el modelo.\n");
        return 2;
    }
    printf("OK: el modelo carga.\n");

    const struct llama_vocab * vocabulario = llama_model_get_vocab(modelo);

    // La plantilla que trae el propio archivo del modelo: es la forma exacta
    // en que fue entrenado para recibir una charla. Con PLANTILLA=1 se
    // imprime, y así se arma el prompt copiándola en vez de adivinándola.
    if (getenv("PLANTILLA") != NULL) {
        const char * plantilla = llama_model_chat_template(modelo, NULL);
        printf("== plantilla del modelo:\n%s\n== fin de la plantilla\n",
               plantilla == NULL ? "(el modelo no trae)" : plantilla);
    }

    struct llama_context_params parametrosDelContexto = llama_context_default_params();
    // Los mismos números que parametrosDelContexto() en motor_llama.dart.
    // La tanda tiene que entrar la charla entera: con 256 esta prueba se
    // moría —GGML_ASSERT(n_tokens_all <= cparams.n_batch)— con los prompts
    // largos, justo los que hacía falta probar.
    parametrosDelContexto.n_ctx           = 1024;
    parametrosDelContexto.n_batch         = 1024;
    parametrosDelContexto.n_ubatch        = 128;
    parametrosDelContexto.n_threads       = 2;
    parametrosDelContexto.n_threads_batch = 2;

    struct llama_context * contexto = llama_init_from_model(modelo, parametrosDelContexto);
    if (contexto == NULL) {
        printf("FALLO: no se pudo armar el contexto.\n");
        llama_model_free(modelo);
        return 3;
    }
    printf("OK: el contexto se arma.\n");

    llama_token fichas[512];
    const int cuantas = llama_tokenize(
        vocabulario, texto, (int32_t) strlen(texto), fichas, 512, true, true);
    if (cuantas <= 0) {
        printf("FALLO: no se pudo partir el texto en fichas (%d).\n", cuantas);
        return 4;
    }
    printf("OK: %d fichas de entrada.\n", cuantas);

    // El mismo sorteo que usa la app. Con "greedy" —agarrar siempre la ficha
    // más probable— la prueba no estaría probando lo que pasa en el celular,
    // que es el error que ya cometí una vez con main_gpu.
    struct llama_sampler * elector =
        llama_sampler_chain_init(llama_sampler_chain_default_params());
    if (getenv("GREEDY") != NULL) {
        llama_sampler_chain_add(elector, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(elector, llama_sampler_init_penalties(64, 1.15f, 0.0f, 0.0f));
        llama_sampler_chain_add(elector, llama_sampler_init_top_k(40));
        llama_sampler_chain_add(elector, llama_sampler_init_top_p(0.9f, 1));
        llama_sampler_chain_add(elector, llama_sampler_init_temp(0.6f));
        llama_sampler_chain_add(elector, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    }

    struct llama_batch tanda = llama_batch_get_one(fichas, cuantas);
    llama_token ficha = 0;

    // Cuántas fichas como mucho. Con FICHAS se cambia desde afuera: pensar
    // gasta muchas antes de llegar a la respuesta.
    const char * cuantasPide = getenv("FICHAS");
    const int tope = cuantasPide == NULL ? 80 : atoi(cuantasPide);

    // Cuánto tarda importa tanto como qué contesta: un modelo que contesta
    // mejor pero tarda el doble puede no servir en un celular. Acá se mide en
    // una computadora, así que el número no es el del teléfono; sirve para
    // comparar un modelo con otro.
    const clock_t arranque = clock();
    int cuantasSalieron = 0;

    printf("== respuesta: ");
    fflush(stdout);
    for (int i = 0; i < tope; i++) {
        if (llama_decode(contexto, tanda) != 0) {
            printf("\nFALLO: llama_decode no pudo seguir.\n");
            return 5;
        }
        ficha = llama_sampler_sample(elector, contexto, -1);
        if (llama_vocab_is_eog(vocabulario, ficha)) {
            break;
        }
        char pedazo[256];
        const int largo = llama_token_to_piece(
            vocabulario, ficha, pedazo, sizeof(pedazo), 0, false);
        if (largo > 0) {
            fwrite(pedazo, 1, (size_t) largo, stdout);
            fflush(stdout);
        }
        cuantasSalieron++;
        tanda = llama_batch_get_one(&ficha, 1);
    }

    const double tardo = (double) (clock() - arranque) / CLOCKS_PER_SEC;
    printf("\n== %d fichas en %.1f s (%.1f por segundo)\n",
           cuantasSalieron, tardo,
           tardo > 0 ? cuantasSalieron / tardo : 0.0);
    printf("OK: el modelo contesta.\n");

    free(delArchivo);
    llama_sampler_free(elector);
    llama_free(contexto);
    llama_model_free(modelo);
    llama_backend_free();
    return 0;
}

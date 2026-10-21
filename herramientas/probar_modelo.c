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
#include <string.h>

int main(int argc, char ** argv) {
    if (argc < 2) {
        fprintf(stderr, "uso: probar_modelo <modelo.gguf> [texto]\n");
        return 1;
    }

    const char * ruta = argv[1];
    // El formato de Qwen3, igual que el que arma la app.
    const char * texto = argc > 2
        ? argv[2]
        : "<|im_start|>user\nCiao! Come stai?<|im_end|>\n<|im_start|>assistant\n";

    llama_backend_init();
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

    // Los mismos números que usa la app.
    struct llama_context_params parametrosDelContexto = llama_context_default_params();
    parametrosDelContexto.n_ctx           = 1024;
    parametrosDelContexto.n_batch         = 256;
    parametrosDelContexto.n_ubatch        = 256;
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

    struct llama_sampler * elector = llama_sampler_init_greedy();

    struct llama_batch tanda = llama_batch_get_one(fichas, cuantas);
    llama_token ficha = 0;

    printf("== respuesta: ");
    fflush(stdout);
    for (int i = 0; i < 32; i++) {
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
        tanda = llama_batch_get_one(&ficha, 1);
    }
    printf("\nOK: el modelo contesta.\n");

    llama_sampler_free(elector);
    llama_free(contexto);
    llama_model_free(modelo);
    llama_backend_free();
    return 0;
}

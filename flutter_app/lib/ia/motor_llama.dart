import 'dart:async';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../logica/capacidad.dart';
import 'motor_ia.dart';

/// El motor de verdad: llama.cpp corriendo adentro del celular.
///
/// No hay servidor, no hay clave y no hay internet: el modelo es un archivo en
/// la carpeta privada de la app y las cuentas las hace el procesador del
/// teléfono.
///
/// Decisiones que valen la pena contar:
///
/// - **Todo en otro isolate.** [LlamaParent] levanta un isolate aparte y las
///   cuentas pasan ahí. Si corrieran en el de la interfaz, la pantalla quedaría
///   congelada todo el rato que tarda en contestar, que en un celular de gama
///   baja es medio minuto.
/// - **Solo procesador.** nGpuLayers en cero: la GPU de un celular común no
///   ayuda con un modelo así y las bibliotecas de GPU no están en todos los
///   aparatos. Es a propósito, para que ande en la mayor cantidad de celulares.
/// - **Contexto corto.** 1024 tokens de memoria y 160 de respuesta. Cada token
///   de contexto ocupa memoria y tiempo; para una charla de dos frases no hace
///   falta más, y así entra en teléfonos chicos y no se recalienta.
/// - **Se libera al salir.** El modelo ocupa unos 400 MB de RAM. Si quedara
///   cargado al irse del chat, Android mataría la app apenas se abra otra cosa.
class MotorLlama implements MotorIA {
  MotorLlama({
    required this.rutaDelModelo,
    this.hilos,
    this.cuantoContexto = 1024,
    this.cuantoContesta = 160,
  });

  /// El .gguf ya bajado y verificado.
  final String rutaDelModelo;

  /// Cuántos núcleos usar. Null = la mitad de los que haya.
  final int? hilos;

  final int cuantoContexto;
  final int cuantoContesta;

  /// Cuánto se espera un pedacito antes de dar la respuesta por colgada.
  static const Duration _paciencia = Duration(seconds: 90);

  LlamaParent? _llama;
  String _problema = '';

  /// Cuál de las dos bibliotecas nativas resultó ser la que está. Se recuerda
  /// para no volver a probar la que no en cada carga.
  static String? _bibliotecaQueEstaba;

  @override
  bool get listo => _llama != null && _problema.isEmpty;

  @override
  String get problema => _problema;

  @override
  Future<bool> preparar() async {
    if (_llama != null) return true;
    _problema = '';

    if (!File(rutaDelModelo).existsSync()) {
      _problema = 'No está el archivo del modelo. Bajalo de nuevo.';
      return false;
    }

    try {
      // En Android la biblioteca nativa viaja adentro del APK, en jniLibs, y
      // se abre por nombre. En la computadora (los tests de escritorio) se
      // deja que la busque sola.
      //
      // Se prueban las dos: el paquete de Dart abre libmtmd.so —la que suma el
      // soporte de imágenes— pero según cómo se haya compilado llama.cpp puede
      // existir solo libllama.so, y para charlar alcanza con esa.
      if (Platform.isAndroid) {
        Llama.libraryPath = _bibliotecaQueEstaba ?? 'libmtmd.so';
      }

      final contexto = ContextParams()
        ..nCtx = cuantoContexto
        ..nPredict = cuantoContesta
        ..nBatch = 256
        ..nUbatch = 256
        ..nThreads = hilos ?? hilosParaElModelo()
        ..nThreadsBatch = hilos ?? hilosParaElModelo();

      final modelo = ModelParams()
        // Cero: solo procesador. Ver el comentario de arriba.
        ..nGpuLayers = 0
        // El archivo se mapea en vez de copiarse a memoria: así el sistema
        // puede soltar pedazos cuando necesita memoria, en vez de matar la app.
        ..useMemorymap = true
        ..useMemoryLock = false;

      final sorteo = SamplerParams()
        // Bajo a propósito: un modelo chico con temperatura alta inventa
        // palabras que no existen, y acá eso se lo enseña mal a alguien.
        ..temp = 0.6
        ..topK = 40
        ..topP = 0.9
        // Sin esto se queda repitiendo la misma frase hasta llenar el renglón.
        ..penaltyRepeat = 1.15
        ..penaltyLastTokens = 64;

      final llama = LlamaParent(
        LlamaLoad(
          path: rutaDelModelo,
          modelParams: modelo,
          contextParams: contexto,
          samplingParams: sorteo,
        ),
      );

      try {
        await llama.init();
        if (Platform.isAndroid) _bibliotecaQueEstaba = Llama.libraryPath;
      } catch (error) {
        // La otra biblioteca, por si la primera no estaba.
        if (!Platform.isAndroid || Llama.libraryPath == 'libllama.so') rethrow;
        Llama.libraryPath = 'libllama.so';
        await llama.init();
        _bibliotecaQueEstaba = 'libllama.so';
      }

      // init() vuelve enseguida: cargar el modelo sigue en el isolate. Se
      // espera a que avise que está listo, con un techo para no quedar
      // esperando para siempre si el celular no da.
      final hasta = DateTime.now().add(const Duration(seconds: 90));
      while (llama.status != LlamaStatus.ready &&
          llama.status != LlamaStatus.error &&
          DateTime.now().isBefore(hasta)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      if (llama.status != LlamaStatus.ready) {
        await llama.dispose();
        _problema = llama.status == LlamaStatus.error
            ? 'No se pudo cargar el modelo en este celular.'
            : 'El modelo tardó demasiado en cargar. Probá cerrando otras apps.';
        return false;
      }

      _llama = llama;
      return true;
    } catch (error) {
      _problema = 'Este celular no puede correr el modelo ($error).';
      return false;
    }
  }

  @override
  Stream<String> responder(String prompt) {
    final llama = _llama;
    if (llama == null) {
      return Stream<String>.error(
        const ProblemaDelMotor('El modelo no está cargado.'),
      );
    }

    final salida = StreamController<String>();
    StreamSubscription<String>? pedazos;
    StreamSubscription<CompletionEvent>? finales;
    Timer? reloj;
    var cerrado = false;

    Future<void> cerrar([Object? error]) async {
      if (cerrado) return;
      cerrado = true;
      reloj?.cancel();
      await pedazos?.cancel();
      await finales?.cancel();
      if (error != null && !salida.isClosed) salida.addError(error);
      if (!salida.isClosed) await salida.close();
    }

    void reiniciarElReloj() {
      reloj?.cancel();
      reloj = Timer(_paciencia, () {
        llama.stop();
        cerrar(const ProblemaDelMotor(
          'La respuesta tardó demasiado. Probá con un mensaje más corto.',
        ));
      });
    }

    pedazos = llama.stream.listen(
      (pedazo) {
        reiniciarElReloj();
        if (!salida.isClosed) salida.add(pedazo);
      },
      onError: (Object error) => cerrar(ProblemaDelMotor('$error')),
    );

    // Solo se genera de a una respuesta por vez, así que el aviso de
    // terminado que llegue es el nuestro.
    finales = llama.completions.listen((fin) {
      cerrar(fin.success
          ? null
          : ProblemaDelMotor(fin.errorDetails ?? 'La IA no pudo contestar.'));
    });

    reiniciarElReloj();
    llama.sendPrompt(prompt).catchError((Object error) {
      cerrar(ProblemaDelMotor('$error'));
      return '';
    });

    salida.onCancel = () => cerrar();
    return salida.stream;
  }

  @override
  Future<void> cortar() async {
    try {
      await _llama?.stop();
    } catch (_) {
      // Cortar algo que ya terminó no es un problema.
    }
  }

  @override
  Future<void> liberar() async {
    final llama = _llama;
    _llama = null;
    try {
      await llama?.dispose();
    } catch (_) {
      // Lo que importa es soltar la referencia; si el isolate ya se fue, mejor.
    }
  }
}

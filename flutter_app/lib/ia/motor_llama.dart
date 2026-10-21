import 'dart:async';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../logica/capacidad.dart';
import 'archivo_gguf.dart';
import 'espia_de_stderr.dart';
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

  /// Si la vez que anduvo fue mapeando el archivo o leyéndolo entero.
  static bool? _mapearAnduvo;

  /// El único motor que puede haber levantado en toda la app.
  ///
  /// Es estático porque el isolate también lo es: el paquete levanta siempre
  /// el número 1, así que dos motores a la vez no existen. Al salir del chat
  /// se libera, pero liberar es asincrónico y entrar de nuevo puede pasarle
  /// por encima; por eso, antes de levantar uno nuevo, se espera de verdad a
  /// que el anterior se haya ido.
  static LlamaParent? _elQueEstaLevantado;

  @override
  bool get listo => _llama != null && _problema.isEmpty;

  @override
  String get problema => _problema;

  @override
  Future<bool> preparar() async {
    if (_llama != null) return true;
    _problema = '';

    final archivo = File(rutaDelModelo);
    if (!archivo.existsSync()) {
      _problema = 'No está el archivo del modelo. Bajalo de nuevo.';
      return false;
    }

    // Si el archivo estuviera cortado o no fuera un GGUF, el error nativo sería
    // el mismo "no se pudo cargar" de siempre. Mirarlo antes cuesta nada y saca
    // esa duda del medio.
    final ficha = await mirarElArchivo(archivo);
    if (ficha != null && !ficha.esGguf) {
      _problema = 'El archivo del modelo no sirve (${ficha.resumen}). '
          'Borralo y bajalo de nuevo.';
      return false;
    }

    // En Android la biblioteca nativa viaja adentro del APK, en jniLibs, y se
    // abre por nombre. Se prueban las dos: el paquete de Dart abre libmtmd.so
    // —la que suma el soporte de imágenes— pero si esa no carga, para charlar
    // alcanza con libllama.so. En la computadora (los tests de escritorio) se
    // deja que la busque sola.
    final bibliotecas = Platform.isAndroid
        ? {_bibliotecaQueEstaba ?? 'libmtmd.so', 'libllama.so'}
        : <String?>{null};

    // Mapear el archivo es lo mejor cuando se puede: el sistema va trayendo los
    // pedazos que hacen falta y puede soltarlos si necesita memoria. Pero en
    // algunos celulares el mapeo no está permitido y entonces no carga nada.
    // Leerlo entero gasta más memoria y por eso va segundo, no primero.
    final conMapa = _mapearAnduvo == null ? [true, false] : [_mapearAnduvo!];

    // llama.cpp cuenta en detalle por qué no pudo cargar, pero lo escribe en la
    // salida de error, que en un celular no se lee en ningún lado. Mientras
    // dura el intento se desvía a un archivo; si sale bien no se usa.
    final espia = EspiaDeStderr(File('${archivo.parent.path}/$archivoDelDicho'));
    espia.empezar();

    final problemas = <String>[];
    for (final biblioteca in bibliotecas) {
      for (final mapear in conMapa) {
        // Cada intento con su propio LlamaParent: reusar el anterior era el
        // error "An isolate with ID [1] already exists", que además tapaba el
        // problema de verdad. Un parent levanta un isolate y no lo suelta hasta
        // que se lo libera.
        final llama = await _intentarCon(biblioteca, mapear: mapear);
        if (llama != null) {
          _llama = llama;
          if (biblioteca != null) _bibliotecaQueEstaba = biblioteca;
          _mapearAnduvo = mapear;
          await espia.terminar();
          return true;
        }
        problemas.add('${biblioteca ?? 'la del sistema'}'
            '${mapear ? '' : ' sin mapear'}: $_ultimoProblema');
      }
    }

    final dicho = loQueImporta(await espia.terminar());

    final queEs = ficha == null ? '' : ' (${ficha.resumen})';
    final loQueDijo = dicho.isEmpty ? '' : ' Dice: $dicho';
    _problema =
        'No se pudo cargar el modelo$queEs. ${problemas.join(' / ')}.$loQueDijo';
    return false;
  }

  String _ultimoProblema = '';

  /// Un intento de levantar el modelo con una biblioteca.
  ///
  /// Devuelve null si no se pudo, y en [_ultimoProblema] queda por qué. Lo que
  /// se haya levantado a medias se libera antes de volver: si quedara dando
  /// vueltas, el intento siguiente chocaría con él.
  Future<LlamaParent?> _intentarCon(
    String? biblioteca, {
    required bool mapear,
  }) async {
    // Si quedó uno de antes —de la vez pasada que se entró al chat, o de un
    // intento que falló— hay que esperarlo antes de levantar otro.
    final anterior = _elQueEstaLevantado;
    if (anterior != null) {
      _elQueEstaLevantado = null;
      await _soltar(anterior);
    }

    if (biblioteca != null) Llama.libraryPath = biblioteca;

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
      // Mapeado, el sistema puede soltar pedazos cuando necesita memoria en
      // vez de matar la app. Sin mapear entra entero en RAM: se usa solo si
      // mapear no funcionó.
      ..useMemorymap = mapear
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
        // Sin esto el paquete le tapa la boca a llama.cpp, y lo que tiene para
        // decir cuando algo sale mal es justo lo que hace falta.
        verbose: true,
      ),
    );

    try {
      await llama.init();

      // init() vuelve enseguida: cargar el modelo sigue en el isolate. Se
      // espera a que avise que está listo, con un techo para no quedar
      // esperando para siempre si el celular no da.
      final hasta = DateTime.now().add(const Duration(seconds: 90));
      while (llama.status != LlamaStatus.ready &&
          llama.status != LlamaStatus.error &&
          DateTime.now().isBefore(hasta)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      if (llama.status == LlamaStatus.ready) {
        _elQueEstaLevantado = llama;
        return llama;
      }

      _ultimoProblema = llama.status == LlamaStatus.error
          ? 'el modelo no cargó'
          : 'tardó demasiado en cargar';
    } catch (error) {
      _ultimoProblema = '$error';
    }

    await _soltar(llama);
    return null;
  }

  /// Suelta un intento fallido. Sin esto, el isolate que dejó levantado hace
  /// fallar al siguiente.
  Future<void> _soltar(LlamaParent llama) async {
    try {
      await llama.dispose();
    } catch (_) {
      // Si ya se había muerto solo, mejor.
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
    if (identical(_elQueEstaLevantado, llama)) _elQueEstaLevantado = null;
    try {
      await llama?.dispose();
    } catch (_) {
      // Lo que importa es soltar la referencia; si el isolate ya se fue, mejor.
    }
  }
}

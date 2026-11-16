import 'package:flutter/material.dart';

import '../datos/buscador_de_palabras.dart';
import '../datos/descargas.dart';
import '../datos/reproductor.dart';
import '../datos/repositorio_diccionario.dart';
import '../datos/repositorio_lecturas.dart';
import '../modelos/diccionario.dart';
import '../modelos/lectura.dart';
import '../tema.dart';
import 'pantalla_una_lectura.dart';

/// Las fábulas de La Fontaine, leídas en italiano.
///
/// Es el primer lugar de la app donde el audio **no viaja en el APK**. Hasta
/// ahora todo el sonido iba adentro: con tres episodios del podcast ya eran
/// 95 MB, y así no se puede crecer. Acá el catálogo viaja —es texto, pesa
/// nada, y deja ver la lista entera sin internet— y cada audio se baja
/// cuando se toca, una sola vez.
///
/// Por qué fábulas y no un libro: duran entre uno y tres minutos, son
/// historias que uno ya conoce, y cada una se cierra sola. Si no entendiste
/// una, perdiste dos minutos. Un capítulo de novela mal entendido es una
/// derrota; una fábula mal entendida es un intento más.
class PantallaLecturas extends StatefulWidget {
  const PantallaLecturas({
    super.key,
    this.repositorio,
    this.descargas,
    this.reproductor,
    this.diccionario,
    this.buscador,
  });

  final RepositorioLecturas? repositorio;
  final Descargas? descargas;
  final Reproductor? reproductor;
  final RepositorioDiccionario? diccionario;

  /// Quién busca las palabras que el diccionario no tiene. Se le pasa a la
  /// pantalla de la fábula, que es donde se tocan.
  final BuscadorDePalabras? buscador;

  @override
  State<PantallaLecturas> createState() => _PantallaLecturasState();
}

class _PantallaLecturasState extends State<PantallaLecturas> {
  late final RepositorioLecturas _repositorio =
      widget.repositorio ?? RepositorioLecturas();
  late final Descargas _descargas = widget.descargas ?? DescargasEnElCelular();
  late final Reproductor _reproductor =
      widget.reproductor ?? ReproductorDeVerdad();
  late final RepositorioDiccionario _diccionario =
      widget.diccionario ?? RepositorioDiccionario();

  /// El diccionario se carga aparte y sin frenar nada: son 770 KB y para ver
  /// la lista no hace falta.
  Diccionario _elDiccionario = const Diccionario();

  /// Cuál está abierta, con su texto. Null cuando se ve la lista.
  Lectura? _abierta;

  /// Dónde quedó guardado el audio de la que está abierta.
  String _rutaAbierta = '';

  Lecturas _catalogo = const Lecturas();
  bool _cargando = true;

  /// Cuáles ya están en el celular.
  Set<String> _guardadas = {};

  /// Cuáles se están bajando ahora.
  final Set<String> _bajando = {};

  /// Cuál falló al bajar. Se muestra en su propio renglón y se borra al
  /// reintentar: un error que se queda para siempre es ruido.
  final Set<String> _fallaron = {};

  @override
  void initState() {
    super.initState();
    _arrancar();
    _prepararDiccionario();
  }

  Future<void> _prepararDiccionario() async {
    final diccionario = await _diccionario.cargar();
    if (!mounted) return;
    setState(() => _elDiccionario = diccionario);
  }

  @override
  void dispose() {
    // Pausar y no soltar: el reproductor es uno solo para toda la app.
    _reproductor.pausar();
    super.dispose();
  }

  Future<void> _arrancar() async {
    final catalogo = await _repositorio.cargar();
    final guardadas =
        await _descargas.cualesEstan(catalogo.lecturas.map((f) => f.archivo));
    if (!mounted) return;
    setState(() {
      _catalogo = catalogo;
      _guardadas = guardadas;
      _cargando = false;
    });
  }

  /// Un toque hace lo que corresponda: si no está la baja, y después abre la
  /// fábula con su texto y la pone a sonar.
  ///
  /// Un solo gesto en vez de un botón de bajar y otro de escuchar. Nadie baja
  /// una fábula para no escucharla.
  Future<void> _tocar(Lectura lectura) async {
    if (!_guardadas.contains(lectura.archivo)) {
      await _bajarla(lectura);
      if (!mounted || !_guardadas.contains(lectura.archivo)) return;
    }

    final donde = await _descargas.donde(lectura.archivo);
    if (donde == null || !mounted) return;

    setState(() {
      _abierta = lectura;
      _rutaAbierta = donde.path;
    });
  }

  /// Vuelve a la lista. Si el audio no se pudo abrir, lo borra: así el
  /// próximo toque lo baja de nuevo en vez de fallar siempre igual.
  Future<void> _cerrarLaFavola(Lectura lectura) async {
    final anduvo = _reproductor.porQueFallo == null;
    if (!anduvo) {
      await _descargas.borrar(lectura.archivo);
      if (!mounted) return;
      setState(() {
        _guardadas.remove(lectura.archivo);
        _fallaron.add(lectura.id);
      });
    }
    if (!mounted) return;
    setState(() => _abierta = null);
  }

  Future<void> _bajarla(Lectura lectura) async {
    setState(() {
      _bajando.add(lectura.id);
      _fallaron.remove(lectura.id);
    });

    final quedo =
        await _descargas.bajar(_catalogo.donde(lectura), lectura.archivo);
    if (!mounted) return;

    setState(() {
      _bajando.remove(lectura.id);
      if (quedo == null) {
        _fallaron.add(lectura.id);
      } else {
        _guardadas.add(lectura.archivo);
      }
    });
  }

  /// Baja las que falten, una por una.
  ///
  /// Una por una y no todas juntas a propósito: veintidós pedidos al mismo
  /// tiempo con señal mala fallan todos, y además así se ve avanzar la lista.
  Future<void> _bajarLasQueFaltan() async {
    for (final lectura in _catalogo.lecturas) {
      if (!mounted) return;
      if (_guardadas.contains(lectura.archivo)) continue;
      await _bajarla(lectura);
    }
  }

  List<Lectura> get _faltan => [
        for (final f in _catalogo.lecturas)
          if (!_guardadas.contains(f.archivo)) f,
      ];

  @override
  Widget build(BuildContext context) {
    final abierta = _abierta;
    if (abierta != null) {
      return PantallaUnaLectura(
        // La clave hace que cambiar de fábula arranque de cero en vez de
        // quedarse con el estado de la anterior.
        key: ValueKey(abierta.id),
        lectura: abierta,
        ruta: _rutaAbierta,
        reproductor: _reproductor,
        diccionario: _elDiccionario,
        deQuien: _catalogo.deQuien,
        buscador: widget.buscador,
        alVolver: () => _cerrarLaFavola(abierta),
      );
    }

    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_catalogo.hay) {
      return const _Cartel('Todavía no hay fábulas cargadas.');
    }

    final faltan = _faltan;
    final bajandoTodas = _bajando.isNotEmpty && faltan.length > 1;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _DeQueVa(
          cuantas: _catalogo.lecturas.length,
          faltan: faltan,
          bajando: bajandoTodas,
          alBajarTodas: bajandoTodas ? null : _bajarLasQueFaltan,
        ),
        const SizedBox(height: 10),
        for (final lectura in _catalogo.lecturas)
          _UnaFavola(
            lectura: lectura,
            guardada: _guardadas.contains(lectura.archivo),
            bajando: _bajando.contains(lectura.id),
            fallo: _fallaron.contains(lectura.id),
            alTocar: () => _tocar(lectura),
          ),
        const SizedBox(height: 18),
        _Credito(catalogo: _catalogo),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Cartel extends StatelessWidget {
  const _Cartel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Tema.textoTenue),
        ),
      ),
    );
  }
}

/// El botón de bajarlas todas, y nada más.
///
/// Antes acá había también un párrafo explicando de qué iban las fábulas y
/// cómo funcionaba la descarga. Se sacó: ocupaba media pantalla, se lee una
/// vez y después estorba todos los días. Lo que hacía falta explicar ya lo
/// dice la lista sola —cada una muestra su duración y, si no está bajada, su
/// peso—.
class _DeQueVa extends StatelessWidget {
  const _DeQueVa({
    required this.cuantas,
    required this.faltan,
    required this.bajando,
    required this.alBajarTodas,
  });

  final int cuantas;
  final List<Lectura> faltan;
  final bool bajando;
  final VoidCallback? alBajarTodas;

  @override
  Widget build(BuildContext context) {
    if (faltan.isEmpty) return const SizedBox.shrink();

    final pesan = faltan.fold<int>(0, (suma, f) => suma + f.bytes);
    final enMegas = (pesan / 1048576).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: alBajarTodas,
          icon: Icon(bajando ? Icons.downloading : Icons.download),
          label: Text(
            bajando
                ? 'Bajando…'
                : faltan.length == cuantas
                    ? 'Bajar todas ($enMegas MB)'
                    : 'Bajar las que faltan ($enMegas MB)',
          ),
        ),
      ),
    );
  }
}

class _UnaFavola extends StatelessWidget {
  const _UnaFavola({
    required this.lectura,
    required this.guardada,
    required this.bajando,
    required this.fallo,
    required this.alTocar,
  });

  final Lectura lectura;
  final bool guardada;
  final bool bajando;
  final bool fallo;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: SizedBox(
        width: 34,
        height: 34,
        child: Center(child: _elIcono()),
      ),
      title: Text(
        lectura.titulo,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Tema.titulo,
        ),
      ),
      subtitle: Text(
        fallo
            ? 'No se pudo bajar. Tocá para probar de nuevo.'
            : guardada
                ? lectura.cuantoDura
                : '${lectura.cuantoDura} · ${lectura.cuantoPesa}',
        style: TextStyle(
          fontSize: 12.5,
          color: fallo ? Tema.incorrecto : Tema.textoTenue,
        ),
      ),
      onTap: bajando ? null : alTocar,
    );
  }

  Widget _elIcono() {
    if (bajando) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (fallo) {
      return const Icon(Icons.refresh, color: Tema.incorrecto);
    }
    if (!guardada) {
      // Una flecha para abajo: lo que va a pasar al tocar es que se baje.
      return const Icon(Icons.arrow_circle_down_outlined,
          color: Tema.textoTenue);
    }
    return const Icon(Icons.play_circle_fill, color: Tema.verde, size: 30);
  }
}

/// Quién las grabó. No es decorativo: son voluntarios que leyeron esto
/// gratis para que cualquiera lo pueda usar.
class _Credito extends StatelessWidget {
  const _Credito({required this.catalogo});

  final Lecturas catalogo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            catalogo.credito,
            style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
          ),
          if (catalogo.textoDe.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              // El texto sale de otro lado que el audio, y es justo decirlo:
              // son dos grupos de gente distintos que lo pusieron gratis.
              'El texto: ${catalogo.textoDe}.',
              style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../datos/audio_de_fondo.dart';
import '../datos/reproductor.dart';
import '../datos/repositorio_radios.dart';
import '../modelos/radio_italiana.dart';
import '../tema.dart';

/// Radio italiana en vivo.
///
/// Es la pantalla más simple de la app y la más difícil de usar: italiano
/// nativo, a velocidad real, sin texto, sin repetición y sin pausa que sirva
/// de algo. No está acá para entender, está para acostumbrar el oído. Las
/// primeras veces se entienden tres palabras, y eso ya es el ejercicio.
///
/// Por eso la pantalla dice de entrada para qué sirve y para qué no, en vez
/// de vender que "escuchando radio se aprende solo". Una emisora que promete
/// más de lo que da se abre una vez.
///
/// Nada se conecta hasta que se toca play: una radio en vivo gasta datos
/// todo el tiempo que está abierta, y entrar a mirar no tiene por qué
/// gastarlos.
class PantallaRadio extends StatefulWidget {
  const PantallaRadio({super.key, this.repositorio, this.reproductor});

  final RepositorioRadios? repositorio;
  final Reproductor? reproductor;

  @override
  State<PantallaRadio> createState() => _PantallaRadioState();
}

/// En qué anda la radio.
///
/// Importa distinguir *conectando* de *sonando*: un stream tarda entre uno y
/// diez segundos en abrir, y sin ese estado el botón parece no haber
/// respondido y uno lo toca de nuevo.
enum _Estado { quieta, conectando, sonando, pausada, falla, cortada }

class _PantallaRadioState extends State<PantallaRadio> {
  late final RepositorioRadios _repositorio =
      widget.repositorio ?? RepositorioRadios();
  late final Reproductor _reproductor =
      widget.reproductor ?? ReproductorDeVerdad();

  List<RadioItaliana> _radios = const [];
  RadioItaliana? _cual;
  bool _cargando = true;

  _Estado _estado = _Estado.quieta;
  String? _porQueFallo;

  /// True cuando el stream de esta emisora ya está abierto en el reproductor:
  /// así pausar y seguir no vuelve a conectarse de cero.
  bool _abierta = false;

  StreamSubscription<void>? _esperandoElCorte;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    final radios = await _repositorio.cargar();
    if (!mounted) return;
    setState(() {
      _radios = radios;
      // Con una sola emisora la lista sobra: se entra directo a ella.
      _cual = radios.length == 1 ? radios.first : null;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _esperandoElCorte?.cancel();
    // Pausar y no soltar: el reproductor es uno solo para toda la app y lo
    // suelta el que lo creó. Y pausar hay que pausar igual: una radio en vivo
    // que sigue sonando con la pantalla cerrada gasta datos sin que nadie la
    // escuche.
    _reproductor.pausar();
    super.dispose();
  }

  Future<void> _playOPausa() async {
    final radio = _cual;
    if (radio == null) return;

    if (_estado == _Estado.sonando) {
      await _reproductor.pausar();
      if (mounted) setState(() => _estado = _Estado.pausada);
      return;
    }

    // Pausada con el stream abierto: en vivo, "seguir" no retoma donde se
    // dejó —eso ya pasó— pero el reproductor se reengancha solo.
    if (_abierta && _estado == _Estado.pausada) {
      setState(() => _estado = _Estado.sonando);
      await _reproductor.reproducir();
      return;
    }

    setState(() {
      _estado = _Estado.conectando;
      _porQueFallo = null;
    });

    final abrio = await _reproductor.cargarDesdeInternet(
      radio.stream,
      titulo: radio.nombre,
      deQuien: radio.quien,
    );
    if (!mounted) return;

    if (!abrio) {
      setState(() {
        _abierta = false;
        _estado = _Estado.falla;
        _porQueFallo = _reproductor.porQueFallo;
      });
      return;
    }

    // Una radio en vivo no "termina", así que si el reproductor dice que
    // terminó es que se cortó: o se cayó la emisora o se cayó la señal. Hay
    // que decirlo, porque desde afuera el silencio y el corte son iguales.
    _esperandoElCorte?.cancel();
    _esperandoElCorte = _reproductor.termino.listen((_) {
      if (!mounted) return;
      setState(() {
        _abierta = false;
        _estado = _Estado.cortada;
      });
    });

    setState(() {
      _abierta = true;
      _estado = _Estado.sonando;
    });
    await _reproductor.reproducir();
  }

  Future<void> _elegir(RadioItaliana radio) async {
    await _reproductor.pausar();
    _esperandoElCorte?.cancel();
    if (!mounted) return;
    setState(() {
      _cual = radio;
      _abierta = false;
      _estado = _Estado.quieta;
      _porQueFallo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_radios.isEmpty) {
      return const _Cartel(
        'Todavía no hay emisoras cargadas.',
      );
    }

    final radio = _cual;
    if (radio == null) {
      return _Lista(radios: _radios, alElegir: _elegir);
    }

    return _Escucha(
      radio: radio,
      estado: _estado,
      porQueFallo: _porQueFallo,
      alPlay: _playOPausa,
      // Con una sola emisora no hay a dónde volver.
      alVolverALaLista: _radios.length > 1 ? () => _elegir(radio) : null,
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

class _Lista extends StatelessWidget {
  const _Lista({required this.radios, required this.alElegir});

  final List<RadioItaliana> radios;
  final void Function(RadioItaliana) alElegir;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: radios.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final radio = radios[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: const Icon(Icons.radio, color: Tema.verde),
          title: Text(
            radio.nombre,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(radio.que, style: const TextStyle(fontSize: 14)),
          ),
          onTap: () => alElegir(radio),
        );
      },
    );
  }
}

class _Escucha extends StatelessWidget {
  const _Escucha({
    required this.radio,
    required this.estado,
    required this.porQueFallo,
    required this.alPlay,
    required this.alVolverALaLista,
  });

  final RadioItaliana radio;
  final _Estado estado;
  final String? porQueFallo;
  final VoidCallback alPlay;
  final VoidCallback? alVolverALaLista;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _Botonera(radio: radio, estado: estado, alPlay: alPlay),
        if (estado == _Estado.falla || estado == _Estado.cortada)
          _Problema(estado: estado, porQue: porQueFallo),
        const SizedBox(height: 22),
        _Parrafo(radio.que),
        if (radio.ojo.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Ojo(radio.ojo),
        ],
        const SizedBox(height: 18),
        const _ComoEscucharla(),
        if (!AudioDeFondo.anda) ...[
          const SizedBox(height: 18),
          const _SinAudioDeFondo(),
        ],
        const SizedBox(height: 18),
        _Credito(radio: radio),
        if (alVolverALaLista != null) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: alVolverALaLista,
              child: const Text('Ver las otras emisoras'),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// El nombre, el botón grande y en qué anda.
class _Botonera extends StatelessWidget {
  const _Botonera({
    required this.radio,
    required this.estado,
    required this.alPlay,
  });

  final RadioItaliana radio;
  final _Estado estado;
  final VoidCallback alPlay;

  @override
  Widget build(BuildContext context) {
    final conectando = estado == _Estado.conectando;
    final sonando = estado == _Estado.sonando;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Tema.verde, Tema.verdeClaro],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Tema.verde.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            radio.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _enQueAnda(estado),
            style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)),
          ),
          const SizedBox(height: 20),
          // Un solo botón, redondo y enorme. Es lo único que hay para hacer
          // acá, así que no tiene por qué compartir el renglón con nada.
          Semantics(
            button: true,
            label: sonando ? 'Parar la radio' : 'Escuchar la radio',
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                // Mientras conecta no hace nada: tocar de nuevo cortaría la
                // conexión que está abriéndose y volvería a empezar.
                onTap: conectando ? null : alPlay,
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Center(
                    child: conectando
                        ? const SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Tema.verde),
                            ),
                          )
                        : Icon(
                            sonando ? Icons.stop : Icons.play_arrow,
                            size: 46,
                            color: Tema.verde,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _enQueAnda(_Estado estado) => switch (estado) {
        _Estado.quieta => 'En vivo desde Italia',
        _Estado.conectando => 'Conectando…',
        _Estado.sonando => 'Sonando en vivo',
        _Estado.pausada => 'Pausada',
        _Estado.falla => 'No se pudo conectar',
        _Estado.cortada => 'Se cortó',
      };
}

/// Lo que salió mal, en criollo y con el motivo de verdad abajo.
///
/// El motivo técnico va igual porque una radio falla por tres cosas
/// distintas —no hay señal, la emisora se cayó, la dirección cambió— y sin
/// él no se puede saber cuál.
class _Problema extends StatelessWidget {
  const _Problema({required this.estado, required this.porQue});

  final _Estado estado;
  final String? porQue;

  @override
  Widget build(BuildContext context) {
    final cortada = estado == _Estado.cortada;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cortada
                ? 'Se cortó la transmisión. Puede ser la señal de tu celular '
                    'o la emisora, que son voluntarios y no transmiten las '
                    '24 horas. Tocá de nuevo para reconectar.'
                : 'No se pudo conectar. Fijate que tengas internet y probá de '
                    'nuevo; si sigue así, puede ser que la emisora esté caída.',
            style: const TextStyle(fontSize: 13.5, color: Tema.texto),
          ),
          if (porQue != null) ...[
            const SizedBox(height: 6),
            Text(
              porQue!,
              style: const TextStyle(fontSize: 11, color: Tema.textoTenue),
            ),
          ],
        ],
      ),
    );
  }
}

class _Parrafo extends StatelessWidget {
  const _Parrafo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 14.5, height: 1.4, color: Tema.texto),
      ),
    );
  }
}

/// La advertencia, en su propia cajita para que no se lea como publicidad de
/// la emisora.
class _Ojo extends StatelessWidget {
  const _Ojo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Tema.verdeOscuro),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: Tema.titulo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cómo usarla sin frustrarse.
///
/// Es la parte que convierte "poner la radio" en un ejercicio. Sin esto, la
/// pantalla es un botón de play y a los dos minutos se cierra porque no se
/// entiende nada, que es exactamente lo que va a pasar al principio.
class _ComoEscucharla extends StatelessWidget {
  const _ComoEscucharla();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cómo escucharla',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
          const SizedBox(height: 8),
          for (final consejo in const [
            'Diez minutos por día alcanzan. Es ejercicio de oído, no de '
                'comprensión.',
            'No trates de entender todo. Contá las palabras que sí '
                'entendiste: la semana que viene van a ser más.',
            'Cuando pesques una palabra que no conocés, anotala y buscala '
                'después con #palabra# en el chat.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '· ',
                    style: TextStyle(fontSize: 13.5, color: Tema.verde),
                  ),
                  Expanded(
                    child: Text(
                      consejo,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Avisa que la radio se va a cortar al salir de la pantalla.
///
/// Solo aparece cuando el servicio de audio no se pudo prender. Sin esto, el
/// síntoma desde afuera es que "se corta a los treinta segundos" y no hay
/// forma de saber si es el celular, la señal o la app.
class _SinAudioDeFondo extends StatelessWidget {
  const _SinAudioDeFondo();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se va a cortar al bloquear la pantalla',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'No se pudo prender el servicio que deja sonar el audio en '
            'segundo plano. La radio funciona igual mientras la pantalla esté '
            'encendida.',
            style: TextStyle(fontSize: 12.5, color: Tema.textoTenue),
          ),
          if (AudioDeFondo.porQueNo != null) ...[
            const SizedBox(height: 6),
            Text(
              AudioDeFondo.porQueNo!,
              style: const TextStyle(fontSize: 11, color: Tema.textoTenue),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quién hace la emisora y dónde ayudarla.
///
/// No es decorativo: la app reproduce un audio que paga otro. Que se vea de
/// quién es, y que se pueda llegar a su sitio desde acá, es lo mínimo.
class _Credito extends StatelessWidget {
  const _Credito({required this.radio});

  final RadioItaliana radio;

  Future<void> _abrir(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          if (radio.quien.isNotEmpty)
            Text(
              'La transmite ${radio.quien}. Tukyliano solo la reproduce: no '
              'la hace, no la graba y no gana nada con ella.',
              style: const TextStyle(fontSize: 12, color: Tema.textoTenue),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (radio.sitio.isNotEmpty)
                TextButton(
                  onPressed: () => _abrir(radio.sitio),
                  child: const Text('Su sitio'),
                ),
              if (radio.sostener.isNotEmpty)
                TextButton(
                  onPressed: () => _abrir(radio.sostener),
                  child: const Text('Ayudarla'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

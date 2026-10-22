import 'dart:async';

import 'package:flutter/material.dart';

import '../datos/descarga_modelo.dart';
import '../ia/modelo.dart';
import '../logica/capacidad.dart';
import '../tema.dart';

/// La pantalla de la primera vez: bajar el modelo de IA.
///
/// Son unos cuantos megas y hay que ser claro sobre eso antes de empezar, no
/// después. También es el lugar donde se avisa si el celular no da: mejor
/// decirlo acá que dejar que alguien se baje mil megas para que después la app se
/// cierre sola al abrir el chat.
class PantallaModelo extends StatefulWidget {
  const PantallaModelo({
    super.key,
    required this.descarga,
    required this.alTerminar,
    this.capacidad,
  });

  final DescargaModelo descarga;

  /// Se llama con la ruta del modelo cuando ya está bajado y verificado.
  final ValueChanged<String> alTerminar;

  /// Inyectable para los tests; en el celular se mira de verdad.
  final Capacidad? capacidad;

  @override
  State<PantallaModelo> createState() => _PantallaModeloState();
}

class _PantallaModeloState extends State<PantallaModelo> {
  StreamSubscription<Descarga>? _bajando;
  Descarga _como = const Descarga(paso: PasoDescarga.mirando);
  Capacidad? _celular;
  int _aMedias = 0;

  @override
  void initState() {
    super.initState();
    _mirar();
  }

  @override
  void dispose() {
    widget.descarga.cortar();
    _bajando?.cancel();
    super.dispose();
  }

  Future<void> _mirar() async {
    final celular = widget.capacidad ?? await mirarElCelular();
    final ruta = await widget.descarga.rutaSiEsta();
    final aMedias = await widget.descarga.cuantoHayAMedias();
    if (!mounted) return;

    if (ruta != null) {
      widget.alTerminar(ruta);
      return;
    }

    setState(() {
      _celular = celular;
      _aMedias = aMedias;
      _como = const Descarga(paso: PasoDescarga.falta);
    });
  }

  void _empezar() {
    _bajando?.cancel();
    setState(() => _como = Descarga(paso: PasoDescarga.bajando, bajados: _aMedias));

    _bajando = widget.descarga.bajar().listen((como) async {
      if (!mounted) return;
      setState(() => _como = como);
      if (como.paso == PasoDescarga.listo) {
        final ruta = await widget.descarga.rutaSiEsta();
        if (!mounted || ruta == null) return;
        widget.alTerminar(ruta);
      }
    });
  }

  void _parar() {
    widget.descarga.cortar();
    _bajando?.cancel();
    _bajando = null;
  }

  @override
  Widget build(BuildContext context) {
    final celular = _celular;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.auto_awesome, size: 54, color: Tema.verde),
            const SizedBox(height: 14),
            const Text(
              'El chat ahora funciona sin internet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Tema.titulo,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'La IA corre adentro de tu celular, no en un servidor. Hay que '
              'bajarla una sola vez: son $megasDelModelo MB. Después charlás '
              'aunque estés en el subte, y no se gasta nada.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.35,
                color: Tema.texto,
              ),
            ),
            if (celular != null && celular.aviso.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Aviso(texto: celular.aviso, grave: !celular.puede),
            ],
            const SizedBox(height: 20),
            _loQueVa(celular),
          ],
        ),
      ),
    );
  }

  Widget _loQueVa(Capacidad? celular) {
    switch (_como.paso) {
      case PasoDescarga.mirando:
        return const Center(
          child: Text(
            'Un momento...',
            style: TextStyle(fontSize: 15, color: Tema.textoTenue),
          ),
        );

      case PasoDescarga.falta:
        final puede = celular?.puede ?? true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_aMedias > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Hay ${(_aMedias / (1024 * 1024)).round()} MB bajados de '
                  'antes: sigue desde ahí.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13.5, color: Tema.verdeOscuro),
                ),
              ),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: puede ? _empezar : null,
                style: Tema.botonPrincipal,
                child: Text(
                  _aMedias > 0 ? 'Seguir bajando' : 'Bajar la IA',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Conviene con wifi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Tema.textoTenue),
            ),
          ],
        );

      case PasoDescarga.bajando:
      case PasoDescarga.verificando:
        final verificando = _como.paso == PasoDescarga.verificando;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                // Mientras verifica no hay porcentaje que mostrar: se deja
                // moviéndose para que se vea que no se colgó.
                value: verificando ? null : _como.cuanto,
                minHeight: 14,
                backgroundColor: Tema.borde,
                valueColor: const AlwaysStoppedAnimation(Tema.verde),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              verificando
                  ? 'Revisando que esté completo...'
                  : '${(_como.cuanto * 100).round()}% · ${_como.texto}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Tema.titulo,
              ),
            ),
            const SizedBox(height: 14),
            if (!verificando)
              TextButton(
                onPressed: _parar,
                style: TextButton.styleFrom(foregroundColor: Tema.textoTenue),
                child: const Text('Pausar'),
              ),
          ],
        );

      case PasoDescarga.fallo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Aviso(texto: _como.problema, grave: true),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _empezar,
                style: Tema.botonPrincipal,
                child: const Text(
                  'Probar de nuevo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );

      case PasoDescarga.listo:
        return const Center(
          child: Text(
            'Listo, abriendo el chat...',
            style: TextStyle(fontSize: 15, color: Tema.verdeOscuro),
          ),
        );
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.grave});

  final String texto;
  final bool grave;

  @override
  Widget build(BuildContext context) {
    final color = grave ? Tema.incorrecto : Tema.verdeOscuro;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: grave ? const Color(0x14D32F2F) : Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            grave ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 13.5, height: 1.3, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

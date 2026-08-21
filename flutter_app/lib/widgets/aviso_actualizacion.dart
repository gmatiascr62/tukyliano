import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../datos/actualizacion.dart';
import '../tema.dart';

/// La franjita que avisa que hay una versión nueva y la baja.
///
/// Aparece sola al arrancar, arriba de todo, y no tapa nada: si no hay nada
/// nuevo (o no hay internet) ocupa cero. Se puede cerrar y no vuelve a
/// aparecer hasta la próxima vez que se abre la app.
///
/// Android no deja que una app se reemplace sola, así que lo último lo tiene
/// que apretar el usuario: cuando termina de bajar se abre el instalador del
/// sistema y ahí va el "Instalar".
class AvisoActualizacion extends StatefulWidget {
  const AvisoActualizacion({super.key, this.actualizacion, this.abrir});

  /// Inyectables para los tests.
  final Actualizacion? actualizacion;

  /// Qué hacer con el archivo bajado. En la app, abrir el instalador.
  final Future<void> Function(String ruta)? abrir;

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> {
  late final Actualizacion _actualizacion =
      widget.actualizacion ?? Actualizacion();

  VersionNueva? _nueva;
  bool _cerrado = false;
  bool _bajando = false;
  double _avance = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  Future<void> _buscar() async {
    final nueva = await _actualizacion.buscar();
    if (!mounted || nueva == null) return;
    setState(() => _nueva = nueva);
  }

  Future<void> _bajar() async {
    final nueva = _nueva;
    if (nueva == null || _bajando) return;

    setState(() {
      _bajando = true;
      _avance = 0;
      _error = '';
    });

    final archivo = await _actualizacion.bajar(
      nueva,
      alAvanzar: (avance) {
        if (mounted) setState(() => _avance = avance);
      },
    );

    if (!mounted) return;
    if (archivo == null) {
      setState(() {
        _bajando = false;
        _error = 'No se pudo bajar. Probá de nuevo.';
      });
      return;
    }

    setState(() => _bajando = false);
    final abrir = widget.abrir ?? _abrirInstalador;
    await abrir(archivo.path);
  }

  Future<void> _abrirInstalador(String ruta) => OpenFilex.open(ruta);

  @override
  Widget build(BuildContext context) {
    final nueva = _nueva;
    if (nueva == null || _cerrado) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: _bajando ? _bajandoWidget(nueva) : _ofertaWidget(nueva),
    );
  }

  Widget _ofertaWidget(VersionNueva nueva) {
    return Row(
      children: [
        const Icon(Icons.system_update, size: 20, color: Tema.verdeOscuro),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hay una versión nueva (${nueva.tamano})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Tema.verdeOscuro,
                ),
              ),
              Text(
                // El tamaño va arriba y esto abajo: son 40 MB y con datos
                // móviles se notan.
                _error.isEmpty ? 'Mejor con wifi' : _error,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _error.isEmpty ? Tema.textoTenue : Tema.incorrecto,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _bajar,
          style: TextButton.styleFrom(
            foregroundColor: Tema.verdeOscuro,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Actualizar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _cerrado = true),
          icon: const Icon(Icons.close, size: 18, color: Tema.textoTenue),
          tooltip: 'Ahora no',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _bajandoWidget(VersionNueva nueva) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bajando la versión ${nueva.nombre}...  ${(_avance * 100).round()}%',
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Tema.verdeOscuro,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _avance,
            minHeight: 5,
            backgroundColor: Colors.white,
            valueColor: const AlwaysStoppedAnimation(Tema.verde),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cuando termine, Android te va a preguntar si la instalás.',
          style: TextStyle(fontSize: 11.5, color: Tema.textoTenue),
        ),
      ],
    );
  }
}

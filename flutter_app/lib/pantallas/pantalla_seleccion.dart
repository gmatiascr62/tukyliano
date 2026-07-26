import 'package:flutter/material.dart';

import '../constantes.dart';
import '../modelos/verbo.dart';
import '../tema.dart';

/// Elección de verbos y tiempos a practicar, con tildes. Equivale a
/// PantallaSeleccion de la app Kivy y se reutiliza para Verbos y para Frases.
class PantallaSeleccion extends StatefulWidget {
  const PantallaSeleccion({
    super.key,
    required this.verbos,
    required this.alConfirmar,
  });

  final Map<String, Verbo> verbos;
  final void Function(List<String> verbos, List<String> tiempos) alConfirmar;

  @override
  State<PantallaSeleccion> createState() => _PantallaSeleccionState();
}

class _PantallaSeleccionState extends State<PantallaSeleccion> {
  late Map<String, bool> _verbosElegidos;
  late Map<String, bool> _tiemposElegidos;

  @override
  void initState() {
    super.initState();
    _verbosElegidos = {for (final v in widget.verbos.keys) v: true};
    _tiemposElegidos = {for (final t in tiemposDisponibles) t: true};
  }

  @override
  void didUpdateWidget(PantallaSeleccion anterior) {
    super.didUpdateWidget(anterior);
    // Pueden llegar verbos nuevos desde GitHub mientras la pantalla está
    // abierta: se agregan tildados, sin pisar lo que el usuario ya destildó.
    for (final v in widget.verbos.keys) {
      _verbosElegidos.putIfAbsent(v, () => true);
    }
    _verbosElegidos.removeWhere((v, _) => !widget.verbos.containsKey(v));
  }

  void _confirmar() {
    // Si no quedó nada tildado se usa todo, igual que en la app Kivy.
    var verbos = _verbosElegidos.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (verbos.isEmpty) verbos = widget.verbos.keys.toList();

    var tiempos = _tiemposElegidos.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (tiempos.isEmpty) tiempos = List.of(tiemposDisponibles);

    widget.alConfirmar(verbos, tiempos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Titulo('Elegí los verbos a practicar'),
        Expanded(
          child: widget.verbos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay verbos cargados.',
                    style: TextStyle(fontSize: 16, color: Tema.textoTenue),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final verbo in widget.verbos.values)
                      _FilaTilde(
                        texto: verbo.traduccion.isEmpty
                            ? verbo.nombre
                            : '${verbo.nombre} (${verbo.traduccion})',
                        valor: _verbosElegidos[verbo.nombre] ?? true,
                        onCambio: (v) => setState(
                          () => _verbosElegidos[verbo.nombre] = v,
                        ),
                      ),
                  ],
                ),
        ),
        const _Titulo('Elegí los tiempos'),
        for (final tiempo in tiemposDisponibles)
          _FilaTilde(
            texto: etiquetasTiempo[tiempo] ?? tiempo,
            valor: _tiemposElegidos[tiempo] ?? true,
            onCambio: (v) => setState(() => _tiemposElegidos[tiempo] = v),
          ),
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: _confirmar,
            style: Tema.botonPrincipal,
            child: const Text(
              'Empezar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Tema.titulo,
        ),
      ),
    );
  }
}

class _FilaTilde extends StatelessWidget {
  const _FilaTilde({
    required this.texto,
    required this.valor,
    required this.onCambio,
  });

  final String texto;
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: valor ? Tema.verdeSuave : Tema.superficie,
        borderRadius: BorderRadius.circular(Tema.radioChico),
        child: InkWell(
          onTap: () => onCambio(!valor),
          borderRadius: BorderRadius.circular(Tema.radioChico),
          child: Container(
            height: 52,
            padding: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Tema.radioChico),
              border: Border.all(
                color: valor ? Tema.verde.withValues(alpha: 0.35) : Tema.borde,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Checkbox(
                    value: valor,
                    onChanged: (v) => onCambio(v ?? false),
                  ),
                ),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: valor ? FontWeight.w600 : FontWeight.w400,
                      color: valor ? Tema.titulo : Tema.textoTenue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../datos/repositorio_racconti.dart';
import '../modelos/racconto.dart';
import '../tema.dart';

/// Cuentos para leer en italiano.
///
/// A diferencia de las otras secciones acá no hay puntaje ni respuestas: es
/// leer. El cuento se muestra entero, como cuento, y se toca el renglón que
/// no se entiende para ver la traducción. Frase por frase con un botón de
/// "Siguiente" volvería a ser un ejercicio, y de esos ya hay tres.
class PantallaRacconti extends StatefulWidget {
  const PantallaRacconti({super.key, this.repositorio});

  /// Inyectable para los tests.
  final RepositorioRacconti? repositorio;

  @override
  State<PantallaRacconti> createState() => _PantallaRaccontiState();
}

class _PantallaRaccontiState extends State<PantallaRacconti> {
  late final RepositorioRacconti _repositorio =
      widget.repositorio ?? RepositorioRacconti();

  List<Racconto> _racconti = const [];
  Racconto? _abierto;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await _repositorio.cargar();
    if (!mounted) return;
    setState(() {
      _racconti = _repositorio.datos.racconti;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(
        child: Text(
          'Cargando cuentos...',
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    final abierto = _abierto;
    if (abierto != null) {
      return _VistaRacconto(
        racconto: abierto,
        alVolver: () => setState(() => _abierto = null),
      );
    }

    if (_racconti.isEmpty) {
      return const Center(
        child: Text(
          'Todavía no hay cuentos cargados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Tema.textoTenue),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _racconti.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TarjetaRacconto(
        racconto: _racconti[i],
        alTocar: () => setState(() => _abierto = _racconti[i]),
      ),
    );
  }
}

class _TarjetaRacconto extends StatelessWidget {
  const _TarjetaRacconto({required this.racconto, required this.alTocar});

  final Racconto racconto;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tema.superficie,
      borderRadius: BorderRadius.circular(Tema.radio),
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(Tema.radio),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Tema.radio),
            border: Border.all(color: Tema.borde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      racconto.titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Tema.titulo,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      racconto.tituloEspanol,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Tema.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Pastilla('Nivel ${racconto.nivel}'),
                  const SizedBox(height: 5),
                  Text(
                    '${racconto.lineas.length} frases',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Tema.textoTenue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Tema.verdeOscuro,
        ),
      ),
    );
  }
}

/// El cuento abierto.
class _VistaRacconto extends StatefulWidget {
  const _VistaRacconto({required this.racconto, required this.alVolver});

  final Racconto racconto;
  final VoidCallback alVolver;

  @override
  State<_VistaRacconto> createState() => _VistaRaccontoState();
}

class _VistaRaccontoState extends State<_VistaRacconto> {
  /// Los renglones que están mostrando la traducción.
  final _reveladas = <int>{};
  bool _vocabularioAbierto = false;

  void _tocarLinea(int i) {
    setState(() {
      if (!_reveladas.remove(i)) _reveladas.add(i);
    });
  }

  bool get _todasReveladas =>
      _reveladas.length == widget.racconto.lineas.length;

  void _mostrarTodo() {
    setState(() {
      if (_todasReveladas) {
        _reveladas.clear();
      } else {
        _reveladas.addAll(
          List.generate(widget.racconto.lineas.length, (i) => i),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final racconto = widget.racconto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: widget.alVolver,
              icon: const Icon(Icons.arrow_back, color: Tema.verdeOscuro),
              tooltip: 'Volver a los cuentos',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    racconto.titulo,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Tema.titulo,
                    ),
                  ),
                  Text(
                    racconto.tituloEspanol,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Tema.textoTenue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tocá el renglón que no entiendas',
          style: TextStyle(fontSize: 12.5, color: Tema.textoTenue),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < racconto.lineas.length; i++)
                  _Linea(
                    linea: racconto.lineas[i],
                    revelada: _reveladas.contains(i),
                    alTocar: () => _tocarLinea(i),
                  ),
                if (racconto.vocabulario.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _vocabulario(racconto),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _mostrarTodo,
            style: OutlinedButton.styleFrom(
              foregroundColor: Tema.verdeOscuro,
              side: const BorderSide(color: Tema.borde),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Tema.radio),
              ),
            ),
            child: Text(
              _todasReveladas ? 'Ocultar todo' : 'Mostrar todo',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Las palabras nuevas, plegadas. Son las que frenan de verdad: una frase
  /// entera se adivina por contexto, una palabra suelta no.
  Widget _vocabulario(Racconto racconto) {
    return Container(
      decoration: BoxDecoration(
        color: Tema.verdeSuave,
        borderRadius: BorderRadius.circular(Tema.radio),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _vocabularioAbierto = !_vocabularioAbierto),
            borderRadius: BorderRadius.circular(Tema.radio),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vocabulario (${racconto.vocabulario.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Tema.verdeOscuro,
                      ),
                    ),
                  ),
                  Icon(
                    _vocabularioAbierto
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Tema.verdeOscuro,
                  ),
                ],
              ),
            ),
          ),
          if (_vocabularioAbierto)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (final palabra in racconto.vocabulario)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              palabra.italiano,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Tema.titulo,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              palabra.espanol,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Tema.textoTenue,
                              ),
                            ),
                          ),
                        ],
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

class _Linea extends StatelessWidget {
  const _Linea({
    required this.linea,
    required this.revelada,
    required this.alTocar,
  });

  final LineaRacconto linea;
  final bool revelada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: alTocar,
      borderRadius: BorderRadius.circular(Tema.radioChico),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              linea.italiano,
              style: TextStyle(
                fontSize: 18,
                height: 1.45,
                color: Tema.texto,
                // La revelada se marca en verde: al volver a leer de corrido
                // se ve de un vistazo cuáles costaron.
                fontWeight: revelada ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (revelada) ...[
              const SizedBox(height: 3),
              Text(
                linea.espanol,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.35,
                  color: Tema.verdeOscuro,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

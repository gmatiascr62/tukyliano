import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ia/gemini.dart';
import '../tema.dart';
import '../widgets/campo_texto.dart';

/// Pide la clave de la API de Gemini la primera vez (o si la guardada dejó de
/// funcionar) y la manda a guardar en el celular. Nunca queda en el código.
///
/// No hay TextField a propósito: en la app Kivy fue lo que trajo los problemas
/// de layout con el teclado nativo. Se copia la clave en el navegador y se
/// pega desde el portapapeles con un botón.
class PantallaClaveIA extends StatefulWidget {
  const PantallaClaveIA({
    super.key,
    required this.onGuardar,
    this.error = '',
  });

  final ValueChanged<String> onGuardar;

  /// Mensaje cuando la clave guardada dejó de funcionar.
  final String error;

  @override
  State<PantallaClaveIA> createState() => _PantallaClaveIAState();
}

class _PantallaClaveIAState extends State<PantallaClaveIA> {
  String _clavePegada = '';
  String _error = '';

  Future<void> _pegar() async {
    final datos = await Clipboard.getData(Clipboard.kTextPlain);
    setState(() {
      _clavePegada = datos?.text?.trim() ?? '';
      _error = '';
    });
  }

  void _guardar() {
    if (_clavePegada.isEmpty) {
      setState(() =>
          _error = "Copiá tu clave y tocá 'Pegar clave' antes de guardar.");
      return;
    }
    widget.onGuardar(_clavePegada);
  }

  Future<void> _abrirLink() async {
    await launchUrl(
      Uri.parse(urlClaveGemini),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error.isNotEmpty ? _error : widget.error;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Tema.verdeSuave,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key_rounded, size: 34, color: Tema.verde),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Necesitás una clave gratis de la IA (Gemini)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Tema.titulo,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Tema.superficie,
              borderRadius: BorderRadius.circular(Tema.radio),
              boxShadow: Tema.sombra,
            ),
            child: _Instrucciones(onLink: _abrirLink),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            texto: _clavePegada,
            placeholderTexto: '(todavía no pegaste nada)',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _pegar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Tema.verdeSuave,
                foregroundColor: Tema.verdeOscuro,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Tema.radio),
                ),
              ),
              icon: const Icon(Icons.content_paste_rounded, size: 20),
              label: const Text(
                'Pegar clave',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(
            height: 30,
            child: Center(
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Tema.incorrecto),
              ),
            ),
          ),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _guardar,
              style: Tema.botonPrincipal,
              child: const Text(
                'Guardar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Instrucciones extends StatelessWidget {
  const _Instrucciones({required this.onLink});

  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 15, color: Tema.texto, height: 1.4);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('1. Andá a ', style: estilo),
            Flexible(
              child: InkWell(
                onTap: onLink,
                child: const Text(
                  urlClaveGemini,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: Tema.verde,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Tema.verde,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '2. Iniciá sesión con Google y creá una clave (gratis)',
          textAlign: TextAlign.center,
          style: estilo,
        ),
        const SizedBox(height: 6),
        const Text(
          '3. Copiala (botón Copiar) y volvé acá',
          textAlign: TextAlign.center,
          style: estilo,
        ),
      ],
    );
  }
}

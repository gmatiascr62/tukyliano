import 'dart:async';

import 'package:http/http.dart' as http;

import '../modelos/radio_italiana.dart';

/// A qué dirección hay que pedirle el audio en vivo de una emisora.
///
/// **Por qué no alcanza con la dirección del archivo.** Senti Chi Parla no
/// transmite desde un servidor: transmite desde una red de reparto con
/// decenas de nodos, y cuál te toca lo decide un balanceador en el momento.
/// La app tenía clavado `24293.live.streamtheworld.com`, que es *un* nodo
/// de esa red. Funciona hasta el día que ese nodo deje de servir, y ese día
/// la radio enmudece sin que nadie se entere de por qué.
///
/// Paolo Canova, el director de la radio, nos pasó la dirección correcta: la
/// del balanceador, que contesta con el nodo que corresponda en ese momento.
/// Se comprobó que rota de verdad —tres consultas seguidas dieron 26343,
/// 15113 y 24293—.
///
/// **El detalle que obliga a este código.** El balanceador contesta con un
/// 302 hacia `http://`, sin cifrar, y eso en la app no sirve: Android
/// bloquea el tráfico sin cifrar y el reproductor tampoco sigue un redirect
/// que baje de https a http. Habilitar tráfico sin cifrar sería bajarle la
/// seguridad a toda la app por una emisora.
///
/// No hace falta: los nodos **sí** hablan https; lo único que pasa es que el
/// balanceador siempre escribe `http` en su respuesta. Se probó con dos
/// nodos distintos de la rotación —26343 y 15113— pedidos por https desde un
/// celular en Argentina, y los dos suenan. Así que se lee a dónde apunta y
/// se le cambia el esquema.
///
/// **Y si algo de esto falla, no se rompe nada**: se vuelve a la dirección
/// de siempre, que es la que la app viene usando y está probada. En el peor
/// caso quedamos como estábamos.
class DondeSuenaLaRadio {
  DondeSuenaLaRadio({
    http.Client? cliente,
    this.cuantoEspera = const Duration(seconds: 6),
  }) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;

  /// Cuánto se espera al balanceador antes de tocar la dirección de siempre.
  ///
  /// Corto a propósito: esto pasa entre que la persona toca "play" y empieza
  /// a sonar. Más vale sonar por la dirección vieja que hacerla esperar.
  final Duration cuantoEspera;

  Future<String> de(RadioItaliana radio) async {
    if (radio.balanceador.isEmpty) return radio.stream;
    try {
      final donde = await _aDondeApunta(radio.balanceador)
          .timeout(cuantoEspera);
      return donde ?? radio.stream;
    } catch (_) {
      // Sin internet, el balanceador caído, un certificado vencido: no
      // importa cuál de las tres. Hay una dirección que anda.
      return radio.stream;
    }
  }

  Future<String?> _aDondeApunta(String balanceador) async {
    final pedido = http.Request('GET', Uri.parse(balanceador))
      // Sin esto el cliente sigue el redirect y empieza a bajar el audio;
      // acá solo interesa saber a dónde apunta.
      ..followRedirects = false;
    final respuesta = await _cliente.send(pedido);
    // El cuerpo hay que vaciarlo igual o la conexión queda abierta.
    unawaited(respuesta.stream.drain<void>().catchError((_) {}));

    if (respuesta.statusCode < 300 || respuesta.statusCode >= 400) return null;
    final aDonde = respuesta.headers['location'];
    if (aDonde == null || aDonde.isEmpty) return null;

    final uri = Uri.tryParse(aDonde);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme == 'https') return uri.toString();
    if (uri.scheme == 'http') return uri.replace(scheme: 'https').toString();
    return null;
  }
}

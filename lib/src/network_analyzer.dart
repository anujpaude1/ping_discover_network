/*
 * ping_discover_network
 * Created by Andrey Ushakov
 * 
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:io';

/// [NetworkAnalyzer] class returns instances of [NetworkAddress].
///
/// Found ip addresses will have [exists] == true field.
class NetworkAddress {
  NetworkAddress(this.ip, this.exists);
  bool exists;
  String ip;
}

class NetworkAnalyzer {
  // Avoid self instance
  NetworkAnalyzer._();
  static NetworkAnalyzer? _instance;
  static NetworkAnalyzer get i => _instance ??= NetworkAnalyzer._();

  Stream<NetworkAddress> discover(
    String subnet,
    int port, {
    Duration timeout = const Duration(milliseconds: 400),
  }) async* {
    if (port < 1 || port > 65535) {
      throw 'Incorrect port';
    }

    for (int i = 1; i < 256; ++i) {
      final host = '$subnet.$i';
      final url = 'ws://$host:$port';

      try {
        final WebSocket ws = await _pingWebSocket(url, timeout);
        await ws.close();
        yield NetworkAddress(host, true);
      } catch (e) {
        if (e is SocketException || e is WebSocketException) {
          yield NetworkAddress(host, false);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Pings a given [subnet] (xxx.xxx.xxx) on a given [port].
  ///
  /// Pings IP:PORT all at once
  Stream<NetworkAddress> discover2(
    String subnet,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    if (port < 1 || port > 65535) {
      throw 'Incorrect port';
    }

    final out = StreamController<NetworkAddress>();
    final futures = <Future<WebSocket>>[];
    for (int i = 1; i < 256; ++i) {
      final host = '$subnet.$i';
      final url = 'ws://$host:$port';
      final Future<WebSocket> f = _pingWebSocket(url, timeout);
      futures.add(f);
      f.then((ws) {
        ws.close();
        out.sink.add(NetworkAddress(host, true));
      }).catchError((dynamic e) {
        if (e is SocketException || e is WebSocketException) {
          out.sink.add(NetworkAddress(host, false));
        } else {
          throw e;
        }
      });
    }

    Future.wait<WebSocket>(futures)
        .then<void>((sockets) => out.close())
        .catchError((dynamic e) => out.close());

    return out.stream;
  }

  Future<WebSocket> _pingWebSocket(String url, Duration timeout) {
    return WebSocket.connect(url).timeout(timeout);
  }

  // 13: Connection failed (OS Error: Permission denied)
  // 49: Bind failed (OS Error: Can't assign requested address)
  // 61: OS Error: Connection refused
  // 64: Connection failed (OS Error: Host is down)
  // 65: No route to host
  // 101: Network is unreachable
  // 111: Connection refused
  // 113: No route to host
  // <empty>: SocketException: Connection timed out
  final _errorCodes = [13, 49, 61, 64, 65, 101, 111, 113];
}

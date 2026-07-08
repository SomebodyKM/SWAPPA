import 'package:socket_io_client/socket_io_client.dart' as io;

import 'env.dart';
import 'token_store.dart';

/// Connects to the backend Socket.IO `/realtime` namespace for live chat and
/// notifications. Authenticated with the JWT access token on connect.
class SocketClient {
  SocketClient(this._tokens);

  final TokenStore _tokens;
  io.Socket? _socket;

  io.Socket? get socket => _socket;

  /// Connects if not already connected. Safe to call repeatedly (e.g. every
  /// time the Chat tab is opened) — reuses the existing socket otherwise.
  Future<io.Socket> ensureConnected() async {
    if (_socket != null && _socket!.connected) return _socket!;
    return connect();
  }

  Future<io.Socket> connect() async {
    final token = await _tokens.accessToken;
    final socket = io.io(
      '${Env.socketOrigin}${Env.socketNamespace}',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    socket.connect();
    _socket = socket;
    return socket;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}

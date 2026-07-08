import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import 'api_client.dart';
import 'socket_client.dart';
import 'token_store.dart';

/// Secure token storage (single instance).
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Configured Dio API client with auth + refresh.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});

/// Socket.IO client for realtime chat (connected lazily on first Chat use,
/// disconnected on logout — see `AuthController`).
final socketClientProvider = Provider<SocketClient>((ref) {
  return SocketClient(ref.watch(tokenStoreProvider));
});

/// The bottom nav's selected tab index (Discover, Swaps, Chat, Wallet,
/// Profile) — a provider rather than local `State` so screens reached via a
/// pushed route (e.g. a notification) can switch tabs and pop back to it.
final appTabIndexProvider = StateProvider<int>((ref) => 0);

/// The conversation id of whichever `ChatThread` is currently open, if any —
/// set/cleared imperatively by `ChatThread` itself (a plain variable, not a
/// provider, since it must be safely settable from `dispose()` — Riverpod
/// forbids `ref.read`/`ref.watch` once a widget is being torn down). Lets a
/// foreground message notification suppress itself when you're already
/// looking at that exact thread (you can already see the message land in
/// the transcript live).
String? activeConversationId;

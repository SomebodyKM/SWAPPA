import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../auth/auth_controller.dart';
import 'conversation.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Conversation>> listConversations(String myUserId) async {
    final data = await _api.getJson('/conversations');
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>, myUserId))
        .toList();
  }

  /// Finds or creates the conversation with [targetUserId] (e.g. tapping
  /// "Message" on a Discovery card) — rejects if either side has blocked the other.
  Future<Conversation> getOrCreate(String targetUserId, String myUserId) async {
    final data = await _api.postJson(
      '/conversations',
      body: {'targetUserId': targetUserId},
    );
    return Conversation.fromJson(data as Map<String, dynamic>, myUserId);
  }

  /// Backend returns newest-first; reversed here so callers get oldest-to-newest.
  Future<List<ChatMessage>> listMessages(
    String conversationId, {
    String? cursor,
  }) async {
    final data = await _api.getJson(
      '/conversations/$conversationId/messages',
      query: cursor != null ? {'cursor': cursor} : null,
    );
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final data = await _api.postJson(
      '/conversations/$conversationId/messages',
      body: {'body': body},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  /// Edits your own text message. The backend rejects this once the edit
  /// window has expired or for non-text/already-deleted messages.
  Future<ChatMessage> editMessage(String messageId, String body) async {
    final data = await _api.patchJson(
      '/messages/$messageId',
      body: {'body': body},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  /// Soft-deletes your own message (body/media cleared, shows as "Message
  /// deleted" to both participants — not a delete-for-me).
  Future<void> deleteMessage(String messageId) =>
      _api.deleteJson('/messages/$messageId');
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's conversations, keyed to the user id so switching
/// accounts re-fetches instead of serving the previous session's list.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(const []);
  return ref.watch(chatRepositoryProvider).listConversations(userId);
});

/// Total unread messages across all conversations, for the Chat tab badge —
/// recomputes whenever [conversationsProvider] refreshes (including after a
/// realtime push from [AppShell]'s socket listener).
final unreadChatCountProvider = Provider<int>((ref) {
  final convos = ref.watch(conversationsProvider).asData?.value ?? const [];
  return convos.fold<int>(0, (sum, c) => sum + c.unreadCount);
});

/// In-memory unsent-message draft per conversation, keyed by conversation id.
/// Not `.autoDispose`, so it outlives a [ChatThread] being popped — leaving
/// the thread and coming back (this session) restores whatever was typed
/// but never sent, like WhatsApp/Telegram drafts.
final chatDraftProvider = StateProvider.family<String, String>(
  (ref, conversationId) => '',
);

/// Conversation ids swiped hidden from the Chat tab. In-memory only (like
/// [chatDraftProvider]) — cleared by [AppShell]'s socket listener the moment
/// the *other* participant sends a new message, per the "hide until they
/// message again" behavior; otherwise persists for the rest of this session.
final hiddenConversationsProvider = StateProvider<Set<String>>((ref) => {});

/// [conversationsProvider], minus anything currently hidden.
final visibleConversationsProvider = Provider<AsyncValue<List<Conversation>>>((
  ref,
) {
  final hidden = ref.watch(hiddenConversationsProvider);
  return ref
      .watch(conversationsProvider)
      .whenData((list) => list.where((c) => !hidden.contains(c.id)).toList());
});

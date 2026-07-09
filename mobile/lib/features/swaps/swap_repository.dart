import 'package:flutter_riverpod/flutter_riverpod.dart';
// StateProvider is a legacy (but supported) provider in Riverpod 3.
import 'package:flutter_riverpod/legacy.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../shared/models/skill.dart';
import '../auth/auth_controller.dart';

/// Statuses that still occupy an active-swap slot / warrant a chat banner.
const kOpenSwapStatuses = {'requested', 'active'};

/// The Swaps screen's selected sub-tab (active | pending | history) — a
/// provider so a notification tap can pick the right one before popping
/// back to [SwapsScreen] rather than always landing on "active".
final swapsTabProvider = StateProvider<String>((ref) => 'active');

/// Maps a raw backend swap status onto the Swaps-tab bucket it lives in —
/// shared by [SwapRecord.tabBucket] and anywhere else (e.g. notification
/// deep-links) that only has the bare status string, not a full record.
String swapTabBucketFor(String? status) => switch (status) {
  'requested' => 'pending',
  'active' => 'active',
  _ => 'history',
};

/// Realtime `notification` event types that mean a swap or one of its
/// sessions may have changed on the other end — used by both the chat
/// thread's swap banner and the Swaps detail screen to invalidate and
/// re-fetch instead of polling.
const kSwapRelatedNotificationTypes = {
  'swap_requested',
  'swap_status_changed',
  'swap_completed',
  'swap_finish_requested',
  'session_proposed',
  'session_responded',
  'session_completed',
  'session_finish_requested',
  'no_show_reported',
};

String _idOf(dynamic v) =>
    v is Map ? (v['_id'] ?? v['id']).toString() : v.toString();

/// A backend `Swap` document (`GET/POST /swaps`), resolved down to "the
/// other participant" the way `Conversation` resolves chat partners.
class SwapRecord {
  const SwapRecord({
    required this.id,
    required this.initiatorId,
    required this.partnerId,
    required this.offeredSkill,
    required this.requestedSkill,
    required this.status,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    required this.updatedAt,
    this.cancelReason,
    this.finishConfirmedBy = const [],
    this.abandonAllowedAt,
  });

  final String id;
  final String initiatorId;
  final String partnerId;
  final Skill offeredSkill; // what the initiator teaches
  final Skill requestedSkill; // what the initiator learns
  final String status; // requested | active | completed | cancelled | abandoned
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final DateTime updatedAt;
  final String? cancelReason;
  final List<String> finishConfirmedBy;
  final DateTime? abandonAllowedAt;

  bool isInitiator(String myUserId) => initiatorId == myUserId;
  bool get isOpen => kOpenSwapStatuses.contains(status);
  bool hasConfirmedFinish(String myUserId) =>
      finishConfirmedBy.contains(myUserId);

  /// Whether cancelling right now would require [SwapRepository.cancel] to be
  /// given a reason — free only for the initiator backing out of their own
  /// still-pending request.
  bool cancelNeedsReason(String myUserId) =>
      !(status == 'requested' && isInitiator(myUserId));

  /// True once a no-show grace window has elapsed and [SwapRepository.abandon]
  /// is actually callable — set by [SwapRepository.reportNoShow].
  bool get canAbandon =>
      status == 'active' &&
      abandonAllowedAt != null &&
      DateTime.now().isAfter(abandonAllowedAt!);

  /// Which Swaps-tab tab this belongs in.
  String get tabBucket => swapTabBucketFor(status);

  /// Maps onto the four styles `StatusBadge` knows about.
  String get badgeStatus => switch (status) {
    'requested' => 'pending',
    'abandoned' => 'cancelled',
    _ => status,
  };

  Skill myTeachSkill(String myUserId) =>
      isInitiator(myUserId) ? offeredSkill : requestedSkill;
  Skill myLearnSkill(String myUserId) =>
      isInitiator(myUserId) ? requestedSkill : offeredSkill;

  String get initials {
    final parts = otherUserName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory SwapRecord.fromJson(Map<String, dynamic> json, String myUserId) {
    final participants = ((json['participants'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => p.cast<String, dynamic>())
        .toList();
    final other = participants.firstWhere(
      (p) => (p['_id'] ?? p['id']).toString() != myUserId,
      orElse: () => participants.isNotEmpty
          ? participants.first
          : const <String, dynamic>{},
    );
    return SwapRecord(
      id: (json['_id'] ?? json['id']).toString(),
      initiatorId: _idOf(json['initiator']),
      partnerId: _idOf(json['partner']),
      offeredSkill: Skill.fromJson(
        (json['offeredSkill'] as Map).cast<String, dynamic>(),
      ),
      requestedSkill: Skill.fromJson(
        (json['requestedSkill'] as Map).cast<String, dynamic>(),
      ),
      status: (json['status'] ?? 'requested') as String,
      otherUserId: (other['_id'] ?? other['id'] ?? '').toString(),
      otherUserName: (other['displayName'] ?? 'Unknown') as String,
      otherUserPhotoUrl: other['photoUrl'] as String?,
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
      cancelReason: json['cancelReason'] as String?,
      finishConfirmedBy: ((json['finishConfirmedBy'] as List?) ?? const [])
          .map(_idOf)
          .toList(),
      abandonAllowedAt: DateTime.tryParse(
        (json['abandonAllowedAt'] ?? '').toString(),
      ),
    );
  }
}

/// A backend `Session` document — a single scheduled meetup nested under a
/// [SwapRecord] (`GET/POST /swaps/:id/sessions`, `GET/PATCH/DELETE /sessions/:id`).
class SwapSession {
  const SwapSession({
    required this.id,
    required this.swapId,
    required this.teacherId,
    required this.learnerId,
    required this.proposedById,
    required this.scheduledAt,
    required this.format,
    required this.status,
    required this.confirmedBy,
  });

  final String id;
  final String swapId;
  final String teacherId;
  final String learnerId;
  final String proposedById;
  final DateTime scheduledAt;
  final String format; // in_person | remote
  final String
  status; // proposed | accepted | declined | completed | cancelled | no_show
  final List<String> confirmedBy;

  bool isProposer(String myUserId) => proposedById == myUserId;
  bool isTeacher(String myUserId) => teacherId == myUserId;
  bool hasConfirmed(String myUserId) => confirmedBy.contains(myUserId);
  bool get isPending => status == 'proposed' || status == 'accepted';

  String get formatLabel => format == 'remote' ? 'Remote' : 'In-person';

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Compact label like "Sat 5 Jul, 10:00am".
  String get whenLabel {
    final t = scheduledAt.toLocal();
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'am' : 'pm';
    return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, $hour12:$minute$ampm';
  }

  factory SwapSession.fromJson(Map<String, dynamic> json) {
    return SwapSession(
      id: (json['_id'] ?? json['id']).toString(),
      swapId: _idOf(json['swap']),
      teacherId: _idOf(json['teacher']),
      learnerId: _idOf(json['learner']),
      proposedById: _idOf(json['proposedBy']),
      scheduledAt:
          DateTime.tryParse((json['scheduledAt'] ?? '').toString()) ??
          DateTime.now(),
      format: (json['format'] ?? 'remote') as String,
      status: (json['status'] ?? 'proposed') as String,
      confirmedBy: ((json['confirmedBy'] as List?) ?? const [])
          .map(_idOf)
          .toList(),
    );
  }
}

class SwapRepository {
  SwapRepository(this._api);
  final ApiClient _api;

  Future<List<SwapRecord>> listMine(String myUserId) async {
    final data = await _api.getJson('/swaps');
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => SwapRecord.fromJson(e as Map<String, dynamic>, myUserId))
        .toList();
  }

  Future<List<SwapRecord>> listWithPartner(
    String myUserId,
    String partnerId,
  ) async {
    final data = await _api.getJson('/swaps', query: {'partnerId': partnerId});
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => SwapRecord.fromJson(e as Map<String, dynamic>, myUserId))
        .toList();
  }

  Future<SwapRecord> getSwap(String myUserId, String id) async {
    final data = await _api.getJson('/swaps/$id');
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  Future<SwapRecord> create({
    required String myUserId,
    required String partnerId,
    required String offeredSkillId,
    required String requestedSkillId,
  }) async {
    final data = await _api.postJson(
      '/swaps',
      body: {
        'partnerId': partnerId,
        'offeredSkillId': offeredSkillId,
        'requestedSkillId': requestedSkillId,
      },
    );
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  Future<SwapRecord> accept(String myUserId, String id) async {
    final data = await _api.postJson('/swaps/$id/accept');
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  Future<SwapRecord> cancel(
    String myUserId,
    String id, {
    String? reason,
  }) async {
    final data = await _api.postJson(
      '/swaps/$id/cancel',
      body: {'reason': ?reason},
    );
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  /// Only the initiator may edit terms, and only while the swap is still
  /// `requested` — enforced server-side.
  Future<SwapRecord> edit(
    String myUserId,
    String id, {
    String? offeredSkillId,
    String? requestedSkillId,
  }) async {
    final data = await _api.patchJson(
      '/swaps/$id',
      body: {
        'offeredSkillId': ?offeredSkillId,
        'requestedSkillId': ?requestedSkillId,
      },
    );
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  /// Ends a swap after a reported no-show's grace window has elapsed — see
  /// [SwapRecord.canAbandon]. Unlike [cancel], this needs no reason: the
  /// no-show report already is one.
  Future<SwapRecord> abandon(String myUserId, String id) async {
    final data = await _api.postJson('/swaps/$id/abandon');
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  /// Mutual "mark finished" — only completes the swap once both participants
  /// have called this.
  Future<SwapRecord> confirmFinish(String myUserId, String id) async {
    final data = await _api.postJson('/swaps/$id/finish');
    return SwapRecord.fromJson(data as Map<String, dynamic>, myUserId);
  }

  /// All of the signed-in user's upcoming sessions across every swap — one
  /// call, used to preview "next session" on the Swaps list without an
  /// N+1 fetch per card.
  Future<List<SwapSession>> listUpcomingSessions() async {
    final data = await _api.getJson('/sessions', query: {'when': 'upcoming'});
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => SwapSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SwapSession>> listSessionsForSwap(String swapId) async {
    final data = await _api.getJson('/swaps/$swapId/sessions');
    final items = (data is Map ? data['items'] : null) as List? ?? const [];
    return items
        .map((e) => SwapSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SwapSession> proposeSession({
    required String swapId,
    required String teacherId,
    required String learnerId,
    required DateTime scheduledAt,
    required String format,
  }) async {
    final data = await _api.postJson(
      '/swaps/$swapId/sessions',
      body: {
        'teacherId': teacherId,
        'learnerId': learnerId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'format': format,
      },
    );
    return SwapSession.fromJson(data as Map<String, dynamic>);
  }

  Future<SwapSession> respondSession(String sessionId, String decision) async {
    final data = await _api.postJson(
      '/sessions/$sessionId/respond',
      body: {'decision': decision},
    );
    return SwapSession.fromJson(data as Map<String, dynamic>);
  }

  Future<SwapSession> confirmCompleteSession(String sessionId) async {
    final data = await _api.postJson('/sessions/$sessionId/confirm-complete');
    return SwapSession.fromJson(data as Map<String, dynamic>);
  }

  Future<SwapSession> cancelSession(String sessionId) async {
    final data = await _api.deleteJson('/sessions/$sessionId');
    return SwapSession.fromJson(data as Map<String, dynamic>);
  }

  /// Reports that the other party didn't show for a past-due session —
  /// starts the swap's abandon grace window (see [SwapRecord.canAbandon]).
  Future<SwapSession> reportNoShow(String sessionId) async {
    final data = await _api.postJson('/sessions/$sessionId/no-show');
    return SwapSession.fromJson(data as Map<String, dynamic>);
  }
}

final swapRepositoryProvider = Provider<SwapRepository>(
  (ref) => SwapRepository(ref.watch(apiClientProvider)),
);

/// The open (requested/active) swap between the signed-in user and [partnerId],
/// if any — drives the "ongoing swap" banner in a chat thread. `null` when
/// there's no open swap (a completed/cancelled one, if any, is ignored here).
final openSwapWithPartnerProvider = FutureProvider.family<SwapRecord?, String>((
  ref,
  partnerId,
) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return null;
  final swaps = await ref
      .watch(swapRepositoryProvider)
      .listWithPartner(userId, partnerId);
  for (final s in swaps) {
    if (s.isOpen) return s;
  }
  return null;
});

/// All of the signed-in user's swaps, for the Swaps tab.
final mySwapsProvider = FutureProvider<List<SwapRecord>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(const []);
  return ref.watch(swapRepositoryProvider).listMine(userId);
});

/// Bulk upcoming-sessions fetch backing the Swaps list's "next session" preview.
final upcomingSessionsProvider = FutureProvider<List<SwapSession>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(const []);
  return ref.watch(swapRepositoryProvider).listUpcomingSessions();
});

/// A single swap, re-fetched fresh (not from the list cache) for the detail screen.
final swapByIdProvider = FutureProvider.family<SwapRecord, String>((
  ref,
  swapId,
) {
  final userId =
      ref.watch(authControllerProvider.select((s) => s.user?.id)) ?? '';
  return ref.watch(swapRepositoryProvider).getSwap(userId, swapId);
});

/// The full session history for one swap, for the detail screen.
final swapSessionsProvider = FutureProvider.family<List<SwapSession>, String>((
  ref,
  swapId,
) {
  return ref.watch(swapRepositoryProvider).listSessionsForSwap(swapId);
});

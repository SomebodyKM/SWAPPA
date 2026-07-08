import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../shared/models/skill.dart';
import '../auth/auth_controller.dart';
import 'models/public_profile.dart';
import 'models/review.dart';

class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;

  Future<List<Skill>> skillsCatalog({String? query}) async {
    final data = await _api.getJson(
      '/skills',
      query: query == null || query.isEmpty
          ? {'all': 'true'}
          : {'query': query},
    );
    return _items(data).map((e) => Skill.fromJson(e)).toList();
  }

  /// Proposes a skill not already in the catalog — always lands `pending`
  /// for admin review (never directly usable by anyone else) unless a skill
  /// with that name already exists, in which case that one is returned.
  Future<Skill> proposeSkill({
    required String name,
    required String category,
  }) async {
    final data = await _api.postJson(
      '/skills',
      body: {'name': name, 'category': category},
    );
    return Skill.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SkillTag>> myTags() async {
    final data = await _api.getJson('/users/me/tags');
    return _items(data).map((e) => SkillTag.fromJson(e)).toList();
  }

  Future<List<SkillTag>> userTags(String userId) async {
    final data = await _api.getJson('/users/$userId/tags');
    return _items(data).map((e) => SkillTag.fromJson(e)).toList();
  }

  Future<void> addTag({
    required String skillId,
    required String kind,
    String? proficiency,
  }) async {
    await _api.postJson(
      '/users/me/tags',
      body: {'skillId': skillId, 'kind': kind, 'proficiency': ?proficiency},
    );
  }

  Future<void> removeTag(String tagId) =>
      _api.deleteJson('/users/me/tags/$tagId');

  Future<void> updateTagProficiency(String tagId, String proficiency) => _api
      .patchJson('/users/me/tags/$tagId', body: {'proficiency': proficiency});

  Future<List<Review>> reviews(String userId) async {
    final data = await _api.getJson('/users/$userId/reviews');
    return _items(data).map((e) => Review.fromJson(e)).toList();
  }

  /// The signed-in user's own review of [swapId], or null if they haven't
  /// left one yet.
  Future<MyReview?> myReviewForSwap(String swapId) async {
    final data = await _api.getJson('/swaps/$swapId/review') as Map;
    final review = data['review'];
    return review is Map<String, dynamic> ? MyReview.fromJson(review) : null;
  }

  Future<MyReview> createReview(
    String swapId, {
    required int rating,
    String? comment,
  }) async {
    final data = await _api.postJson(
      '/swaps/$swapId/review',
      body: {'rating': rating, 'comment': ?comment},
    );
    return MyReview.fromJson(data as Map<String, dynamic>);
  }

  Future<MyReview> editReview(
    String reviewId, {
    required int rating,
    String? comment,
  }) async {
    final data = await _api.patchJson(
      '/reviews/$reviewId',
      body: {'rating': rating, 'comment': ?comment},
    );
    return MyReview.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteReview(String reviewId) =>
      _api.deleteJson('/reviews/$reviewId');

  Future<PublicProfile> getUser(String userId) async {
    final data = await _api.getJson('/users/$userId');
    return PublicProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? photoUrl,
    String? phone,
  }) async {
    await _api.patchJson(
      '/users/me',
      body: {
        'displayName': ?displayName,
        'bio': ?bio,
        'photoUrl': ?photoUrl,
        'phone': ?phone,
      },
    );
  }

  /// Changes the account email; the new address is unverified until the code
  /// sent to it is confirmed (reuse `AuthController.verifyEmail`/`resendCode`).
  Future<void> updateEmail(String email) =>
      _api.patchJson('/users/me/email', body: {'email': email});

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.patchJson(
    '/users/me/password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  /// Uploads [file] straight to Cloudinary using a short-lived signature from
  /// the API (`POST /media/sign`), then returns the resulting secure URL.
  /// The API never sees the image bytes; it only signs the upload.
  Future<String> uploadAvatar(File file) async {
    final signed =
        await _api.postJson('/media/sign', body: {'purpose': 'avatar'}) as Map;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'api_key': signed['apiKey'].toString(),
      'timestamp': signed['timestamp'].toString(),
      'signature': signed['signature'].toString(),
      'folder': signed['folder'].toString(),
    });
    final res = await Dio().post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/${signed['cloudName']}/image/upload',
      data: form,
    );
    return res.data!['secure_url'] as String;
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    final list = (data is Map ? data['items'] : data) as List? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);

/// Full skills catalog (cached for the session), for pickers + name resolution.
final skillsCatalogProvider = FutureProvider<List<Skill>>((ref) {
  return ref.watch(profileRepositoryProvider).skillsCatalog();
});

/// The signed-in user's skill tags. Keyed to the user id so switching accounts
/// (login / logout / delete + re-register) re-fetches instead of serving the
/// previous session's cached tags.
final myTagsProvider = FutureProvider<List<SkillTag>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(const []);
  return ref.watch(profileRepositoryProvider).myTags();
});

/// Another user's public skill tags (e.g. to pick what they teach when
/// proposing a swap from a chat thread).
final userTagsProvider = FutureProvider.family<List<SkillTag>, String>((
  ref,
  userId,
) {
  return ref.watch(profileRepositoryProvider).userTags(userId);
});

/// Reviews for the signed-in user (also keyed to the user id).
final myReviewsProvider = FutureProvider<List<Review>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return Future.value(const []);
  return ref.watch(profileRepositoryProvider).reviews(userId);
});

/// Reviews for an arbitrary user — e.g. the Discovery profile popup.
final userReviewsProvider = FutureProvider.family<List<Review>, String>((
  ref,
  userId,
) {
  return ref.watch(profileRepositoryProvider).reviews(userId);
});

/// The signed-in user's own review of a given swap, if any — lets the swap
/// detail screen show "leave a review" vs "edit your review".
final myReviewForSwapProvider = FutureProvider.family<MyReview?, String>((
  ref,
  swapId,
) {
  return ref.watch(profileRepositoryProvider).myReviewForSwap(swapId);
});

/// Another user's public profile (`GET /users/:id`) — for the Discovery
/// profile popup.
final publicProfileProvider = FutureProvider.family<PublicProfile, String>((
  ref,
  userId,
) {
  return ref.watch(profileRepositoryProvider).getUser(userId);
});

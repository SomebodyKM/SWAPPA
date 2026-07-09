import '../../discovery/match.dart';

/// Another user's public-facing profile (`GET /users/:id`) — deliberately a
/// much smaller shape than the signed-in user's own `User` model, since the
/// backend only ever returns public-safe fields for someone else (no email,
/// phone, credits, role, etc).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.bio,
    required this.tier,
    required this.ratingAvg,
    required this.ratingCount,
    this.location = MatchLocation.none,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final String tier; // 'free' | 'premium'
  final double ratingAvg;
  final int ratingCount;
  final MatchLocation location;

  bool get isPremium => tier == 'premium';

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      id: (json['_id'] ?? json['id']).toString(),
      displayName: (json['displayName'] ?? 'Unknown') as String,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      tier: (json['tier'] ?? 'free') as String,
      ratingAvg: ((json['ratingAvg'] ?? 0) as num).toDouble(),
      ratingCount: (json['ratingCount'] ?? 0) as int,
      location: MatchLocation.fromJson(
        json['location'] as Map<String, dynamic>?,
      ),
    );
  }
}

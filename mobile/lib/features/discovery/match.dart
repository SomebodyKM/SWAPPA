/// A discovery match result. Mirrors the backend `MatchResult`
/// (`GET /api/v1/matches`). Skill *names* are resolved separately from the
/// skills catalog since the API returns skill ids.
class MatchResult {
  MatchResult({
    required this.candidateId,
    required this.displayName,
    this.photoUrl,
    required this.ratingAvg,
    required this.sharedSkillIds,
    required this.mutual,
    this.distanceMeters,
    this.teaches,
    this.wants,
    this.reviewCount,
  });

  final String candidateId;
  final String displayName;
  final String? photoUrl;
  final double ratingAvg;
  final List<String> sharedSkillIds;
  final bool mutual;
  final int? distanceMeters;

  /// Resolved display names (from the skills catalog / sample data).
  final String? teaches;
  final String? wants;
  final int? reviewCount;

  bool get isRemote => distanceMeters == null;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get distanceLabel {
    final d = distanceMeters;
    if (d == null) return 'Remote';
    if (d < 1000) return '$d m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  factory MatchResult.fromJson(Map<String, dynamic> json, {Map<String, String>? skillNames}) {
    final ids = ((json['sharedSkillIds'] as List?) ?? const []).map((e) => e.toString()).toList();
    String? firstName;
    if (ids.isNotEmpty && skillNames != null) firstName = skillNames[ids.first];
    return MatchResult(
      candidateId: (json['candidateId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Unknown') as String,
      photoUrl: json['photoUrl'] as String?,
      ratingAvg: ((json['ratingAvg'] ?? 0) as num).toDouble(),
      sharedSkillIds: ids,
      mutual: (json['mutual'] ?? false) as bool,
      distanceMeters: (json['distanceMeters'] as num?)?.round(),
      teaches: firstName,
    );
  }
}

/// Sample matches used for design preview before auth/live data is wired.
/// (Not the export's mock data — a minimal local placeholder.)
const List<Map<String, dynamic>> kSampleMatches = [
  // ── Local ──────────────────────────────────────────────────────────────
  {
    'candidateId': '1', 'displayName': 'Maya Chen', 'ratingAvg': 4.8, 'reviews': 23,
    'teaches': 'Mandarin Chinese', 'wants': 'Guitar', 'mutual': true, 'distanceMeters': 1200,
  },
  {
    'candidateId': '3', 'displayName': 'Priya Sharma', 'ratingAvg': 4.7, 'reviews': 18,
    'teaches': 'Watercolour', 'wants': 'Yoga', 'mutual': true, 'distanceMeters': 3400,
  },
  {
    'candidateId': '5', 'displayName': 'Sia Kowalski', 'ratingAvg': 4.6, 'reviews': 31,
    'teaches': 'Knitting', 'wants': 'Baking', 'mutual': false, 'distanceMeters': 800,
  },
  {
    'candidateId': '6', 'displayName': 'Tom Becker', 'ratingAvg': 4.5, 'reviews': 12,
    'teaches': 'Photography', 'wants': 'Guitar', 'mutual': false, 'distanceMeters': 2100,
  },
  {
    'candidateId': '7', 'displayName': 'Ana García', 'ratingAvg': 4.9, 'reviews': 27,
    'teaches': 'Spanish', 'wants': 'Baking', 'mutual': true, 'distanceMeters': 600,
  },
  // ── Remote ─────────────────────────────────────────────────────────────
  {
    'candidateId': '2', 'displayName': 'Luca Romano', 'ratingAvg': 4.9, 'reviews': 41,
    'teaches': 'Italian Cooking', 'wants': 'Photography', 'mutual': false, 'distanceMeters': null,
  },
  {
    'candidateId': '4', 'displayName': 'James Okafor', 'ratingAvg': 5.0, 'reviews': 9,
    'teaches': 'Web Development', 'wants': 'Spanish', 'mutual': false, 'distanceMeters': null,
  },
  {
    'candidateId': '8', 'displayName': 'Kenji Tanaka', 'ratingAvg': 4.8, 'reviews': 15,
    'teaches': 'Japanese', 'wants': 'Web Development', 'mutual': true, 'distanceMeters': null,
  },
  {
    'candidateId': '9', 'displayName': 'Nina Petrova', 'ratingAvg': 4.7, 'reviews': 22,
    'teaches': 'Ballet', 'wants': 'French', 'mutual': false, 'distanceMeters': null,
  },
  {
    'candidateId': '10', 'displayName': 'Omar Haddad', 'ratingAvg': 4.6, 'reviews': 8,
    'teaches': 'Arabic', 'wants': 'Photography', 'mutual': false, 'distanceMeters': null,
  },
];

List<MatchResult> sampleMatches() => kSampleMatches
    .map((m) => MatchResult(
          candidateId: m['candidateId'] as String,
          displayName: m['displayName'] as String,
          ratingAvg: (m['ratingAvg'] as num).toDouble(),
          reviewCount: m['reviews'] as int?,
          sharedSkillIds: const [],
          mutual: m['mutual'] as bool,
          distanceMeters: m['distanceMeters'] as int?,
          teaches: m['teaches'] as String?,
          wants: m['wants'] as String?,
        ))
    .toList();

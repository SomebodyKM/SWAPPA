import 'dart:math' as math;

/// Free/premium-aware location info for a match candidate — mirrors the
/// backend's `serializeUserLocation` output exactly. Free viewers get a
/// fuzzed `point` and a bucketed `distanceLabel`; premium viewers get the
/// exact stored (still only ~1.1km-precise) point and an exact `distanceKm`.
class MatchLocation {
  const MatchLocation({
    this.displayName,
    this.point,
    this.distanceKm,
    this.distanceLabel,
  });

  final String? displayName;
  final List<double>? point; // [lng, lat]
  final double? distanceKm; // premium only
  final String? distanceLabel;

  static const none = MatchLocation();

  factory MatchLocation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    final pointJson = json['point'] as List?;
    return MatchLocation(
      displayName: json['displayName'] as String?,
      point: pointJson?.map((e) => (e as num).toDouble()).toList(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      distanceLabel: json['distanceLabel'] as String?,
    );
  }
}

/// A discovery match result. Mirrors the backend `MatchResult`
/// (`GET /api/v1/matches`) — `teaches`/`wants` are display names the backend
/// already resolves server-side.
class MatchResult {
  MatchResult({
    required this.candidateId,
    required this.displayName,
    this.photoUrl,
    required this.ratingAvg,
    required this.sharedSkillIds,
    required this.mutual,
    this.location = MatchLocation.none,
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
  final MatchLocation location;

  /// Display names for a skill the candidate teaches / wants to learn.
  final String? teaches;
  final String? wants;
  final int? reviewCount;

  /// No stored location for this candidate at all (as opposed to "local but
  /// distance unknown", which still carries a fuzzed/exact `point`).
  bool get isRemote => location.point == null;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get distanceLabel => location.distanceLabel ?? 'Remote';

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    final ids = ((json['sharedSkillIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return MatchResult(
      candidateId: (json['candidateId'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Unknown') as String,
      photoUrl: json['photoUrl'] as String?,
      ratingAvg: ((json['ratingAvg'] ?? 0) as num).toDouble(),
      sharedSkillIds: ids,
      mutual: (json['mutual'] ?? false) as bool,
      location: MatchLocation.fromJson(
        json['location'] as Map<String, dynamic>?,
      ),
      teaches: json['teachesName'] as String?,
      wants: json['wantsName'] as String?,
    );
  }
}

/// A non-identifying preview of a match hidden behind the free-tier cap
/// (`GET /matches`'s `teasers`) — no candidate id, name, or photo, just
/// enough to show "someone teaches X, 3km away" without revealing who.
class MatchTeaser {
  const MatchTeaser({
    this.teachesName,
    this.wantsName,
    this.distanceLabel,
    required this.mutual,
  });

  final String? teachesName;
  final String? wantsName;
  final String? distanceLabel;
  final bool mutual;

  factory MatchTeaser.fromJson(Map<String, dynamic> json) => MatchTeaser(
    teachesName: json['teachesName'] as String?,
    wantsName: json['wantsName'] as String?,
    distanceLabel: json['distanceLabel'] as String?,
    mutual: (json['mutual'] ?? false) as bool,
  );
}

/// Sample matches used for design preview before auth/live data is wired.
/// (Not the export's mock data — a minimal local placeholder.)
const List<Map<String, dynamic>> kSampleMatches = [
  // ── Local ──────────────────────────────────────────────────────────────
  {
    'candidateId': '1',
    'displayName': 'Maya Chen',
    'ratingAvg': 4.8,
    'reviews': 23,
    'teaches': 'Mandarin Chinese',
    'wants': 'Guitar',
    'mutual': true,
    'distanceMeters': 1200,
  },
  {
    'candidateId': '3',
    'displayName': 'Priya Sharma',
    'ratingAvg': 4.7,
    'reviews': 18,
    'teaches': 'Watercolour',
    'wants': 'Yoga',
    'mutual': true,
    'distanceMeters': 3400,
  },
  {
    'candidateId': '5',
    'displayName': 'Sia Kowalski',
    'ratingAvg': 4.6,
    'reviews': 31,
    'teaches': 'Knitting',
    'wants': 'Baking',
    'mutual': false,
    'distanceMeters': 800,
  },
  {
    'candidateId': '6',
    'displayName': 'Tom Becker',
    'ratingAvg': 4.5,
    'reviews': 12,
    'teaches': 'Photography',
    'wants': 'Guitar',
    'mutual': false,
    'distanceMeters': 2100,
  },
  {
    'candidateId': '7',
    'displayName': 'Ana García',
    'ratingAvg': 4.9,
    'reviews': 27,
    'teaches': 'Spanish',
    'wants': 'Baking',
    'mutual': true,
    'distanceMeters': 600,
  },
  // ── Remote ─────────────────────────────────────────────────────────────
  {
    'candidateId': '2',
    'displayName': 'Luca Romano',
    'ratingAvg': 4.9,
    'reviews': 41,
    'teaches': 'Italian Cooking',
    'wants': 'Photography',
    'mutual': false,
    'distanceMeters': null,
  },
  {
    'candidateId': '4',
    'displayName': 'James Okafor',
    'ratingAvg': 5.0,
    'reviews': 9,
    'teaches': 'Web Development',
    'wants': 'Spanish',
    'mutual': false,
    'distanceMeters': null,
  },
  {
    'candidateId': '8',
    'displayName': 'Kenji Tanaka',
    'ratingAvg': 4.8,
    'reviews': 15,
    'teaches': 'Japanese',
    'wants': 'Web Development',
    'mutual': true,
    'distanceMeters': null,
  },
  {
    'candidateId': '9',
    'displayName': 'Nina Petrova',
    'ratingAvg': 4.7,
    'reviews': 22,
    'teaches': 'Ballet',
    'wants': 'French',
    'mutual': false,
    'distanceMeters': null,
  },
  {
    'candidateId': '10',
    'displayName': 'Omar Haddad',
    'ratingAvg': 4.6,
    'reviews': 8,
    'teaches': 'Arabic',
    'wants': 'Photography',
    'mutual': false,
    'distanceMeters': null,
  },
];

/// Sample-data-only demo center (central London) and per-entry bearings, used
/// to scatter "local" sample pins around a point for the map view — purely
/// cosmetic for design preview, not derived from anything real.
const _sampleCenter = [-0.1276, 51.5072];
const _sampleBearingsDeg = [15.0, 95.0, 170.0, 240.0, 300.0];

/// Offsets [center] by [meters] along [bearingDeg] — approximate, fine for
/// scattering design-preview pins, not for real geo work.
List<double> _offsetPoint(
  List<double> center,
  double meters,
  double bearingDeg,
) {
  const kmPerDegreeLat = 111.32;
  final km = meters / 1000;
  final bearingRad = bearingDeg * (math.pi / 180);
  final dLat = (km / kmPerDegreeLat) * math.cos(bearingRad);
  final kmPerDegreeLng = kmPerDegreeLat * math.cos(center[1] * math.pi / 180);
  final dLng = kmPerDegreeLng > 0
      ? (km / kmPerDegreeLng) * math.sin(bearingRad)
      : 0.0;
  return [center[0] + dLng, center[1] + dLat];
}

/// Sample data predates real coordinates, so "local" samples are scattered
/// around a fixed demo center with an exact — rather than bucketed —
/// distance label, since fake data has no privacy story to preserve.
List<MatchResult> sampleMatches() {
  var localIndex = 0;
  return kSampleMatches.map((m) {
    final distanceMeters = m['distanceMeters'] as int?;
    MatchLocation location = MatchLocation.none;
    if (distanceMeters != null) {
      final bearing =
          _sampleBearingsDeg[localIndex % _sampleBearingsDeg.length];
      localIndex++;
      location = MatchLocation(
        point: _offsetPoint(_sampleCenter, distanceMeters.toDouble(), bearing),
        distanceLabel: distanceMeters < 1000
            ? '$distanceMeters m'
            : '${(distanceMeters / 1000).toStringAsFixed(1)} km',
      );
    }
    return MatchResult(
      candidateId: m['candidateId'] as String,
      displayName: m['displayName'] as String,
      ratingAvg: (m['ratingAvg'] as num).toDouble(),
      reviewCount: m['reviews'] as int?,
      sharedSkillIds: const [],
      mutual: m['mutual'] as bool,
      location: location,
      teaches: m['teaches'] as String?,
      wants: m['wants'] as String?,
    );
  }).toList();
}

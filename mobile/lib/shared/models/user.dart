class Credits {
  Credits({
    required this.basicBalance,
    required this.basicCap,
    required this.boostBalance,
  });

  final int basicBalance;
  final int basicCap;
  final int boostBalance;

  int get total => basicBalance + boostBalance;

  factory Credits.fromJson(Map<String, dynamic> json) {
    final basic = (json['basic'] as Map?) ?? const {};
    final boost = (json['boost'] as Map?) ?? const {};
    return Credits(
      basicBalance: (basic['balance'] ?? 0) as int,
      basicCap: (basic['cap'] ?? 0) as int,
      boostBalance: (boost['balance'] ?? 0) as int,
    );
  }

  static Credits empty() =>
      Credits(basicBalance: 0, basicCap: 0, boostBalance: 0);
}

/// The signed-in user's own location, as stored (never fuzzed — that only
/// happens when *other* users view it, via the backend's location
/// serializer). Parses the raw `location` subdocument shape from
/// `GET/PATCH /users/me*`, which differs from [MatchLocation] (the flattened
/// serializer output used for other users' locations in Discovery).
class UserLocationInfo {
  const UserLocationInfo({this.displayName, this.point});

  final String? displayName;
  final List<double>? point; // [lng, lat]

  bool get isSet => displayName != null;

  static const none = UserLocationInfo();

  factory UserLocationInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return none;
    final coords = (json['point'] as Map?)?['coordinates'] as List?;
    return UserLocationInfo(
      displayName: json['displayName'] as String?,
      point: coords?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

class User {
  User({
    required this.id,
    this.email,
    this.phone,
    required this.emailVerified,
    required this.displayName,
    this.photoUrl,
    this.bio,
    required this.tier,
    required this.role,
    required this.ratingAvg,
    required this.ratingCount,
    required this.credits,
    required this.onboardingComplete,
    this.location = UserLocationInfo.none,
  });

  final String id;
  final String? email;
  final String? phone;
  final bool emailVerified;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final String tier; // 'free' | 'premium'
  final String role; // 'user' | 'admin'
  final double ratingAvg;
  final int ratingCount;
  final Credits credits;
  final bool onboardingComplete;
  final UserLocationInfo location;

  bool get isPremium => tier == 'premium';
  bool get isAdmin => role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id']).toString(),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      emailVerified: (json['emailVerified'] ?? false) as bool,
      displayName: (json['displayName'] ?? '') as String,
      photoUrl: json['photoUrl'] as String?,
      bio: json['bio'] as String?,
      tier: (json['tier'] ?? 'free') as String,
      role: (json['role'] ?? 'user') as String,
      ratingAvg: ((json['ratingAvg'] ?? 0) as num).toDouble(),
      ratingCount: (json['ratingCount'] ?? 0) as int,
      credits: json['credits'] is Map
          ? Credits.fromJson(json['credits'] as Map<String, dynamic>)
          : Credits.empty(),
      onboardingComplete: (json['onboardingComplete'] ?? false) as bool,
      location: UserLocationInfo.fromJson(
        json['location'] as Map<String, dynamic>?,
      ),
    );
  }
}

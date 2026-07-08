/// A catalog skill (`GET /skills`).
class Skill {
  const Skill({required this.id, required this.name, required this.category});

  final String id;
  final String name;
  final String category;

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: (json['_id'] ?? json['id']).toString(),
      name: (json['name'] ?? '') as String,
      category: (json['category'] ?? '') as String,
    );
  }
}

/// Groups skills by category, sorted alphabetically by category (skills
/// within each group keep their incoming order, i.e. alphabetical by name).
Map<String, List<Skill>> groupSkillsByCategory(List<Skill> skills) {
  final byCategory = <String, List<Skill>>{};
  for (final s in skills) {
    byCategory.putIfAbsent(s.category, () => []).add(s);
  }
  final sortedKeys = byCategory.keys.toList()..sort();
  return {for (final k in sortedKeys) k: byCategory[k]!};
}

/// A user's skill tag — an offer (teach) or want (learn) linked to a [Skill]
/// (`GET /users/:id/tags`; skill is populated).
class SkillTag {
  const SkillTag({
    required this.id,
    required this.skill,
    required this.kind,
    this.proficiency,
  });

  final String id;
  final Skill skill;
  final String kind; // 'offer' | 'want'
  final String? proficiency;

  bool get isOffer => kind == 'offer';

  factory SkillTag.fromJson(Map<String, dynamic> json) {
    final skillJson = json['skill'];
    return SkillTag(
      id: (json['_id'] ?? json['id']).toString(),
      skill: skillJson is Map<String, dynamic>
          ? Skill.fromJson(skillJson)
          : Skill(id: skillJson.toString(), name: '', category: ''),
      kind: (json['kind'] ?? 'want') as String,
      proficiency: json['proficiency'] as String?,
    );
  }
}

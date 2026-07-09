import 'package:flutter/material.dart';

import '../ai/ai_repository.dart';

class AiActionInfo {
  const AiActionInfo({
    required this.icon,
    required this.label,
    required this.cost,
    required this.desc,
  });
  final IconData icon;
  final String label;
  final int cost;
  final String desc;
}

/// Costs mirror [AiCosts] (itself a mirror of the backend's `AI_ACTION_COST`)
/// so this list can never silently drift from what actions actually charge.
const List<AiActionInfo> aiActions = [
  AiActionInfo(
    icon: Icons.auto_awesome_rounded,
    label: 'Icebreaker',
    cost: AiCosts.icebreaker,
    desc: 'Start a warm, personalised conversation',
  ),
  AiActionInfo(
    icon: Icons.trending_up_rounded,
    label: 'Insight Report',
    cost: AiCosts.insight,
    desc: 'Skill demand & market analysis',
  ),
  AiActionInfo(
    icon: Icons.refresh_rounded,
    label: 'Deep Re-Match',
    cost: AiCosts.rematch,
    desc: 'Broader search, AI-ranked results',
  ),
  AiActionInfo(
    icon: Icons.shield_rounded,
    label: 'Profile Optimizer',
    cost: AiCosts.profileOptimizer,
    desc: 'Improve your profile to attract more matches',
  ),
];

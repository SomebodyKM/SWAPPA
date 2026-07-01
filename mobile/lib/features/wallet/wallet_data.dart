import 'package:flutter/material.dart';

class Txn {
  const Txn({
    required this.id,
    required this.label,
    required this.amount,
    required this.date,
    required this.basic,
  });
  final String id;
  final String label;
  final int amount; // + credit, - debit
  final String date;
  final bool basic; // Basic vs Boost
}

const List<Txn> sampleTxns = [
  Txn(id: '1', label: 'Welcome bonus', amount: 10, date: '30 Jun', basic: true),
  Txn(id: '2', label: 'AI Icebreaker → Maya Chen', amount: -2, date: '30 Jun', basic: true),
  Txn(id: '3', label: 'Deep Re-Match', amount: -3, date: '29 Jun', basic: true),
  Txn(id: '4', label: 'Weekly Basic refill', amount: 15, date: '23 Jun', basic: true),
  Txn(id: '5', label: 'Boost Pack — Small (×10)', amount: 10, date: '20 Jun', basic: false),
  Txn(id: '6', label: 'Insight Report', amount: -5, date: '18 Jun', basic: false),
];

class AiActionInfo {
  const AiActionInfo({required this.icon, required this.label, required this.cost, required this.desc});
  final IconData icon;
  final String label;
  final int cost;
  final String desc;
}

const List<AiActionInfo> aiActions = [
  AiActionInfo(icon: Icons.auto_awesome_rounded, label: 'Icebreaker', cost: 2, desc: 'Start a warm, personalised conversation'),
  AiActionInfo(icon: Icons.trending_up_rounded, label: 'Insight Report', cost: 5, desc: 'Skill demand & market analysis'),
  AiActionInfo(icon: Icons.refresh_rounded, label: 'Deep Re-Match', cost: 3, desc: 'Broader search, AI-ranked results'),
  AiActionInfo(icon: Icons.shield_rounded, label: 'Profile Optimizer', cost: 4, desc: 'Improve your profile to attract more matches'),
];

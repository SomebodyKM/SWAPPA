/// A swap between the current user and a partner (UI model + sample data).
class Swap {
  const Swap({
    required this.id,
    required this.partner,
    required this.mine,
    required this.theirs,
    required this.status,
    required this.sessions,
    this.next,
    required this.format,
  });

  final String id;
  final String partner;
  final String mine; // what I teach
  final String theirs; // what I learn
  final String status; // active | pending | completed | cancelled
  final int sessions;
  final String? next; // next session label, null if none
  final String format; // In-person | Remote

  String get initials {
    final parts = partner.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 2).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

const List<Swap> sampleSwaps = [
  Swap(
    id: '1', partner: 'Maya Chen', mine: 'Guitar', theirs: 'Mandarin Chinese',
    status: 'active', sessions: 3, next: 'Sat 5 Jul, 10:00am', format: 'In-person',
  ),
  Swap(
    id: '2', partner: 'Priya Sharma', mine: 'Yoga', theirs: 'Watercolour',
    status: 'active', sessions: 1, next: 'Wed 2 Jul, 6:00pm', format: 'Remote',
  ),
  Swap(
    id: '3', partner: 'Luca Romano', mine: 'Photography', theirs: 'Italian Cooking',
    status: 'completed', sessions: 6, next: null, format: 'Remote',
  ),
  Swap(
    id: '4', partner: 'Jamie Park', mine: 'Guitar', theirs: 'Korean',
    status: 'cancelled', sessions: 2, next: null, format: 'Remote',
  ),
  Swap(
    id: '5', partner: 'Kenji Tanaka', mine: 'Web Development', theirs: 'Japanese',
    status: 'pending', sessions: 0, next: 'Proposed: Fri 4 Jul, 2:00pm', format: 'Remote',
  ),
];

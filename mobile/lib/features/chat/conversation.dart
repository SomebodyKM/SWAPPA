class ChatMessage {
  const ChatMessage({required this.fromMe, required this.text, required this.time});
  final bool fromMe;
  final String text;
  final String time;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.name,
    required this.last,
    required this.time,
    required this.unread,
    required this.messages,
  });

  final String id;
  final String name;
  final String last;
  final String time; // "2m", "1h", "3d"
  final int unread;
  final List<ChatMessage> messages;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 2).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

const List<Conversation> sampleConversations = [
  Conversation(
    id: '1', name: 'Maya Chen', last: "How about Saturday morning? I'm free from 9am",
    time: '2m', unread: 2,
    messages: [
      ChatMessage(fromMe: false, text: 'Hi! I saw you want to learn Mandarin — that sounds like a perfect swap! ✨', time: 'Yesterday'),
      ChatMessage(fromMe: true, text: "Amazing! I've been playing guitar for 3 years and would love to help a beginner.", time: 'Yesterday'),
      ChatMessage(fromMe: false, text: 'Want to set up our first session?', time: 'Today'),
      ChatMessage(fromMe: false, text: "How about Saturday morning? I'm free from 9am", time: '2m'),
    ],
  ),
  Conversation(
    id: '2', name: 'Priya Sharma', last: 'The watercolour set I recommended is on sale!',
    time: '1h', unread: 0,
    messages: [
      ChatMessage(fromMe: false, text: 'Welcome to our swap! So excited to teach you watercolour 🎨', time: 'Mon'),
      ChatMessage(fromMe: true, text: 'Me too! Just ordered some supplies.', time: 'Mon'),
      ChatMessage(fromMe: false, text: 'The watercolour set I recommended is on sale!', time: '1h'),
    ],
  ),
  Conversation(
    id: '3', name: 'Luca Romano', last: 'Was great swapping! Cacio e pepe forever 🍝',
    time: '3d', unread: 0,
    messages: [
      ChatMessage(fromMe: false, text: 'Was great swapping with you! Cacio e pepe forever 🍝', time: '3d'),
      ChatMessage(fromMe: true, text: 'Thank you so much — I finally nailed the emulsification!', time: '3d'),
    ],
  ),
];

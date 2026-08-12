class ChatMessage {
  final String role; // "user", "model", or "system" (for error notices)
  final String text;
  ChatMessage({required this.role, required this.text});

  Map<String, dynamic> toMap() => {'role': role, 'text': text};
  static ChatMessage fromMap(Map<String, dynamic> m) =>
      ChatMessage(role: m['role'] as String, text: m['text'] as String);
}

class Conversation {
  final String id;
  String title;
  String? category;
  List<ChatMessage> messages;
  int updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.category,
    required this.messages,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'messages': messages.map((m) => m.toMap()).toList(),
        'updatedAt': updatedAt,
      };

  static Conversation fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        title: j['title'] as String,
        category: j['category'] as String?,
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
            .toList(),
        updatedAt: j['updatedAt'] as int,
      );
}
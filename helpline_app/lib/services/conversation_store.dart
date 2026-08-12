import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String role;
  final String text;
  ChatMessage({required this.role, required this.text});

  Map<String, String> toMap() => {'role': role, 'text': text};
  static ChatMessage fromMap(Map<String, dynamic> m) =>
      ChatMessage(role: m['role'], text: m['text']);
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
        'title': title,
        'category': category,
        'messages': messages.map((m) => m.toMap()).toList(),
        'updatedAt': updatedAt,
      };

  static Conversation fromJson(String id, Map<String, dynamic> j) =>
      Conversation(
        id: id,
        title: j['title'] ?? '',
        category: j['category'],
        messages: (j['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
        updatedAt: j['updatedAt'] ?? 0,
      );
}

class ConversationStore {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations');
  }

  static Future<List<Conversation>> loadAll() async {
    final col = _collection;
    if (col == null) return [];
    final snapshot = await col.orderBy('updatedAt', descending: true).get();
    return snapshot.docs
        .map((doc) => Conversation.fromJson(doc.id, doc.data()))
        .toList();
  }

  static Future<void> upsert(Conversation conversation) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(conversation.id).set(conversation.toJson());
  }

  static Future<void> delete(String conversationId) async {
    final col = _collection;
    if (col == null) return;
    await col.doc(conversationId).delete();
  }
}
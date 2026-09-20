import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String role;
  final String text;
  // The classification this SPECIFIC reply was generated under - null for
  // user/system messages and for Appointment replies (which don't use the
  // badge/answer-card layout). Kept per-message rather than as shared
  // screen state so an older Emergency reply still reads as "EMERGENCY
  // ALERT" even after a later message in the same thread gets classified
  // differently.
  final String? category;
  final double? confidence;
  final double? distressScore;

  ChatMessage({
    required this.role,
    required this.text,
    this.category,
    this.confidence,
    this.distressScore,
  });

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        if (category != null) 'category': category,
        if (confidence != null) 'confidence': confidence,
        if (distressScore != null) 'distressScore': distressScore,
      };
  static ChatMessage fromMap(Map<String, dynamic> m) => ChatMessage(
        role: m['role'],
        text: m['text'],
        category: m['category'] as String?,
        confidence: (m['confidence'] as num?)?.toDouble(),
        distressScore: (m['distressScore'] as num?)?.toDouble(),
      );
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
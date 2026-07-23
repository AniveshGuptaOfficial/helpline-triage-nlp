import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const HelplineApp());
}

class HelplineApp extends StatelessWidget {
  const HelplineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helpline Triage',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const ChatPage(),
    );
  }
}

// ---------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------

class ChatMessage {
  final String role; // "user" or "model"
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
        'id': id,
        'title': title,
        'category': category,
        'messages': messages.map((m) => m.toMap()).toList(),
        'updatedAt': updatedAt,
      };

  static Conversation fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'],
        title: j['title'],
        category: j['category'],
        messages: (j['messages'] as List)
            .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
        updatedAt: j['updatedAt'],
      );
}

// ---------------------------------------------------------------------
// Local persistence (device storage, no server database)
// ---------------------------------------------------------------------

class ConversationStore {
  static const _key = 'conversations';

  static Future<List<Conversation>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // newest first
  }

  static Future<void> saveAll(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  /// Insert or update one conversation, keeping the rest of the list intact.
  static Future<void> upsert(Conversation conversation) async {
    final all = await loadAll();
    final index = all.indexWhere((c) => c.id == conversation.id);
    if (index >= 0) {
      all[index] = conversation;
    } else {
      all.add(conversation);
    }
    await saveAll(all);
  }
}

// ---------------------------------------------------------------------
// History list screen
// ---------------------------------------------------------------------

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await ConversationStore.loadAll();
    setState(() {
      _conversations = all;
      _isLoading = false;
    });
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'Emergency':
        return Colors.red;
      case 'Medicine Query':
        return Colors.amber.shade800;
      case 'Appointment':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Conversations'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('No past conversations yet.'))
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final c = _conversations[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _categoryColor(c.category),
                        child: Text(
                          c.category != null ? c.category![0] : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(c.category ?? 'Uncategorized'),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------------------
// Main chat screen
// ---------------------------------------------------------------------

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  String? _category;
  double? _distressScore;
  bool _escalationFlag = false;
  bool _isLoading = false;

  String _conversationId = _newId();
  String? _conversationTitle;

  static const String _apiUrl = 'http://10.0.2.2:5000/chat';

  static String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, String>> get _historyForApi =>
      _messages.map((m) => m.toMap()).toList();

  Future<void> _persistCurrentConversation() async {
    if (_messages.isEmpty) return;
    final conversation = Conversation(
      id: _conversationId,
      title: _conversationTitle ?? _messages.first.text,
      category: _category,
      messages: _messages,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ConversationStore.upsert(conversation);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_messages.isEmpty) {
      _conversationTitle = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final res = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'history': _historyForApi.sublist(0, _historyForApi.length - 1),
              'message': text,
              'category': _category,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _category = data['category'];
          _escalationFlag = data['escalation_flag'] ?? false;
          if (data['distress_score'] != null) {
            _distressScore = (data['distress_score'] as num).toDouble();
          }
          _messages.add(ChatMessage(
            role: 'model',
            text: data['response'] ?? '[No response]',
          ));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            role: 'model',
            text: '[Server error: ${res.statusCode}]',
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(role: 'model', text: '[Could not reach server: $e]'));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
      await _persistCurrentConversation();
    }
  }

  Future<void> _startNewConversation() async {
    await _persistCurrentConversation();
    setState(() {
      _messages = [];
      _category = null;
      _distressScore = null;
      _escalationFlag = false;
      _conversationId = _newId();
      _conversationTitle = null;
    });
  }

  Future<void> _openHistory() async {
    await _persistCurrentConversation();
    final selected = await Navigator.push<Conversation>(
      context,
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
    if (selected != null) {
      setState(() {
        _conversationId = selected.id;
        _conversationTitle = selected.title;
        _category = selected.category;
        _messages = selected.messages;
        _distressScore = null; // not re-shown for reloaded conversations
        _escalationFlag = selected.category == 'Emergency';
      });
      _scrollToBottom();
    }
  }

  Color _categoryColor(String? category) {
    switch (category) {
      case 'Emergency':
        return Colors.red;
      case 'Medicine Query':
        return Colors.amber.shade800;
      case 'Appointment':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoryBanner() {
    if (_category == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _categoryColor(_category).withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _categoryColor(_category),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _category!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          if (_escalationFlag) ...[
            const SizedBox(width: 6),
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          ],
          if (_distressScore != null) ...[
            const SizedBox(width: 10),
            Text('Distress: ${_distressScore!.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rural Helpline Triage'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past conversations',
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New conversation',
            onPressed: _startNewConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBanner(),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Start by describing a symptom, medicine question, or appointment request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Type your message...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
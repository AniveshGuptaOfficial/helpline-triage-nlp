import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../theme.dart';
import '../services/conversation_store.dart';
import 'history_page.dart';
import 'stats_page.dart';

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
  double? _confidence;
  bool _escalationFlag = false;
  bool _isLoading = false;

  String _conversationId = _newId();
  String? _conversationTitle;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsEnabled = false;

  static const String _apiUrl = 'http://10.0.2.2:5000/chat';

  static String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
      );
    }
  }

  void _toggleTts() {
    setState(() => _ttsEnabled = !_ttsEnabled);
    if (!_ttsEnabled) _flutterTts.stop();
  }

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

  List<Map<String, String>> get _historyForApi => _messages
      .where((m) => m.role == 'user' || m.role == 'model')
      .map((m) => m.toMap())
      .toList();

  Future<void> _persistCurrentConversation() async {
    final realMessages = _messages.where((m) => m.role != 'system').toList();
    if (realMessages.isEmpty) return;
    final conversation = Conversation(
      id: _conversationId,
      title: _conversationTitle ?? realMessages.first.text,
      category: _category,
      messages: realMessages,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ConversationStore.upsert(conversation);
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }

    final realMessages = _messages.where((m) => m.role != 'system').toList();
    if (realMessages.isEmpty) {
      _conversationTitle =
          text.length > 50 ? '${text.substring(0, 50)}...' : text;
    }

    final historyBefore = _historyForApi;

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
              'history': historyBefore,
              'message': text,
              'category': _category,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final replyText = data['response'] ?? '[No response]';
        setState(() {
          _category = data['category'];
          _escalationFlag = data['escalation_flag'] ?? false;
          if (data['distress_score'] != null) {
            _distressScore = (data['distress_score'] as num).toDouble();
          }
          if (data['confidence'] != null) {
            _confidence = (data['confidence'] as num).toDouble();
          }
          _messages.add(ChatMessage(role: 'model', text: replyText));
        });
        if (_ttsEnabled) {
          _flutterTts.speak(replyText);
        }
      } else {
        setState(() {
          _messages.add(ChatMessage(
            role: 'system',
            text:
                'The server had trouble responding (code ${res.statusCode}). Please try again.',
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'system',
          text: "Can't reach the server right now. Check your connection "
              "(and that the backend is running), then try again.",
        ));
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
      _confidence = null;
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
        _distressScore = null;
        _confidence = null;
        _escalationFlag = selected.category == 'Emergency';
      });
      _scrollToBottom();
    }
  }

  void _openStats() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage()));
  }

  Future<void> _signOut() async {
    await _persistCurrentConversation();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in anytime with your phone number.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Widget _buildCategoryBanner() {
    if (_category == null) return const SizedBox.shrink();
    final color = categoryColor(_category);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(categoryIcon(_category), color: color, size: 18),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _category!,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          if (_escalationFlag) ...[
            const SizedBox(width: 6),
            const Icon(Icons.warning_amber_rounded, color: kEmergency, size: 18),
          ],
          const Spacer(),
          if (_confidence != null)
            Text('${(_confidence! * 100).toStringAsFixed(0)}% confident',
                style: const TextStyle(fontSize: 11, color: kNeutral)),
          if (_distressScore != null) ...[
            const SizedBox(width: 10),
            Text('Distress: ${_distressScore!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: kNeutral)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.role == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: kNeutral),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message.text,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: kNeutral,
                      fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );
    }

    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? kPrimary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
              color: isUser ? Colors.white : Colors.black87,
              fontSize: 15,
              height: 1.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.health_and_safety_rounded),
            SizedBox(width: 8),
            Text('Vaidyum', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
                _ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            tooltip: _ttsEnabled ? 'Voice replies on' : 'Voice replies off',
            onPressed: _toggleTts,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Stats',
            onPressed: _openStats,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Past conversations',
            onPressed: _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New conversation',
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryBanner(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.health_and_safety_rounded,
                              size: 56, color: kPrimary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'Welcome to Vaidyum',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Describe a symptom, ask a medicine question, or request an appointment to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kNeutral),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
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
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  if (_speechAvailable)
                    IconButton(
                      icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                      color: _isListening ? kEmergency : kNeutral,
                      tooltip: _isListening ? 'Stop listening' : 'Speak your message',
                      onPressed: _toggleListening,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        hintText: _isListening ? 'Listening...' : 'Type your message...',
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                        backgroundColor: kPrimary, foregroundColor: Colors.white),
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

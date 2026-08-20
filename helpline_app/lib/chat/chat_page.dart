import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
  int? _speakingMessageIndex; // index of the message currently being read aloud, if any

  // TODO: replace with your actual Space URL once deployed, e.g.
  // 'https://yourusername-vaidyum-backend.hf.space'
  static const String _backendBase = 'https://YOUR_USERNAME-vaidyum-backend.hf.space';
  static const String _apiUrl = '$_backendBase/chat';
  static const String _hospitalsUrl = '$_backendBase/hospitals';
  static const String _bookHospitalUrl = '$_backendBase/book_hospital';

  // Hospital lookup / booking state (Emergency + Appointment only)
  bool _hospitalFlowTriggeredForThisTurn = false;
  bool _isLoadingHospitals = false;
  List<Map<String, dynamic>> _hospitals = [];
  Map<String, dynamic>? _bookingResult; // result of /book_hospital

  static String _newId() => DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingMessageIndex = null);
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) setState(() => _speakingMessageIndex = null);
    });
    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _speakingMessageIndex = null);
    });
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
    if (!_ttsEnabled) {
      _flutterTts.stop();
      setState(() => _speakingMessageIndex = null);
    }
  }

  Future<void> _speakMessage(int index, String text) async {
    if (_speakingMessageIndex == index) {
      // Tapped the same message again: stop reading.
      await _flutterTts.stop();
      setState(() => _speakingMessageIndex = null);
      return;
    }
    // Switching to a different message: stop whatever was playing first.
    await _flutterTts.stop();
    setState(() => _speakingMessageIndex = index);
    await _flutterTts.speak(text);
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

  // ---------------------------------------------------------------
  // Hospital lookup + booking flow (Emergency / Appointment only)
  // ---------------------------------------------------------------

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchNearbyHospitals() async {
    setState(() {
      _isLoadingHospitals = true;
      _hospitals = [];
      _bookingResult = null;
    });

    final position = await _getCurrentLocation();
    if (position == null) {
      setState(() => _isLoadingHospitals = false);
      _messages.add(ChatMessage(
        role: 'system',
        text: "Couldn't access your location, so nearby hospitals can't be "
            "shown. Please allow location access and try again.",
      ));
      setState(() {});
      _scrollToBottom();
      return;
    }

    try {
      final res = await http
          .post(
            Uri.parse(_hospitalsUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
              'radius_miles': 8,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['hospitals'] as List? ?? [])
            .map((h) => Map<String, dynamic>.from(h as Map))
            .toList();
        setState(() => _hospitals = list);
        if (list.isEmpty) {
          _messages.add(ChatMessage(
            role: 'system',
            text: 'No hospitals were found within 8 miles (13 km) of '
                '(${position.latitude.toStringAsFixed(4)}, '
                '${position.longitude.toStringAsFixed(4)}). '
                'If that doesn\'t look like your real location, check the '
                'emulator\'s location settings (Extended Controls > Location).',
          ));
          setState(() {});
        }
      } else {
        _messages.add(ChatMessage(
          role: 'system',
          text: 'Could not fetch nearby hospitals right now.',
        ));
        setState(() {});
      }
    } catch (_) {
      _messages.add(ChatMessage(
        role: 'system',
        text: "Can't reach the hospital search service right now.",
      ));
      setState(() {});
    } finally {
      setState(() => _isLoadingHospitals = false);
      _scrollToBottom();
    }
  }

  Future<void> _selectHospital(Map<String, dynamic> hospital) async {
    setState(() => _isLoadingHospitals = true);
    try {
      final res = await http
          .post(
            Uri.parse(_bookHospitalUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hospital_name': hospital['name'],
              'hospital_address': hospital['address'],
              'hospital_lat': hospital['lat'],
              'hospital_lon': hospital['lon'],
              'category': _category,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _bookingResult = Map<String, dynamic>.from(data);
          _hospitals = [];
        });
      } else {
        _messages.add(ChatMessage(
          role: 'system',
          text: 'Could not confirm that booking. Please try selecting again.',
        ));
        setState(() {});
      }
    } catch (_) {
      _messages.add(ChatMessage(
        role: 'system',
        text: "Can't reach the booking service right now.",
      ));
      setState(() {});
    } finally {
      setState(() => _isLoadingHospitals = false);
      _scrollToBottom();
    }
  }

  Future<void> _openLiveNavigation() async {
    final booking = _bookingResult;
    if (booking == null) return;
    final intentUri = Uri.parse(booking['maps_intent_url'] as String);
    final webUri = Uri.parse(booking['maps_web_url'] as String);
    try {
      if (await canLaunchUrl(intentUri)) {
        await launchUrl(intentUri);
        return;
      }
    } catch (_) {
      // fall through to web URL
    }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  void _clearHospitalFlow() {
    setState(() {
      _hospitals = [];
      _bookingResult = null;
      _hospitalFlowTriggeredForThisTurn = false;
    });
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
        final hospitalLookupRequired =
            data['hospital_lookup_required'] == true;
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
          setState(() => _speakingMessageIndex = _messages.length - 1);
          _flutterTts.speak(replyText);
        }
        // Emergency / Appointment: after the triage/scheduling reply,
        // immediately look up nearby hospitals (once per conversation turn).
        if (hospitalLookupRequired &&
            !_hospitalFlowTriggeredForThisTurn &&
            _bookingResult == null) {
          _hospitalFlowTriggeredForThisTurn = true;
          _fetchNearbyHospitals();
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
    await _flutterTts.stop();
    setState(() {
      _messages = [];
      _category = null;
      _distressScore = null;
      _confidence = null;
      _escalationFlag = false;
      _conversationId = _newId();
      _conversationTitle = null;
      _hospitals = [];
      _bookingResult = null;
      _hospitalFlowTriggeredForThisTurn = false;
      _speakingMessageIndex = null;
    });
  }

  Future<void> _openHistory() async {
    await _persistCurrentConversation();
    await _flutterTts.stop();
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
        _hospitals = [];
        _bookingResult = null;
        // Reopened conversations already have their reply in history, so
        // don't re-trigger an automatic hospital search on top of it.
        _hospitalFlowTriggeredForThisTurn = true;
        _speakingMessageIndex = null;
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

  Widget _buildHospitalSearchingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: kPrimaryLight,
      child: const Row(
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Searching nearby hospitals...',
              style: TextStyle(fontSize: 13, color: kPrimary)),
        ],
      ),
    );
  }

  Widget _buildHospitalListPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.local_hospital_rounded,
                    color: kPrimary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _category == 'Emergency'
                        ? 'Please select a hospital to secure your Emergency Triage spot'
                        : 'Please select your preferred hospital for the appointment',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: _clearHospitalFlow,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Within 8 miles (13 km) - nearest first',
              style: TextStyle(fontSize: 11, color: kNeutral),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: _hospitals.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final h = _hospitals[index];
                final rating = h['rating'];
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: kPrimaryLight,
                    child: Icon(Icons.local_hospital_rounded,
                        color: kPrimary, size: 18),
                  ),
                  title: Text(h['name']?.toString() ?? 'Hospital',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${h['distance_miles']} mi away'
                    '${rating != null ? ' • ${rating.toStringAsFixed(1)}★' : ' • Not rated'}',
                    style: const TextStyle(fontSize: 12, color: kNeutral),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: kNeutral),
                  onTap: _isLoadingHospitals ? null : () => _selectHospital(h),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingConfirmationPanel() {
    final booking = _bookingResult!;
    final lat = booking['hospital_lat'];
    final lon = booking['hospital_lon'];
    final staticMapUrl = booking['static_map_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: kPrimary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking['confirmation_text']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss',
                  onPressed: _clearHospitalFlow,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              booking['hospital_address']?.toString() ??
                  'Address not available',
              style: const TextStyle(fontSize: 12.5, color: kNeutral),
            ),
          ),
          const SizedBox(height: 8),
          if (staticMapUrl != null && lat != null && lon != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _openLiveNavigation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Image.network(
                        staticMapUrl,
                        headers: const {
                          'User-Agent':
                              'VaidyumHelplineTriage/1.0 (BCSE409L course project)',
                        },
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 140,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                                strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stack) => Container(
                          height: 140,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: const Text(
                            'Map preview unavailable - you can still tap '
                            '"Open Live Navigation" below',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: kNeutral),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Tap to navigate',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openLiveNavigation,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Open Live Navigation in Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
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
    final isSpeaking = _speakingMessageIndex == index;
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
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.35),
            ),
            if (!isUser) ...[
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _speakMessage(index, message.text),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSpeaking
                            ? Icons.stop_circle_rounded
                            : Icons.volume_up_rounded,
                        size: 16,
                        color: isSpeaking ? kEmergency : kPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSpeaking ? 'Stop' : 'Listen',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isSpeaking ? kEmergency : kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
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
                        _buildMessageBubble(_messages[index], index),
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
          // Emergency / Appointment hospital lookup + booking flow
          if (_isLoadingHospitals && _hospitals.isEmpty && _bookingResult == null)
            _buildHospitalSearchingIndicator(),
          if (_bookingResult != null)
            _buildBookingConfirmationPanel()
          else if (_hospitals.isNotEmpty)
            _buildHospitalListPanel(),
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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../theme.dart';
import '../services/conversation_store.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/symptom_chip_bar.dart';
import '../widgets/follow_up_chip_bar.dart';
import '../widgets/language_switcher_bar.dart';
import '../widgets/emergency_call_fab.dart';
import '../localization/vaidyum_strings.dart';
import 'history_page.dart';

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
  // Auto-read replies is ON by default, per the "keep it simple, no
  // complicated voice settings" requirement - the toggle stays available
  // for anyone who wants it off, but a rural/low-literacy user shouldn't
  // have to discover and enable it first.
  bool _ttsEnabled = true;
  int? _speakingMessageIndex; // index of the message currently being read aloud, if any

  // Voice-first mode: when on, mic input auto-stops after a short silence
  // and auto-sends, instead of requiring a separate tap to send.
  bool _voiceModeEnabled = false;

  // Quick language switcher (chat screen) - shares the same persisted
  // preference the Profile screen's language list reads/writes.
  String _languageCode = 'en';

  bool _sharingLocation = false;

  // Backend URL is set at BUILD TIME via --dart-define, not hardcoded.
  // Default (no flag needed): local backend via the emulator's special
  // 10.0.2.2 alias for your PC's localhost - just `flutter run` as usual.
  // To point at a real deployed backend instead (for testing on your
  // real phone, or against Cloud Run/Render), pass the flag:
  //   flutter run --dart-define=BACKEND_URL=https://your-real-url.run.app
  //   flutter build apk --release --dart-define=BACKEND_URL=https://your-real-url.run.app
  // Same source code either way - only the launch/build command changes.
  static const String _backendBase = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
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
    _loadLanguagePreference();
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

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kLanguagePrefKey);
      if (saved != null && mounted) setState(() => _languageCode = saved);
    } catch (_) {
      // Non-fatal: falls back to English for this session.
    }
  }

  Future<void> _setLanguage(String code) async {
    setState(() => _languageCode = code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLanguagePrefKey, code);
    } catch (_) {
      // Non-fatal: selection still applies for this session.
    }
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
        // Voice Mode: stop automatically after a short silence and send
        // right away, instead of requiring a second tap. Regular mic tap
        // (Voice Mode off) keeps the original behavior - dictate, then
        // review/edit the text before sending manually.
        pauseFor: _voiceModeEnabled ? const Duration(seconds: 3) : null,
        listenFor: _voiceModeEnabled ? const Duration(seconds: 30) : null,
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          if (_voiceModeEnabled && result.finalResult) {
            setState(() => _isListening = false);
            if (_controller.text.trim().isNotEmpty) {
              _sendMessage();
            }
          }
        },
      );
    }
  }

  void _toggleVoiceMode() {
    setState(() => _voiceModeEnabled = !_voiceModeEnabled);
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

  List<Map<String, dynamic>> get _historyForApi => _messages
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
          .timeout(const Duration(seconds: 35));

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

  /// Sends a pre-written phrase (from a symptom chip or follow-up chip)
  /// exactly as if the user had typed and sent it themselves - reuses
  /// _sendMessage() so history, persistence, and the hospital-lookup flow
  /// all behave identically to a typed message.
  void _sendQuickMessage(String phrase, {String? intent}) {
    if (_isLoading) return;
    _controller.text = phrase;
    _sendMessage(followUpIntent: intent);
  }

  /// Emergency location sharing: reuses the same location fetch already
  /// used for hospital search, builds a Google Maps link, and opens the
  /// device's native share sheet so the user can send it via WhatsApp,
  /// SMS, or any other installed app. Handles the off/denied states with
  /// a plain snackbar instead of failing silently.
  Future<void> _shareMyLocation() async {
    setState(() => _sharingLocation = true);
    try {
      final position = await _getCurrentLocation();
      if (!mounted) return;
      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't get your location. Please allow location access and try again.",
            ),
          ),
        );
        return;
      }
      final mapsLink =
          'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
      await Share.share(
        'Emergency - I need help. My current location: $mapsLink',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't share location right now.")),
      );
    } finally {
      if (mounted) setState(() => _sharingLocation = false);
    }
  }

  Future<void> _sendMessage({String? followUpIntent}) async {
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
              'language': _languageCode,
              if (followUpIntent != null) 'follow_up_intent': followUpIntent,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final replyText = data['response'] ?? '[No response]';
        final hospitalLookupRequired =
            data['hospital_lookup_required'] == true;
        // Backend re-triage safety net: a conversation that started as
        // Medicine Query or Appointment can be promoted to Emergency
        // mid-thread if a later message (e.g. "it's getting worse") reads
        // as an emergency in context. Surface this explicitly instead of
        // letting the app bar/badge silently flip colors with no
        // explanation.
        final justEscalated = data['re_triaged_to_emergency'] == true;
        setState(() {
          if (justEscalated) {
            _messages.add(ChatMessage(
              role: 'system',
              text: '⚠️ Based on your latest message, this conversation has '
                  'been escalated to Emergency.',
            ));
          }
          _category = data['category'];
          _escalationFlag = data['escalation_flag'] ?? false;
          if (data['distress_score'] != null) {
            _distressScore = (data['distress_score'] as num).toDouble();
          }
          if (data['confidence'] != null) {
            _confidence = (data['confidence'] as num).toDouble();
          }
          _messages.add(ChatMessage(
            role: 'model',
            text: replyText,
            category: data['category'] as String?,
            confidence: (data['confidence'] as num?)?.toDouble(),
            distressScore: (data['distress_score'] as num?)?.toDouble(),
          ));
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
    if (!mounted) return;
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


  /// Dials the national emergency ambulance number directly from the
  /// Emergency answer card's "Call Ambulance (108)" button.
  Future<void> _callAmbulance() async {
    final uri = Uri(scheme: 'tel', path: '108');
    await launchUrl(uri);
  }

  Future<void> _signOut() async {
    await _persistCurrentConversation();
    if (!mounted) return;
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
    return Material(
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
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
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final h = _hospitals[index];
                  final rating = h['rating'];
                  final phone = h['phone']?.toString();
                  final hasPhone = phone != null && phone.isNotEmpty;
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPhone)
                          IconButton(
                            icon: const Icon(Icons.call_rounded, color: kPrimary, size: 20),
                            tooltip: 'Call Hospital',
                            onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
                          ),
                        const Icon(Icons.chevron_right_rounded, color: kNeutral),
                      ],
                    ),
                    onTap: _isLoadingHospitals ? null : () => _selectHospital(h),
                  );
                },
              ),
            ),
          ],
        ),
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

  /// Turns a free-form Gemini reply into separate lines for the card
  /// layout below - a display-only heuristic (message.text itself, and
  /// what gets saved to Firestore history, is untouched either way).
  List<String> _splitIntoPoints(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isEmpty ? [text.trim()] : lines;
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }

  /// Structured "answer card" used for Medicine Query and Emergency model
  /// replies (badge + numbered points + disclaimer / Call Ambulance),
  /// matching the mockups. Appointment replies and everything before the
  /// category is known keep using the plain chat bubble in
  /// _buildMessageBubble below - this widget is only ever reached from
  /// there, never instead of it.
  Widget _buildAnswerCard(ChatMessage message, int index) {
    final msgCategory = message.category;
    final isEmergency = msgCategory == 'Emergency';
    final isMedicine = msgCategory == 'Medicine Query';
    final color = categoryColor(msgCategory);
    final bgColor = isEmergency ? kEmergencyBg : kPrimaryLight;
    final borderColor = isEmergency ? kEmergencyBorder : color.withValues(alpha: 0.25);
    final points = _splitIntoPoints(message.text);
    final isSpeaking = _speakingMessageIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isEmergency ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isEmergency ? 'EMERGENCY ALERT' : (msgCategory ?? '').toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const Spacer(),
              if (isMedicine && message.confidence != null)
                _miniPill('${(message.confidence! * 100).toStringAsFixed(0)}% Match', color),
              if (isEmergency && message.distressScore != null)
                _miniPill('Distress: ${(message.distressScore! * 100).toStringAsFixed(0)}%', kEmergency),
            ],
          ),
          const SizedBox(height: 10),
          ...points.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: points.length > 1
                  ? RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: kFontBody, height: 1.4, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: '${i + 1}. ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color),
                          ),
                          TextSpan(text: line),
                        ],
                      ),
                    )
                  : Text(line,
                      style: const TextStyle(
                          fontSize: kFontBody, height: 1.4, color: Colors.black87)),
            );
          }),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kWarningBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 15, color: kWarningText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    uiLabel('guidanceWarning', _languageCode),
                    style: const TextStyle(fontSize: 11.5, color: kWarningText, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (isEmergency) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _callAmbulance,
                icon: const Icon(Icons.call_rounded, size: 22),
                label: Text(uiLabel('callAmbulanceBtn', _languageCode)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kEmergency,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(kMinTapTarget),
                  textStyle: const TextStyle(
                      fontSize: kFontLarge, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sharingLocation ? null : _shareMyLocation,
                icon: _sharingLocation
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kEmergency),
                      )
                    : const Icon(Icons.share_location_rounded, size: 20),
                label: Text(uiLabel('shareLocation', _languageCode)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kEmergency,
                  side: const BorderSide(color: kEmergency, width: 1.6),
                  minimumSize: const Size.fromHeight(kMinTapTarget),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_hospitals.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital_rounded, color: kEmergency, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_hospitals.first['name']?.toString() ?? 'Nearest hospital',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            '${_hospitals.first['distance_miles']} mi away'
                            '${_hospitals.first['emergency'] == true ? ' • Emergency Ward Open' : ''}',
                            style: const TextStyle(fontSize: 11.5, color: kNeutral),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kNeutral),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _speakMessage(index, message.text),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                    size: 16,
                    color: isSpeaking ? kEmergency : color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSpeaking ? 'Stop' : 'Listen',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isSpeaking ? kEmergency : color,
                    ),
                  ),
                ],
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

    // Medicine Query / Emergency replies get the structured card layout
    // from the mockups; Appointment replies and user messages keep the
    // original chat-bubble rendering below unchanged.
    if (!isUser && (message.category == 'Emergency' || message.category == 'Medicine Query')) {
      return _buildAnswerCard(message, index);
    }

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
                  fontSize: kFontBody,
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
        backgroundColor: _escalationFlag ? kEmergency : kPrimary,
        titleSpacing: 8,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _escalationFlag
                  ? Icons.local_shipping_rounded
                  : Icons.health_and_safety_rounded,
              size: 20,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _escalationFlag ? uiLabel('vaidyumEmergency', _languageCode) : 'Vaidyum',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // "Triage Active" / "HIGH DISTRESS" status pill
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _escalationFlag
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _escalationFlag
                        ? uiLabel('highDistress', _languageCode)
                        : uiLabel('triageActive', _languageCode),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
                _ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            tooltip: _ttsEnabled ? 'Voice replies on' : 'Voice replies off',
            onPressed: _toggleTts,
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: LanguageSwitcherBar(
              selectedCode: _languageCode,
              onLanguageSelected: _setLanguage,
            ),
          ),
          _buildCategoryBanner(),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.health_and_safety_rounded,
                              size: 56, color: kPrimary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            uiLabel('welcomeTitle', _languageCode),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            uiLabel('welcomeSubtitle', _languageCode),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: kNeutral),
                          ),
                          const SizedBox(height: 24),
                          SymptomChipBar(
                            languageCode: _languageCode,
                            onSymptomSelected: _sendQuickMessage,
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
          if (_messages.isNotEmpty && _messages.last.role == 'model' && !_isLoading)
            FollowUpChipBar(
              languageCode: _languageCode,
              category: _category,
              onFollowUpSelected: _sendQuickMessage,
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
            _buildHospitalListPanel()
          else if (!_isLoadingHospitals && _hospitalFlowTriggeredForThisTurn && _bookingResult == null)
            Material(
              color: Colors.white,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching_rounded,
                        color: kNeutral, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No hospitals found nearby. Try enabling GPS or setting your location in the emulator.',
                        style: TextStyle(fontSize: 12, color: kNeutral),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchNearbyHospitals,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          // Emergency reassurance strip, matching the mockup's "Voice &
          // text locked" note. Worded accurately instead of copied
          // verbatim: this build keeps voice/text available for follow-up
          // details rather than actually locking them, since disabling
          // input would block someone from adding "it's getting worse" or
          // similar during a real emergency.
          if (_escalationFlag)
            Container(
              width: double.infinity,
              color: kEmergencyBg,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                uiLabel('emergencyStrip', _languageCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: kEmergency, fontStyle: FontStyle.italic),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                // Voice Mode / Auto-read toggles - kept visible right above
                // the input since they're used every message, unlike the
                // language switcher which changes rarely.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _toggleChip(
                          icon: Icons.record_voice_over_rounded,
                          label: uiLabel('voiceMode', _languageCode),
                          active: _voiceModeEnabled,
                          onTap: _toggleVoiceMode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _toggleChip(
                          icon: Icons.hearing_rounded,
                          label: uiLabel('autoReadReplies', _languageCode),
                          active: _ttsEnabled,
                          onTap: _toggleTts,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
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
                          iconSize: 32,
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(
                              minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                          icon: Icon(
                              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
                          color: _isListening ? kEmergency : kPrimary,
                          tooltip: _isListening ? 'Stop listening' : 'Speak your message',
                          onPressed: _toggleListening,
                        ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          style: const TextStyle(fontSize: kFontBody),
                          decoration: InputDecoration(
                            border:
                                OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                            hintText: _isListening
                                ? uiLabel('listening', _languageCode)
                                : uiLabel('typeMessage', _languageCode),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        iconSize: 26,
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(
                            minWidth: kMinTapTarget, minHeight: kMinTapTarget),
                        onPressed: _isLoading ? null : _sendMessage,
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                            backgroundColor: kPrimary, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Lifted above the Voice Mode/Auto-read toggle row + input bar, which
      // (unlike the other 4 screens) live inside this screen's body as
      // fixed content, not inside bottomNavigationBar - Scaffold's default
      // FAB position only avoids bottomNavigationBar, so without this
      // offset the button sits directly on top of the send button.
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 192),
        child: EmergencyCallFab(),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  /// Small labeled on/off chip used for the Voice Mode and Auto-read
  /// toggles - icon + short label + a filled/outline state so it reads
  /// clearly even without careful reading of text.
  Widget _toggleChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kPrimary : kPrimaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : kPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : kPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Small, hand-maintained translation set for the phrases this app needs
/// to show or send in the user's chosen helpline language: quick-symptom
/// chip phrases, follow-up chip phrases, and a handful of UI labels for
/// the voice/language features. This is intentionally NOT a general
/// translation layer - it only covers the fixed, known strings below.
/// Free-form chat replies are still handled by the backend's Gemini
/// translation step, untouched by this file.
library;

/// One tappable quick-symptom entry: an emoji/icon label plus the
/// natural-language phrase to send, per language code.
class SymptomOption {
  final String emoji;
  final Map<String, String> phrasesByLanguage;

  const SymptomOption({required this.emoji, required this.phrasesByLanguage});

  /// Falls back to English if a language isn't covered for this entry
  /// (all five are covered below, but this keeps it safe against typos).
  String phraseFor(String languageCode) =>
      phrasesByLanguage[languageCode] ?? phrasesByLanguage['en']!;
}

/// The 7 quick-symptom chips shown on the empty chat screen, in order.
const List<SymptomOption> kQuickSymptoms = [
  SymptomOption(
    emoji: '🤒',
    phrasesByLanguage: {
      'en': 'I have fever',
      'hi': 'मुझे बुखार है',
      'ta': 'எனக்கு காய்ச்சல் இருக்கிறது',
      'te': 'నాకు జ్వరం వచ్చింది',
      'mr': 'मला ताप आला आहे',
    },
  ),
  SymptomOption(
    emoji: '❤️',
    phrasesByLanguage: {
      'en': 'I have chest pain',
      'hi': 'मुझे सीने में दर्द है',
      'ta': 'எனக்கு மார்பு வலி இருக்கிறது',
      'te': 'నాకు ఛాతీ నొప్పి ఉంది',
      'mr': 'मला छातीत दुखत आहे',
    },
  ),
  SymptomOption(
    emoji: '🫁',
    phrasesByLanguage: {
      'en': 'I am having trouble breathing',
      'hi': 'मुझे सांस लेने में तकलीफ़ हो रही है',
      'ta': 'எனக்கு மூச்சு விட சிரமமாக இருக்கிறது',
      'te': 'నాకు శ్వాస తీసుకోవడంలో ఇబ్బంది ఉంది',
      'mr': 'मला श्वास घ्यायला त्रास होत आहे',
    },
  ),
  SymptomOption(
    emoji: '🤕',
    phrasesByLanguage: {
      'en': 'I have an injury',
      'hi': 'मुझे चोट लगी है',
      'ta': 'எனக்கு காயம் ஏற்பட்டுள்ளது',
      'te': 'నాకు గాయం అయ్యింది',
      'mr': 'मला दुखापत झाली आहे',
    },
  ),
  SymptomOption(
    emoji: '🤢',
    phrasesByLanguage: {
      'en': 'I have stomach pain',
      'hi': 'मुझे पेट में दर्द है',
      'ta': 'எனக்கு வயிற்று வலி இருக்கிறது',
      'te': 'నాకు కడుపు నొప్పి ఉంది',
      'mr': 'मला पोटदुखी आहे',
    },
  ),
  SymptomOption(
    emoji: '👶',
    phrasesByLanguage: {
      'en': 'My child is sick',
      'hi': 'मेरा बच्चा बीमार है',
      'ta': 'என் குழந்தைக்கு உடல்நிலை சரியில்லை',
      'te': 'నా పిల్లవాడికి ఆరోగ్యం బాలేదు',
      'mr': 'माझं मूल आजारी आहे',
    },
  ),
  SymptomOption(
    emoji: '💊',
    phrasesByLanguage: {
      'en': 'I have a question about medicine',
      'hi': 'मुझे दवा के बारे में एक सवाल है',
      'ta': 'எனக்கு மருந்து பற்றி ஒரு கேள்வி உள்ளது',
      'te': 'నాకు మందుల గురించి ఒక ప్రశ్న ఉంది',
      'mr': 'मला औषधाबद्दल एक प्रश्न आहे',
    },
  ),
];

/// The 4 follow-up chips shown under a reply, in order.
const List<SymptomOption> kFollowUpOptions = [
  SymptomOption(
    emoji: '🙂',
    phrasesByLanguage: {
      'en': "I'm better now",
      'hi': 'अब मुझे बेहतर लग रहा है',
      'ta': 'இப்போது நலமாக உணர்கிறேன்',
      'te': 'ఇప్పుడు నాకు నయమైంది',
      'mr': 'आता मला बरं वाटतंय',
    },
  ),
  SymptomOption(
    emoji: '😐',
    phrasesByLanguage: {
      'en': "It's still the same",
      'hi': 'अभी भी वैसा ही है',
      'ta': 'இன்னும் அப்படியே இருக்கிறது',
      'te': 'ఇంకా అలాగే ఉంది',
      'mr': 'अजूनही तसंच आहे',
    },
  ),
  SymptomOption(
    emoji: '😟',
    phrasesByLanguage: {
      'en': "It's getting worse",
      'hi': 'यह और बिगड़ रहा है',
      'ta': 'மேலும் மோசமாகிறது',
      'te': 'ఇంకా అధ్వాన్నంగా అవుతోంది',
      'mr': 'ते अधिक बिघडत आहे',
    },
  ),
  SymptomOption(
    emoji: '🆘',
    phrasesByLanguage: {
      'en': 'I need more help',
      'hi': 'मुझे और मदद चाहिए',
      'ta': 'எனக்கு மேலும் உதவி தேவை',
      'te': 'నాకు మరింత సహాయం కావాలి',
      'mr': 'मला अजून मदत हवी आहे',
    },
  ),
];

/// A handful of standalone UI labels used by the voice/language features,
/// keyed by a semantic name then language code.
const Map<String, Map<String, String>> kUiLabels = {
  'voiceMode': {
    'en': 'Voice Mode',
    'hi': 'आवाज़ मोड',
    'ta': 'குரல் முறை',
    'te': 'వాయిస్ మోడ్',
    'mr': 'आवाज मोड',
  },
  'autoReadReplies': {
    'en': 'Auto-read replies',
    'hi': 'जवाब अपने आप पढ़ें',
    'ta': 'பதில்களை தானாக படிக்கவும்',
    'te': 'సమాధానాలను స్వయంచాలకంగా చదవండి',
    'mr': 'उत्तरे आपोआप वाचा',
  },
  'shareLocation': {
    'en': 'Share My Location',
    'hi': 'मेरा स्थान साझा करें',
    'ta': 'என் இருப்பிடத்தை பகிரவும்',
    'te': 'నా స్థానాన్ని షేర్ చేయండి',
    'mr': 'माझे स्थान शेअर करा',
  },
  'listening': {
    'en': 'Listening...',
    'hi': 'सुन रहा है...',
    'ta': 'கேட்கிறது...',
    'te': 'వింటోంది...',
    'mr': 'ऐकत आहे...',
  },
};

String uiLabel(String key, String languageCode) =>
    kUiLabels[key]?[languageCode] ?? kUiLabels[key]?['en'] ?? key;
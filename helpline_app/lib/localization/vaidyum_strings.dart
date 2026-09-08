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

  // --- Home / chat screen chrome ---
  'welcomeTitle': {
    'en': 'Welcome to Vaidyum',
    'hi': 'वैद्यम में आपका स्वागत है',
    'ta': 'வைத்யம் உங்களை வரவேற்கிறது',
    'te': 'వైద్యం కు స్వాగతం',
    'mr': 'वैद्यम मध्ये आपले स्वागत आहे',
  },
  'welcomeSubtitle': {
    'en': 'Describe a symptom, ask a medicine question, or request an appointment to get started.',
    'hi': 'शुरू करने के लिए कोई लक्षण बताएं, दवा के बारे में पूछें, या अपॉइंटमेंट का अनुरोध करें।',
    'ta': 'தொடங்க ஒரு அறிகுறியை விவரிக்கவும், மருந்து கேள்வி கேளுங்கள், அல்லது சந்திப்பு கோரவும்.',
    'te': 'ప్రారంభించడానికి ఒక లక్షణాన్ని వివరించండి, మందుల ప్రశ్న అడగండి, లేదా అపాయింట్‌మెంట్ కోరండి.',
    'mr': 'सुरुवात करण्यासाठी लक्षण सांगा, औषधाबद्दल प्रश्न विचारा, किंवा अपॉइंटमेंट मागवा.',
  },
  'typeMessage': {
    'en': 'Type your message...',
    'hi': 'अपना संदेश लिखें...',
    'ta': 'உங்கள் செய்தியை தட்டச்சு செய்யவும்...',
    'te': 'మీ సందేశాన్ని టైప్ చేయండి...',
    'mr': 'तुमचा संदेश टाइप करा...',
  },
  'triageActive': {
    'en': 'Triage Active',
    'hi': 'ट्राइएज सक्रिय',
    'ta': 'டிரையேஜ் செயலில்',
    'te': 'ట్రయేజ్ యాక్టివ్',
    'mr': 'ट्रायएज सक्रिय',
  },
  'highDistress': {
    'en': 'HIGH DISTRESS',
    'hi': 'अत्यधिक तकलीफ़',
    'ta': 'கடுமையான துயரம்',
    'te': 'తీవ్ర బాధ',
    'mr': 'तीव्र त्रास',
  },
  'vaidyumEmergency': {
    'en': 'Vaidyum Emergency',
    'hi': 'वैद्यम आपातकाल',
    'ta': 'வைத்யம் அவசரநிலை',
    'te': 'వైద్యం అత్యవసరం',
    'mr': 'वैद्यम आणीबाणी',
  },
  'callAmbulanceBtn': {
    'en': 'Call Ambulance (108)',
    'hi': 'एम्बुलेंस बुलाएं (108)',
    'ta': 'ஆம்புலன்ஸை அழைக்கவும் (108)',
    'te': 'అంబులెన్స్‌కు కాల్ చేయండి (108)',
    'mr': 'रुग्णवाहिका बोलवा (108)',
  },
  'guidanceWarning': {
    'en': 'This is only guidance. Please consult a real doctor. In emergency, call 108.',
    'hi': 'यह केवल मार्गदर्शन है। कृपया किसी वास्तविक डॉक्टर से सलाह लें। आपातकाल में 108 पर कॉल करें।',
    'ta': 'இது வழிகாட்டுதல் மட்டுமே. உண்மையான மருத்துவரை அணுகவும். அவசரநிலையில் 108-ஐ அழைக்கவும்.',
    'te': 'ఇది మార్గదర్శకత్వం మాత్రమే. దయచేసి నిజమైన వైద్యుడిని సంప్రదించండి. అత్యవసర పరిస్థితిలో 108కి కాల్ చేయండి.',
    'mr': 'ही फक्त मार्गदर्शक माहिती आहे. कृपया खऱ्या डॉक्टरांचा सल्ला घ्या. आणीबाणीत 108 वर कॉल करा.',
  },
  'emergencyStrip': {
    'en': 'Emergency: For fastest help, call 108 directly. Voice & text stay open here for follow-up details.',
    'hi': 'आपातकाल: सबसे तेज़ मदद के लिए सीधे 108 पर कॉल करें। आगे की जानकारी के लिए आवाज़ और टेक्स्ट यहां उपलब्ध हैं।',
    'ta': 'அவசரநிலை: விரைவான உதவிக்கு நேரடியாக 108-ஐ அழைக்கவும். தொடர் விவரங்களுக்கு குரல் மற்றும் உரை இங்கே திறந்திருக்கும்.',
    'te': 'అత్యవసరం: వేగవంతమైన సహాయం కోసం నేరుగా 108కి కాల్ చేయండి. తదుపరి వివరాల కోసం వాయిస్ మరియు టెక్స్ట్ ఇక్కడ తెరిచి ఉంటాయి.',
    'mr': 'आणीबाणी: जलद मदतीसाठी थेट 108 वर कॉल करा. पुढील तपशीलांसाठी आवाज आणि मजकूर येथे खुले राहतात.',
  },

  // --- Hospitals screen ---
  'hospitalsTitle': {
    'en': 'Helpline Hospitals',
    'hi': 'हेल्पलाइन अस्पताल',
    'ta': 'ஹெல்ப்லைன் மருத்துவமனைகள்',
    'te': 'హెల్ప్‌లైన్ ఆసుపత్రులు',
    'mr': 'हेल्पलाइन रुग्णालये',
  },
  'searchingNearby': {
    'en': 'Searching nearby...',
    'hi': 'आस-पास खोज रहे हैं...',
    'ta': 'அருகில் தேடுகிறது...',
    'te': 'సమీపంలో వెతుకుతోంది...',
    'mr': 'जवळपास शोधत आहे...',
  },
  'hospitalsFoundNearby': {
    'en': 'hospitals found nearby',
    'hi': 'अस्पताल आस-पास मिले',
    'ta': 'மருத்துவமனைகள் அருகில் கண்டறியப்பட்டன',
    'te': 'ఆసుపత్రులు సమీపంలో కనుగొనబడ్డాయి',
    'mr': 'रुग्णालये जवळपास सापडली',
  },
  'mapUnavailable': {
    'en': 'Map preview unavailable',
    'hi': 'मानचित्र पूर्वावलोकन अनुपलब्ध',
    'ta': 'வரைபடம் முன்னோட்டம் கிடைக்கவில்லை',
    'te': 'మ్యాప్ ప్రివ్యూ అందుబాటులో లేదు',
    'mr': 'नकाशा पूर्वावलोकन उपलब्ध नाही',
  },
  'navigate': {
    'en': 'Navigate',
    'hi': 'दिशा-निर्देश',
    'ta': 'வழிசெலுத்து',
    'te': 'నావిగేట్ చేయండి',
    'mr': 'दिशादर्शन',
  },
  'callHospital': {
    'en': 'Call Hospital',
    'hi': 'अस्पताल को कॉल करें',
    'ta': 'மருத்துவமனையை அழைக்கவும்',
    'te': 'ఆసుపత్రికి కాల్ చేయండి',
    'mr': 'रुग्णालयाला कॉल करा',
  },
  'notRated': {
    'en': 'Not rated',
    'hi': 'रेटेड नहीं',
    'ta': 'மதிப்பீடு இல்லை',
    'te': 'రేటింగ్ లేదు',
    'mr': 'रेटिंग नाही',
  },
  'addressUnavailable': {
    'en': 'Address unavailable',
    'hi': 'पता उपलब्ध नहीं',
    'ta': 'முகவரி கிடைக்கவில்லை',
    'te': 'చిరునామా అందుబాటులో లేదు',
    'mr': 'पत्ता उपलब्ध नाही',
  },
  'noHospitalsFound': {
    'en': 'No hospitals found within 8 miles.',
    'hi': '8 मील के भीतर कोई अस्पताल नहीं मिला।',
    'ta': '8 மைல் தூரத்தில் மருத்துவமனைகள் இல்லை.',
    'te': '8 మైళ్ల లోపు ఆసుపత్రులు కనుగొనబడలేదు.',
    'mr': '8 मैलांच्या आत रुग्णालये आढळली नाहीत.',
  },
  'tryAgain': {
    'en': 'Try Again',
    'hi': 'पुनः प्रयास करें',
    'ta': 'மீண்டும் முயற்சிக்கவும்',
    'te': 'మళ్ళీ ప్రయత్నించండి',
    'mr': 'पुन्हा प्रयत्न करा',
  },

  // --- Stats screen ---
  'statsTitle': {
    'en': 'Triage Dashboard',
    'hi': 'ट्राइएज डैशबोर्ड',
    'ta': 'டிரையேஜ் டாஷ்போர்டு',
    'te': 'ట్రయేజ్ డాష్‌బోర్డ్',
    'mr': 'ट्रायएज डॅशबोर्ड',
  },
  'statsSubtitle': {
    'en': 'Overview of your cases',
    'hi': 'आपके मामलों का अवलोकन',
    'ta': 'உங்கள் வழக்குகளின் மேலோட்டம்',
    'te': 'మీ కేసుల అవలోకనం',
    'mr': 'तुमच्या प्रकरणांचा आढावा',
  },
  'totalConsultations': {
    'en': 'Total Consultations',
    'hi': 'कुल परामर्श',
    'ta': 'மொத்த ஆலோசனைகள்',
    'te': 'మొత్తం సంప్రదింపులు',
    'mr': 'एकूण सल्लामसलत',
  },
  'recentCases': {
    'en': 'Recent Cases',
    'hi': 'हाल के मामले',
    'ta': 'சமீபத்திய வழக்குகள்',
    'te': 'ఇటీవలి కేసులు',
    'mr': 'अलीकडील प्रकरणे',
  },
  'noConversationsYet': {
    'en': 'No conversations yet.',
    'hi': 'अभी तक कोई बातचीत नहीं।',
    'ta': 'இதுவரை உரையாடல்கள் இல்லை.',
    'te': 'ఇంకా సంభాషణలు లేవు.',
    'mr': 'अजून कोणतेही संभाषण नाही.',
  },
  'helplinesLabel': {
    'en': 'HELPLINES',
    'hi': 'हेल्पलाइन',
    'ta': 'ஹெல்ப்லைன்கள்',
    'te': 'హెల్ప్‌లైన్‌లు',
    'mr': 'हेल्पलाइन',
  },
  'medicineLabel': {
    'en': 'Medicine',
    'hi': 'दवा',
    'ta': 'மருந்து',
    'te': 'మందు',
    'mr': 'औषध',
  },
  'appointmentLabel': {
    'en': 'Appointment',
    'hi': 'अपॉइंटमेंट',
    'ta': 'சந்திப்பு',
    'te': 'అపాయింట్‌మెంట్',
    'mr': 'अपॉइंटमेंट',
  },
  'emergencyLabel': {
    'en': 'Emergency',
    'hi': 'आपातकाल',
    'ta': 'அவசரநிலை',
    'te': 'అత్యవసరం',
    'mr': 'आणीबाणी',
  },

  // --- Profile screen ---
  'profileTitle': {
    'en': 'Your Profile',
    'hi': 'आपकी प्रोफ़ाइल',
    'ta': 'உங்கள் சுயவிவரம்',
    'te': 'మీ ప్రొఫైల్',
    'mr': 'तुमची प्रोफाइल',
  },
  'registeredUser': {
    'en': 'Registered Helpline User',
    'hi': 'पंजीकृत हेल्पलाइन उपयोगकर्ता',
    'ta': 'பதிவு செய்யப்பட்ட ஹெல்ப்லைன் பயனர்',
    'te': 'నమోదిత హెల్ప్‌లైన్ వినియోగదారు',
    'mr': 'नोंदणीकृत हेल्पलाइन वापरकर्ता',
  },
  'responseLanguage': {
    'en': 'Helpline Response Language',
    'hi': 'हेल्पलाइन प्रतिक्रिया भाषा',
    'ta': 'ஹெல்ப்லைன் பதில் மொழி',
    'te': 'హెల్ప్‌లైన్ ప్రతిస్పందన భాష',
    'mr': 'हेल्पलाइन प्रतिसाद भाषा',
  },
  'emergencyContactsTitle': {
    'en': 'Emergency Contacts',
    'hi': 'आपातकालीन संपर्क',
    'ta': 'அவசர தொடர்புகள்',
    'te': 'అత్యవసర పరిచయాలు',
    'mr': 'आणीबाणी संपर्क',
  },
  'emergencyContactsSubtitle': {
    'en': 'Saved contacts can be notified quickly during an emergency.',
    'hi': 'आपातकाल के दौरान सहेजे गए संपर्कों को जल्दी सूचित किया जा सकता है।',
    'ta': 'அவசரகாலத்தில் சேமிக்கப்பட்ட தொடர்புகளுக்கு விரைவாக அறிவிக்கலாம்.',
    'te': 'అత్యవసర సమయంలో సేవ్ చేసిన పరిచయాలకు త్వరగా తెలియజేయవచ్చు.',
    'mr': 'आणीबाणीच्या वेळी जतन केलेल्या संपर्कांना पटकन कळवता येते.',
  },
  'addEmergencyContact': {
    'en': 'Add Emergency Contact',
    'hi': 'आपातकालीन संपर्क जोड़ें',
    'ta': 'அவசர தொடர்பைச் சேர்க்கவும்',
    'te': 'అత్యవసర పరిచయాన్ని జోడించండి',
    'mr': 'आणीबाणी संपर्क जोडा',
  },
  'shareEmergencyBtn': {
    'en': 'Share Emergency',
    'hi': 'आपातकाल साझा करें',
    'ta': 'அவசரநிலையைப் பகிரவும்',
    'te': 'అత్యవసర పరిస్థితిని షేర్ చేయండి',
    'mr': 'आणीबाणी शेअर करा',
  },
  'logoutBtn': {
    'en': 'Logout from Helpline',
    'hi': 'हेल्पलाइन से लॉगआउट करें',
    'ta': 'ஹெல்ப்லைனிலிருந்து வெளியேறு',
    'te': 'హెల్ప్‌లైన్ నుండి లాగ్ అవుట్ చేయండి',
    'mr': 'हेल्पलाइनमधून लॉगआउट करा',
  },
  'nameLabel': {
    'en': 'Name',
    'hi': 'नाम',
    'ta': 'பெயர்',
    'te': 'పేరు',
    'mr': 'नाव',
  },
  'phoneLabel': {
    'en': 'Phone Number',
    'hi': 'फ़ोन नंबर',
    'ta': 'தொலைபேசி எண்',
    'te': 'ఫోన్ నంబర్',
    'mr': 'फोन नंबर',
  },
  'save': {
    'en': 'Save',
    'hi': 'सहेजें',
    'ta': 'சேமி',
    'te': 'సేవ్ చేయండి',
    'mr': 'जतन करा',
  },
  'cancel': {
    'en': 'Cancel',
    'hi': 'रद्द करें',
    'ta': 'ரத்து செய்',
    'te': 'రద్దు చేయండి',
    'mr': 'रद्द करा',
  },

  // --- First Aid screen ---
  'firstAidTitle': {
    'en': 'First Aid',
    'hi': 'प्राथमिक चिकित्सा',
    'ta': 'முதலுதவி',
    'te': 'ప్రథమ చికిత్స',
    'mr': 'प्रथमोपचार',
  },
  'firstAidSubtitle': {
    'en': 'Works without internet',
    'hi': 'बिना इंटरनेट के काम करता है',
    'ta': 'இணையம் இல்லாமல் வேலை செய்யும்',
    'te': 'ఇంటర్నెట్ లేకుండా పనిచేస్తుంది',
    'mr': 'इंटरनेटशिवाय काम करते',
  },
  'firstAidOfflineNote': {
    'en': 'These steps are stored on your phone and work even with no signal.',
    'hi': 'ये चरण आपके फ़ोन में सहेजे गए हैं और बिना नेटवर्क के भी काम करते हैं।',
    'ta': 'இந்த படிகள் உங்கள் தொலைபேசியில் சேமிக்கப்பட்டுள்ளன, சிக்னல் இல்லாமலும் வேலை செய்யும்.',
    'te': 'ఈ దశలు మీ ఫోన్‌లో నిల్వ చేయబడ్డాయి మరియు సిగ్నల్ లేకున్నా పనిచేస్తాయి.',
    'mr': 'या पायऱ्या तुमच्या फोनमध्ये साठवलेल्या आहेत आणि सिग्नल नसतानाही काम करतात.',
  },
};

/// First Aid topic content (titles, steps, and warnings) in all 5
/// languages. IMPORTANT: these are safety-relevant medical instructions -
/// the English content was written first and reviewed against standard
/// first-aid guidance; the Hindi/Tamil/Telugu/Marathi versions below are
/// best-effort translations and have NOT been verified by a native-speaking
/// medical professional. Before relying on these in a real deployment,
/// have each translation checked by a fluent speaker with medical
/// knowledge - a subtly wrong translation of a first-aid instruction is
/// far more dangerous than a subtly wrong translation of a button label.
class FirstAidTranslation {
  final String title;
  final List<String> steps;
  final String warning;
  const FirstAidTranslation({required this.title, required this.steps, required this.warning});
}

const Map<String, Map<String, FirstAidTranslation>> kFirstAidTranslations = {
  'snakeBite': {
    'en': FirstAidTranslation(
      title: 'Snake Bite',
      steps: [
        'Keep the person calm and still - moving speeds up how fast venom spreads.',
        'Keep the bitten limb lower than the heart, if possible.',
        'Remove tight rings, watches, or clothing near the bite before swelling starts.',
        'Do NOT cut the wound, suck out venom, or apply ice.',
        'Do NOT tie a tight tourniquet - a loose, snug bandage above the bite is safer.',
        'Get to a hospital immediately - every snake bite needs real medical care.',
      ],
      warning: 'Call 108 or get to a hospital right away. Try to remember the snake\'s color and shape if it\'s safe to look.',
    ),
    'hi': FirstAidTranslation(
      title: 'सांप का काटना',
      steps: [
        'व्यक्ति को शांत और स्थिर रखें - हिलने-डुलने से ज़हर तेज़ी से फैलता है।',
        'यदि संभव हो तो काटे गए अंग को दिल से नीचे रखें।',
        'सूजन शुरू होने से पहले पास की तंग अंगूठी, घड़ी या कपड़े हटा दें।',
        'घाव को न काटें, ज़हर चूसने की कोशिश न करें, और बर्फ न लगाएं।',
        'कसकर तौर्निकेट न बांधें - काटने के ऊपर हल्की, ढीली पट्टी बांधना सुरक्षित है।',
        'तुरंत अस्पताल जाएं - हर सांप के काटने पर असली चिकित्सा देखभाल चाहिए।',
      ],
      warning: 'तुरंत 108 पर कॉल करें या अस्पताल जाएं। यदि सुरक्षित हो तो सांप का रंग और आकार याद रखने की कोशिश करें।',
    ),
    'ta': FirstAidTranslation(
      title: 'பாம்பு கடி',
      steps: [
        'நபரை அமைதியாகவும் அசையாமலும் வைத்திருங்கள் - அசைவது நச்சு பரவும் வேகத்தை அதிகரிக்கும்.',
        'முடிந்தால் கடிபட்ட உறுப்பை இதயத்திற்கு கீழே வைத்திருங்கள்.',
        'வீக்கம் தொடங்கும் முன் இறுக்கமான மோதிரங்கள், கடிகாரம் அல்லது ஆடைகளை அகற்றவும்.',
        'காயத்தை வெட்ட வேண்டாம், நச்சை உறிஞ்ச வேண்டாம், பனிக்கட்டி வைக்க வேண்டாம்.',
        'இறுக்கமான டோர்னிக்கெட் கட்ட வேண்டாம் - கடிக்கு மேல் தளர்வான கட்டு பாதுகாப்பானது.',
        'உடனடியாக மருத்துவமனைக்குச் செல்லுங்கள் - ஒவ்வொரு பாம்பு கடிக்கும் உண்மையான மருத்துவ சிகிச்சை தேவை.',
      ],
      warning: 'உடனடியாக 108-ஐ அழைக்கவும் அல்லது மருத்துவமனைக்குச் செல்லவும். பாதுகாப்பாக இருந்தால் பாம்பின் நிறம் மற்றும் வடிவத்தை நினைவில் கொள்ள முயற்சிக்கவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'పాము కాటు',
      steps: [
        'వ్యక్తిని ప్రశాంతంగా మరియు కదలకుండా ఉంచండి - కదలడం విషం వేగంగా వ్యాపించేలా చేస్తుంది.',
        'వీలైతే కరిచిన అవయవాన్ని గుండె కంటే కిందకు ఉంచండి.',
        'వాపు మొదలయ్యే ముందు దగ్గరలోని బిగుతైన ఉంగరాలు, వాచీలు లేదా బట్టలు తీసివేయండి.',
        'గాయాన్ని కోయవద్దు, విషాన్ని పీల్చవద్దు, మంచు వేయవద్దు.',
        'బిగుతైన టోర్నికెట్ కట్టవద్దు - కాటుకు పైన వదులుగా ఉన్న కట్టు సురక్షితం.',
        'వెంటనే ఆసుపత్రికి వెళ్లండి - ప్రతి పాము కాటుకు నిజమైన వైద్య చికిత్స అవసరం.',
      ],
      warning: 'వెంటనే 108కి కాల్ చేయండి లేదా ఆసుపత్రికి వెళ్లండి. సురక్షితమైతే పాము రంగు మరియు ఆకారాన్ని గుర్తుంచుకోవడానికి ప్రయత్నించండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'सापाचा दंश',
      steps: [
        'व्यक्तीला शांत आणि स्थिर ठेवा - हालचालीमुळे विष वेगाने पसरते.',
        'शक्य असल्यास चावलेला अवयव हृदयापेक्षा खाली ठेवा.',
        'सूज येण्यापूर्वी जवळची घट्ट अंगठी, घड्याळ किंवा कपडे काढा.',
        'जखम कापू नका, विष शोषण्याचा प्रयत्न करू नका, बर्फ लावू नका.',
        'घट्ट टूर्निकेट बांधू नका - दंशाच्या वर सैल पट्टी बांधणे सुरक्षित आहे.',
        'ताबडतोब रुग्णालयात जा - प्रत्येक सापाच्या दंशाला खरी वैद्यकीय काळजी लागते.',
      ],
      warning: 'ताबडतोब 108 वर कॉल करा किंवा रुग्णालयात जा. सुरक्षित असल्यास सापाचा रंग आणि आकार लक्षात ठेवण्याचा प्रयत्न करा.',
    ),
  },
  'heavyBleeding': {
    'en': FirstAidTranslation(
      title: 'Heavy Bleeding',
      steps: [
        'Press down firmly on the wound with a clean cloth or your hand.',
        'Keep pressing without lifting the cloth to check - this stops the bleeding.',
        'If possible, raise the injured part above heart level.',
        'Add more cloth on top if it soaks through - do not remove the first layer.',
        'Keep the person warm and lying down.',
      ],
      warning: 'If bleeding does not stop after several minutes of firm pressure, call 108 immediately.',
    ),
    'hi': FirstAidTranslation(
      title: 'तेज़ रक्तस्राव',
      steps: [
        'साफ कपड़े या अपने हाथ से घाव पर मज़बूती से दबाव डालें।',
        'देखने के लिए कपड़ा न हटाएं, दबाव बनाए रखें - इससे खून बहना रुकता है।',
        'यदि संभव हो, घायल हिस्से को दिल के स्तर से ऊपर उठाएं।',
        'अगर कपड़ा भीग जाए तो ऊपर और कपड़ा डालें - पहली परत न हटाएं।',
        'व्यक्ति को गर्म रखें और लिटा दें।',
      ],
      warning: 'यदि कई मिनट तक मज़बूत दबाव के बाद भी खून बहना नहीं रुकता, तो तुरंत 108 पर कॉल करें।',
    ),
    'ta': FirstAidTranslation(
      title: 'கடுமையான இரத்தப்போக்கு',
      steps: [
        'சுத்தமான துணி அல்லது உங்கள் கையால் காயத்தின் மீது உறுதியாக அழுத்தவும்.',
        'பார்க்க துணியை எடுக்காமல் அழுத்தத்தைத் தொடரவும் - இது இரத்தப்போக்கை நிறுத்தும்.',
        'முடிந்தால், காயமடைந்த பகுதியை இதய அளவிற்கு மேலே உயர்த்தவும்.',
        'துணி நனைந்தால் மேலும் துணியைச் சேர்க்கவும் - முதல் அடுக்கை அகற்ற வேண்டாம்.',
        'நபரை சூடாகவும் படுத்தும் நிலையிலும் வைத்திருங்கள்.',
      ],
      warning: 'பல நிமிடங்கள் உறுதியான அழுத்தத்திற்குப் பிறகும் இரத்தப்போக்கு நிற்கவில்லை என்றால், உடனடியாக 108-ஐ அழைக்கவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'తీవ్ర రక్తస్రావం',
      steps: [
        'శుభ్రమైన గుడ్డతో లేదా మీ చేతితో గాయంపై గట్టిగా నొక్కండి.',
        'చూడటానికి గుడ్డను తీయకుండా నొక్కడం కొనసాగించండి - దీనితో రక్తస్రావం ఆగుతుంది.',
        'వీలైతే, గాయమైన భాగాన్ని గుండె స్థాయి కంటే పైకి లేపండి.',
        'గుడ్డ తడిస్తే మరింత గుడ్డను పైన వేయండి - మొదటి పొరను తీయవద్దు.',
        'వ్యక్తిని వెచ్చగా మరియు పడుకున్న స్థితిలో ఉంచండి.',
      ],
      warning: 'చాలా నిమిషాలు గట్టిగా నొక్కిన తర్వాత కూడా రక్తస్రావం ఆగకపోతే, వెంటనే 108కి కాల్ చేయండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'जास्त रक्तस्त्राव',
      steps: [
        'स्वच्छ कापड किंवा आपल्या हाताने जखमेवर घट्ट दाब द्या.',
        'बघण्यासाठी कापड न काढता दाब कायम ठेवा - यामुळे रक्तस्त्राव थांबतो.',
        'शक्य असल्यास, जखमी भाग हृदयाच्या पातळीपेक्षा वर उचला.',
        'कापड भिजल्यास वर आणखी कापड घाला - पहिला थर काढू नका.',
        'व्यक्तीला उबदार ठेवा आणि झोपवा.',
      ],
      warning: 'अनेक मिनिटे घट्ट दाब दिल्यानंतरही रक्तस्त्राव थांबत नसेल, तर ताबडतोब 108 वर कॉल करा.',
    ),
  },
  'burns': {
    'en': FirstAidTranslation(
      title: 'Burns',
      steps: [
        'Cool the burn under clean, cool (not ice-cold) running water for 10-20 minutes.',
        'Remove tight clothing or jewelry near the burn before it swells.',
        'Do NOT apply ice, butter, oil, or toothpaste to the burn.',
        'Cover loosely with a clean, dry cloth - do not use cotton wool.',
        'Do NOT pop any blisters that form.',
      ],
      warning: 'For large burns, burns on the face/hands, or if the skin looks white or charred, get to a hospital immediately.',
    ),
    'hi': FirstAidTranslation(
      title: 'जलना',
      steps: [
        'जले हुए हिस्से को साफ, ठंडे (बर्फ जैसे ठंडे नहीं) बहते पानी के नीचे 10-20 मिनट तक रखें।',
        'सूजन आने से पहले जलन के पास के तंग कपड़े या गहने हटा दें।',
        'जलन पर बर्फ, मक्खन, तेल या टूथपेस्ट न लगाएं।',
        'साफ, सूखे कपड़े से हल्के से ढकें - रूई का उपयोग न करें।',
        'बनने वाले किसी भी छाले को न फोड़ें।',
      ],
      warning: 'बड़ी जलन, चेहरे/हाथों पर जलन, या यदि त्वचा सफेद या जली हुई दिखे, तो तुरंत अस्पताल जाएं।',
    ),
    'ta': FirstAidTranslation(
      title: 'தீக்காயங்கள்',
      steps: [
        'சுத்தமான, குளிர்ந்த (பனிக்கட்டி போல் இல்லாத) ஓடும் நீரின் கீழ் 10-20 நிமிடங்கள் தீக்காயத்தை குளிர்விக்கவும்.',
        'வீக்கம் வருவதற்கு முன் தீக்காயத்திற்கு அருகில் உள்ள இறுக்கமான ஆடை அல்லது நகைகளை அகற்றவும்.',
        'தீக்காயத்தில் பனிக்கட்டி, வெண்ணெய், எண்ணெய் அல்லது பற்பசை தேவையில்லை.',
        'சுத்தமான, உலர்ந்த துணியால் தளர்வாக மூடவும் - பஞ்சு பயன்படுத்த வேண்டாம்.',
        'உருவாகும் கொப்புளங்களை உடைக்க வேண்டாம்.',
      ],
      warning: 'பெரிய தீக்காயங்கள், முகம்/கைகளில் தீக்காயம், அல்லது தோல் வெண்மையாக அல்லது கருகியதாகத் தெரிந்தால், உடனடியாக மருத்துவமனைக்குச் செல்லவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'కాలిన గాయాలు',
      steps: [
        'శుభ్రమైన, చల్లని (మంచు చల్లని కాదు) ప్రవహించే నీటి కింద 10-20 నిమిషాలు కాలిన గాయాన్ని చల్లబరచండి.',
        'వాపు రాకముందే కాలిన గాయం దగ్గర బిగుతైన బట్టలు లేదా నగలు తీసివేయండి.',
        'కాలిన గాయంపై మంచు, వెన్న, నూనె లేదా టూత్‌పేస్ట్ వేయవద్దు.',
        'శుభ్రమైన, పొడి గుడ్డతో వదులుగా కప్పండి - దూదిని ఉపయోగించవద్దు.',
        'ఏర్పడిన బొబ్బలను పగలగొట్టవద్దు.',
      ],
      warning: 'పెద్ద కాలిన గాయాలు, ముఖం/చేతులపై కాలిన గాయాలు, లేదా చర్మం తెల్లగా లేదా కాలిపోయినట్లు కనిపిస్తే, వెంటనే ఆసుపత్రికి వెళ్లండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'भाजणे',
      steps: [
        'स्वच्छ, थंड (बर्फासारखे नाही) वाहत्या पाण्याखाली भाजलेला भाग 10-20 मिनिटे थंड करा.',
        'सूज येण्यापूर्वी भाजलेल्या जागेजवळचे घट्ट कपडे किंवा दागिने काढा.',
        'भाजलेल्या जागेवर बर्फ, लोणी, तेल किंवा टूथपेस्ट लावू नका.',
        'स्वच्छ, कोरड्या कापडाने सैलपणे झाका - कापूस वापरू नका.',
        'तयार झालेले फोड फोडू नका.',
      ],
      warning: 'मोठे भाजणे, चेहरा/हातांवर भाजणे, किंवा त्वचा पांढरी किंवा करपलेली दिसत असल्यास, ताबडतोब रुग्णालयात जा.',
    ),
  },
  'choking': {
    'en': FirstAidTranslation(
      title: 'Choking',
      steps: [
        'Ask "Are you choking?" - if they can cough or speak, let them keep coughing.',
        'If they cannot breathe, cough, or speak: stand behind them, lean them forward.',
        'Give 5 sharp back blows between the shoulder blades with the heel of your hand.',
        'If that doesn\'t work, give 5 quick abdominal thrusts (fist above navel, pull inward and up).',
        'Repeat back blows and abdominal thrusts until the object comes out or help arrives.',
      ],
      warning: 'If the person becomes unconscious, call 108 immediately and start CPR if you know how.',
    ),
    'hi': FirstAidTranslation(
      title: 'दम घुटना',
      steps: [
        '"क्या आपका दम घुट रहा है?" पूछें - अगर वे खांस या बोल सकते हैं, तो उन्हें खांसने दें।',
        'अगर वे सांस, खांसी या बोल नहीं पा रहे: उनके पीछे खड़े हों, उन्हें आगे झुकाएं।',
        'अपने हाथ की एड़ी से कंधे की हड्डियों के बीच 5 तेज़ थपकी दें।',
        'अगर यह काम न करे, तो 5 त्वरित पेट पर धक्के दें (नाभि के ऊपर मुट्ठी, अंदर और ऊपर खींचें)।',
        'वस्तु बाहर आने या मदद आने तक थपकी और धक्के दोहराते रहें।',
      ],
      warning: 'यदि व्यक्ति बेहोश हो जाए, तो तुरंत 108 पर कॉल करें और यदि आपको आता हो तो सीपीआर शुरू करें।',
    ),
    'ta': FirstAidTranslation(
      title: 'மூச்சுத் திணறல்',
      steps: [
        '"உங்களுக்கு மூச்சுத் திணறுகிறதா?" எனக் கேளுங்கள் - இருமலாம் அல்லது பேசலாம் என்றால், இருமட்டும்.',
        'மூச்சு விட, இருமல் அல்லது பேச முடியவில்லை என்றால்: பின்னால் நின்று, முன்னோக்கி சாய்க்கவும்.',
        'உங்கள் உள்ளங்கையால் தோள்பட்டைகளுக்கு இடையே 5 கடுமையான தட்டல்களைக் கொடுங்கள்.',
        'அது வேலை செய்யவில்லை என்றால், 5 விரைவான வயிற்று உந்துதல்களைக் கொடுங்கள் (தொப்புளுக்கு மேல் முஷ்டி, உள்ளே மற்றும் மேலே இழுக்கவும்).',
        'பொருள் வெளியே வரும் வரை அல்லது உதவி வரும் வரை தட்டல்கள் மற்றும் உந்துதல்களை மீண்டும் செய்யவும்.',
      ],
      warning: 'நபர் மயங்கிவிட்டால், உடனடியாக 108-ஐ அழைக்கவும், உங்களுக்குத் தெரிந்தால் சிபிஆர் தொடங்கவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'ఊపిరాడకపోవడం',
      steps: [
        '"మీకు ఊపిరాడటం లేదా?" అని అడగండి - దగ్గగలిగితే లేదా మాట్లాడగలిగితే, దగ్గనివ్వండి.',
        'శ్వాస తీసుకోలేకపోతే, దగ్గలేకపోతే, మాట్లాడలేకపోతే: వెనుక నిలబడి, ముందుకు వంచండి.',
        'మీ చేతి అరచేతితో భుజం ఎముకల మధ్య 5 బలమైన వెన్ను దెబ్బలు ఇవ్వండి.',
        'అది పనిచేయకపోతే, 5 వేగవంతమైన కడుపు నెట్టివేతలు ఇవ్వండి (బొడ్డు పైన పిడికిలి, లోపలికి మరియు పైకి లాగండి).',
        'వస్తువు బయటకు వచ్చేవరకు లేదా సహాయం వచ్చేవరకు దెబ్బలు మరియు నెట్టివేతలను పునరావృతం చేయండి.',
      ],
      warning: 'వ్యక్తి స్పృహ కోల్పోతే, వెంటనే 108కి కాల్ చేసి, మీకు తెలిస్తే సీపీఆర్ ప్రారంభించండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'गुदमरणे',
      steps: [
        '"तुमचा श्वास कोंडतोय का?" विचारा - खोकू किंवा बोलू शकत असल्यास, खोकू द्या.',
        'श्वास घेता येत नसेल, खोकता किंवा बोलता येत नसेल तर: मागे उभे राहा, पुढे वाकवा.',
        'तुमच्या हाताच्या तळव्याने खांद्याच्या हाडांमध्ये 5 जोरदार फटके द्या.',
        'ते काम करत नसेल तर, 5 जलद पोटावर धक्के द्या (नाभीच्या वर मूठ, आत आणि वर खेचा).',
        'वस्तू बाहेर येईपर्यंत किंवा मदत येईपर्यंत फटके आणि धक्के पुन्हा करा.',
      ],
      warning: 'व्यक्ती बेशुद्ध झाल्यास, ताबडतोब 108 वर कॉल करा आणि तुम्हाला येत असल्यास सीपीआर सुरू करा.',
    ),
  },
  'heatStroke': {
    'en': FirstAidTranslation(
      title: 'Heat Stroke',
      steps: [
        'Move the person to shade or a cool place immediately.',
        'Remove excess clothing.',
        'Cool the body with wet cloths, fanning, or a cool (not ice) bath if available.',
        'Give small sips of water only if the person is fully awake and able to swallow.',
        'Do NOT give water if they are confused, drowsy, or vomiting.',
      ],
      warning: 'Heat stroke can be fatal within hours. If confusion, high fever, or loss of consciousness occurs, call 108 now.',
    ),
    'hi': FirstAidTranslation(
      title: 'लू लगना',
      steps: [
        'व्यक्ति को तुरंत छाया या ठंडी जगह पर ले जाएं।',
        'अतिरिक्त कपड़े हटा दें।',
        'शरीर को गीले कपड़ों, पंखे या ठंडे (बर्फ नहीं) स्नान से ठंडा करें।',
        'यदि व्यक्ति पूरी तरह से जाग रहा है और निगल सकता है तभी थोड़ा पानी दें।',
        'यदि वे भ्रमित, नींद में या उल्टी कर रहे हों तो पानी न दें।',
      ],
      warning: 'लू घंटों में जानलेवा हो सकती है। यदि भ्रम, तेज़ बुखार या बेहोशी हो, तो अभी 108 पर कॉल करें।',
    ),
    'ta': FirstAidTranslation(
      title: 'வெப்ப அடி',
      steps: [
        'நபரை உடனடியாக நிழல் அல்லது குளிர்ந்த இடத்திற்கு நகர்த்தவும்.',
        'அதிகப்படியான ஆடைகளை அகற்றவும்.',
        'ஈரமான துணிகள், விசிறி, அல்லது குளிர்ந்த (பனிக்கட்டி இல்லாத) குளியல் மூலம் உடலைக் குளிர்விக்கவும்.',
        'நபர் முழுமையாக விழிப்புடன் இருந்து விழுங்க முடிந்தால் மட்டும் சிறிது தண்ணீர் கொடுக்கவும்.',
        'குழப்பம், தூக்கம் அல்லது வாந்தி இருந்தால் தண்ணீர் கொடுக்க வேண்டாம்.',
      ],
      warning: 'வெப்ப அடி மணிநேரங்களில் உயிரிழப்பை ஏற்படுத்தலாம். குழப்பம், அதிக காய்ச்சல் அல்லது மயக்கம் ஏற்பட்டால், இப்போதே 108-ஐ அழைக்கவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'హీట్ స్ట్రోక్',
      steps: [
        'వ్యక్తిని వెంటనే నీడకు లేదా చల్లని ప్రదేశానికి తరలించండి.',
        'అదనపు బట్టలు తీసివేయండి.',
        'తడి గుడ్డలు, ఫ్యానింగ్, లేదా చల్లని (మంచు కాదు) స్నానంతో శరీరాన్ని చల్లబరచండి.',
        'వ్యక్తి పూర్తిగా మేల్కొని మింగగలిగితే మాత్రమే కొద్దిగా నీరు ఇవ్వండి.',
        'గందరగోళంగా, నిద్రమత్తుగా లేదా వాంతులు అవుతుంటే నీరు ఇవ్వవద్దు.',
      ],
      warning: 'హీట్ స్ట్రోక్ గంటల్లో ప్రాణాంతకం కావచ్చు. గందరగోళం, అధిక జ్వరం లేదా స్పృహ కోల్పోవడం జరిగితే, ఇప్పుడే 108కి కాల్ చేయండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'उष्माघात',
      steps: [
        'व्यक्तीला ताबडतोब सावलीत किंवा थंड ठिकाणी हलवा.',
        'जास्तीचे कपडे काढा.',
        'ओले कापड, पंखा, किंवा थंड (बर्फ नाही) आंघोळीने शरीर थंड करा.',
        'व्यक्ती पूर्णपणे जागृत असेल आणि गिळू शकत असेल तरच थोडे पाणी द्या.',
        'ती गोंधळलेली, झोपाळू किंवा उलट्या करत असेल तर पाणी देऊ नका.',
      ],
      warning: 'उष्माघात काही तासांत जीवघेणा ठरू शकतो. गोंधळ, तीव्र ताप किंवा बेशुद्धी आल्यास, आत्ताच 108 वर कॉल करा.',
    ),
  },
  'boneInjury': {
    'en': FirstAidTranslation(
      title: 'Bone Injury',
      steps: [
        'Keep the injured area still - do not try to straighten or push the bone back.',
        'Support the area above and below the injury with a splint (a stick, rolled cloth, or board) if you must move them.',
        'Apply a cold pack wrapped in cloth to reduce swelling - never directly on skin.',
        'Do not let the person walk on or use the injured limb.',
        'Keep them still and get medical help.',
      ],
      warning: 'If the bone is visibly out of place, pierces the skin, or the person cannot feel/move the limb, call 108 immediately.',
    ),
    'hi': FirstAidTranslation(
      title: 'हड्डी की चोट',
      steps: [
        'घायल हिस्से को स्थिर रखें - हड्डी को सीधा करने या वापस धकेलने की कोशिश न करें।',
        'यदि हिलाना ज़रूरी हो, तो चोट के ऊपर और नीचे के हिस्से को स्प्लिंट (डंडा, लपेटा हुआ कपड़ा, या तख्ती) से सहारा दें।',
        'सूजन कम करने के लिए कपड़े में लपेटा हुआ ठंडा पैक लगाएं - सीधे त्वचा पर कभी न लगाएं।',
        'व्यक्ति को घायल अंग पर चलने या उपयोग करने न दें।',
        'उन्हें स्थिर रखें और चिकित्सा सहायता लें।',
      ],
      warning: 'यदि हड्डी स्पष्ट रूप से अपनी जगह से हट गई हो, त्वचा को छेद रही हो, या व्यक्ति अंग को महसूस/हिला नहीं पा रहा हो, तो तुरंत 108 पर कॉल करें।',
    ),
    'ta': FirstAidTranslation(
      title: 'எலும்பு காயம்',
      steps: [
        'காயமடைந்த பகுதியை அசைக்காமல் வைத்திருங்கள் - எலும்பை நேராக்க அல்லது தள்ள முயற்சிக்க வேண்டாம்.',
        'நகர்த்த வேண்டியிருந்தால், காயத்திற்கு மேலேயும் கீழேயும் உள்ள பகுதியை ஸ்பிளிண்ட் (குச்சி, சுருட்டப்பட்ட துணி, அல்லது பலகை) மூலம் ஆதரிக்கவும்.',
        'வீக்கத்தைக் குறைக்க துணியில் சுற்றப்பட்ட குளிர் பொதியை பயன்படுத்தவும் - நேரடியாக தோலில் இல்லை.',
        'காயமடைந்த உறுப்பில் நபரை நடக்க அல்லது பயன்படுத்த விட வேண்டாம்.',
        'அவர்களை அசையாமல் வைத்து மருத்துவ உதவியைப் பெறவும்.',
      ],
      warning: 'எலும்பு வெளிப்படையாக இடம் மாறியிருந்தால், தோலைத் துளைத்திருந்தால், அல்லது நபர் உறுப்பை உணரவோ அசைக்கவோ முடியவில்லை என்றால், உடனடியாக 108-ஐ அழைக்கவும்.',
    ),
    'te': FirstAidTranslation(
      title: 'ఎముక గాయం',
      steps: [
        'గాయమైన ప్రాంతాన్ని కదలకుండా ఉంచండి - ఎముకను నేరుగా చేయడానికి లేదా వెనక్కి నెట్టడానికి ప్రయత్నించవద్దు.',
        'కదిలించవలసి వస్తే, గాయానికి పైన మరియు కింద ఉన్న ప్రాంతాన్ని స్ప్లింట్ (కర్ర, చుట్టిన గుడ్డ, లేదా బోర్డు)తో ఆధారం ఇవ్వండి.',
        'వాపు తగ్గించడానికి గుడ్డలో చుట్టిన చల్లని ప్యాక్‌ను ఉపయోగించండి - నేరుగా చర్మంపై వేయవద్దు.',
        'గాయమైన అవయవంపై వ్యక్తిని నడవనివ్వవద్దు లేదా ఉపయోగించనివ్వవద్దు.',
        'వారిని కదలకుండా ఉంచి వైద్య సహాయం పొందండి.',
      ],
      warning: 'ఎముక కనిపించేలా స్థానభ్రంశం చెందితే, చర్మాన్ని చీల్చుకుంటే, లేదా వ్యక్తి అవయవాన్ని అనుభూతి చెందలేకపోతే/కదిలించలేకపోతే, వెంటనే 108కి కాల్ చేయండి.',
    ),
    'mr': FirstAidTranslation(
      title: 'हाडाची दुखापत',
      steps: [
        'जखमी भाग स्थिर ठेवा - हाड सरळ करण्याचा किंवा मागे ढकलण्याचा प्रयत्न करू नका.',
        'हलवावे लागल्यास, दुखापतीच्या वर आणि खालच्या भागाला स्प्लिंट (काठी, गुंडाळलेले कापड, किंवा फळी) ने आधार द्या.',
        'सूज कमी करण्यासाठी कापडात गुंडाळलेला थंड पॅक लावा - थेट त्वचेवर कधीही नाही.',
        'व्यक्तीला जखमी अवयवावर चालू देऊ नका किंवा वापरू देऊ नका.',
        'त्यांना स्थिर ठेवा आणि वैद्यकीय मदत घ्या.',
      ],
      warning: 'हाड स्पष्टपणे जागेवरून सरकले असेल, त्वचा फाटली असेल, किंवा व्यक्तीला अवयव जाणवत/हलवता येत नसेल, तर ताबडतोब 108 वर कॉल करा.',
    ),
  },
};

String uiLabel(String key, String languageCode) =>
    kUiLabels[key]?[languageCode] ?? kUiLabels[key]?['en'] ?? key;
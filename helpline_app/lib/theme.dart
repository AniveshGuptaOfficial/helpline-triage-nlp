import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFF0F6B66); // deep teal
const Color kPrimaryLight = Color(0xFFE6F2F1);
const Color kBackground = Color(0xFFFAFAF8);
const Color kEmergency = Color(0xFFD64545);
// Swapped from the original build to match the Vaidyum mockups: Medicine
// Query reads as teal/green there, Appointment reads as amber/orange.
// categoryColor()/categoryIcon() below are unchanged in shape, only the
// two hex values moved, so every screen that already calls them (chat
// banner, history list, stats legend) picks up the mockup palette
// automatically without needing its own edits.
const Color kMedicine = Color(0xFF0F6B66);
const Color kAppointment = Color(0xFFC98A2C);
const Color kNeutral = Color(0xFF8A8A8A);

// --- Added for the card-style Emergency / Medicine Query answer UI,
// the hospital finder, stats donut, and profile screens. Purely additive
// constants - nothing above this line changed in meaning, only the two
// hex values noted above. ---
const Color kEmergencyBg = Color(0xFFFDEAEA); // Emergency alert card background
const Color kEmergencyBorder = Color(0xFFF6C9C9);
const Color kDistressPillBg = Color(0xFFFCE0E0); // "HIGH DISTRESS" pill
const Color kWarningText = Color(0xFFB4791F); // disclaimer / warning copy
const Color kWarningBg = Color(0xFFFCF3E3);
const Color kRatingStar = Color(0xFFC98A2C);
const Color kCardBorder = Color(0xFFE7E7E2);
const Color kDonutTrack = Color(0xFFEFEFEA);

/// The five in-app helpline response languages shown on the Profile screen
/// and the quick language switcher on the chat screen.
const List<({String english, String native, String code})> kSupportedLanguages = [
  (english: 'Hindi', native: 'हिंदी', code: 'hi'),
  (english: 'English', native: 'English', code: 'en'),
  (english: 'Tamil', native: 'தமிழ்', code: 'ta'),
  (english: 'Telugu', native: 'తెలుగు', code: 'te'),
  (english: 'Marathi', native: 'मराठी', code: 'mr'),
];

// --- Shared SharedPreferences keys. Centralized here (rather than defined
// separately per screen) so both the Profile screen and the chat screen's
// quick language switcher read/write the exact same stored value. ---
const String kLanguagePrefKey = 'vaidyum_helpline_language_code';
const String kEmergencyContactsPrefKey = 'vaidyum_emergency_contacts';

// --- Low-literacy / visual-first sizing constants. Used across chat
// bubbles, answer cards, the bottom nav, and emergency actions so text and
// tap targets are consistently larger than typical default Material
// sizing - purely additive, existing call sites are updated to use these
// instead of their old inline literals. ---
const double kFontBody = 17.0; // chat bubble / answer card body text
const double kFontLabel = 13.5; // badges, pills, secondary labels
const double kFontLarge = 19.0; // emergency headlines, large buttons
const double kMinTapTarget = 48.0; // minimum comfortable tap target height

Color categoryColor(String? category) {
  switch (category) {
    case 'Emergency':
      return kEmergency;
    case 'Medicine Query':
      return kMedicine;
    case 'Appointment':
      return kAppointment;
    default:
      return kNeutral;
  }
}

IconData categoryIcon(String? category) {
  switch (category) {
    case 'Emergency':
      return Icons.emergency_rounded;
    case 'Medicine Query':
      return Icons.medical_information_rounded;
    case 'Appointment':
      return Icons.event_available_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}

/// Light background tint for a category badge/chip - the solid
/// categoryColor() is used for text/icon, this is used for the pill fill.
Color categoryColorLight(String? category) {
  switch (category) {
    case 'Emergency':
      return kEmergencyBg;
    case 'Medicine Query':
      return kPrimaryLight;
    case 'Appointment':
      return const Color(0xFFF6ECD9);
    default:
      return const Color(0xFFF0F0EC);
  }
}
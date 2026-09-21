// PHASE 4 - TOP-DOWN FLUTTER TESTING, unit layer
//
// Plain Dart unit tests for the localization/theming helpers in
// vaidyum_strings.dart and theme.dart. Not executed in this sandbox
// (no Flutter/Dart SDK available here) - run with:
//   cd helpline_app
//   flutter test test/unit/vaidyum_strings_test.dart
//
// COPY THIS FILE TO: helpline_app/test/unit/vaidyum_strings_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:helpline_app/localization/vaidyum_strings.dart';
import 'package:helpline_app/theme.dart';

void main() {
  group('uiLabel', () {
    test('returns the requested language when available', () {
      expect(uiLabel('hospitalsTitle', 'hi'), 'हेल्पलाइन अस्पताल');
    });

    test('falls back to English for an unsupported language code', () {
      expect(uiLabel('hospitalsTitle', 'fr'), uiLabel('hospitalsTitle', 'en'));
    });

    test('falls back to the raw key if the key itself does not exist', () {
      expect(uiLabel('thisKeyDoesNotExist', 'en'), 'thisKeyDoesNotExist');
    });
  });

  group('SymptomOption', () {
    test('phraseFor returns the requested language', () {
      const option = SymptomOption(
        emoji: '🆘',
        intent: 'sos',
        phrasesByLanguage: {'en': 'I need more help', 'hi': 'मुझे और मदद चाहिए'},
      );
      expect(option.phraseFor('hi'), 'मुझे और मदद चाहिए');
    });

    test('phraseFor falls back to English for a missing language', () {
      const option = SymptomOption(
        emoji: '🆘',
        intent: 'sos',
        phrasesByLanguage: {'en': 'I need more help'},
      );
      expect(option.phraseFor('ta'), 'I need more help');
    });

    test('the SOS chip in kFollowUpOptions carries intent "sos"', () {
      final sosOption = kFollowUpOptions.firstWhere((o) => o.emoji == '🆘');
      expect(sosOption.intent, 'sos');
      expect(sosOption.phraseFor('en'), 'I need more help');
    });

    test('non-SOS follow-up chips have no forced intent', () {
      final otherOptions = kFollowUpOptions.where((o) => o.emoji != '🆘');
      for (final option in otherOptions) {
        expect(option.intent, isNull,
            reason: '${option.phraseFor('en')} should rely on normal '
                'classification, not force an outcome');
      }
    });

    test('quick-symptom chips (kQuickSymptoms) never carry an intent tag', () {
      // Only follow-up chips should ever force server-side behavior -
      // the initial symptom chips are just pre-filled queries.
      for (final option in kQuickSymptoms) {
        expect(option.intent, isNull);
      }
    });
  });

  group('categoryColor', () {
    test('Emergency maps to kEmergency', () {
      expect(categoryColor('Emergency'), kEmergency);
    });

    test('Medicine Query maps to kMedicine', () {
      expect(categoryColor('Medicine Query'), kMedicine);
    });

    test('Appointment maps to kAppointment', () {
      expect(categoryColor('Appointment'), kAppointment);
    });

    test('null or unknown category maps to kNeutral', () {
      expect(categoryColor(null), kNeutral);
      expect(categoryColor('something else entirely'), kNeutral);
    });
  });
}
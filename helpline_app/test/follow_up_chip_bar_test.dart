// PHASE 4 - TOP-DOWN FLUTTER TESTING, widget layer
//
// This is the actual regression test for the SOS-chip bug fixed
// earlier: tapping the SOS chip must invoke the callback with
// intent: 'sos', while every other follow-up chip must invoke it with
// intent: null (relying on normal server-side classification instead
// of forcing an outcome).
//
// NOT executed in this sandbox (no Flutter/Dart SDK available) - run
// with:
//   cd helpline_app
//   flutter test test/widget/follow_up_chip_bar_test.dart
//
// COPY THIS FILE TO: helpline_app/test/widget/follow_up_chip_bar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helpline_app/widgets/follow_up_chip_bar.dart';
import 'package:helpline_app/localization/vaidyum_strings.dart';

void main() {
  Future<void> pumpChipBar(
    WidgetTester tester, {
    required void Function(String, {String? intent}) onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowUpChipBar(
            languageCode: 'en',
            category: 'Medicine Query',
            onFollowUpSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the SOS chip calls back with intent "sos"', (tester) async {
    String? capturedPhrase;
    String? capturedIntent;

    await pumpChipBar(
      tester,
      onSelected: (phrase, {intent}) {
        capturedPhrase = phrase;
        capturedIntent = intent;
      },
    );

    final sosOption = kFollowUpOptions.firstWhere((o) => o.emoji == '🆘');
    final sosPhrase = sosOption.phraseFor('en');

    expect(find.text(sosPhrase), findsOneWidget,
        reason: 'the SOS chip should render its English phrase as visible text');

    await tester.tap(find.text(sosPhrase));
    await tester.pump();

    expect(capturedPhrase, sosPhrase);
    expect(capturedIntent, 'sos',
        reason: 'this is the actual fix under test - the SOS tap must carry '
            'an explicit intent so the backend can force Emergency treatment '
            'even though the phrase itself ("I need more help") has no '
            'red-flag keywords on its own');
  });

  testWidgets('tapping a non-SOS chip calls back with intent null', (tester) async {
    String? capturedIntent = 'not-yet-set';

    await pumpChipBar(
      tester,
      onSelected: (phrase, {intent}) {
        capturedIntent = intent;
      },
    );

    final nonSosOption = kFollowUpOptions.firstWhere((o) => o.emoji != '🆘');
    final phrase = nonSosOption.phraseFor('en');

    await tester.tap(find.text(phrase));
    await tester.pump();

    expect(capturedIntent, isNull,
        reason: 'only the SOS chip should force server-side behavior - other '
            'follow-ups must rely on normal classification/re-triage logic');
  });

  testWidgets('renders one chip per entry in kFollowUpOptions', (tester) async {
    await pumpChipBar(tester, onSelected: (phrase, {intent}) {});

    for (final option in kFollowUpOptions) {
      expect(find.text(option.phraseFor('en')), findsOneWidget);
    }
  });
}
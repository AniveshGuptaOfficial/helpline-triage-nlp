// PHASE 4 - TOP-DOWN FLUTTER TESTING, unit layer
//
// These are plain Dart unit tests (no widget tree needed) for the
// ChatMessage/Conversation model in conversation_store.dart. This is
// the lowest rung of the Top-Down side of the Sandwich strategy: before
// testing whether the chat screen uses these models correctly (the
// widget test below), first prove the models themselves round-trip
// correctly on their own.
//
// IMPORTANT: this file was written and statically reviewed (bracket
// balance, import paths, API shapes checked against the real source)
// but was NOT executed - the sandbox this was authored in has no
// Flutter/Dart SDK. Run it yourself with:
//   cd helpline_app
//   flutter test test/unit/chat_message_test.dart
// and report back anything that fails - a static review can catch
// syntax/shape mistakes but not everything a real compiler will.
//
// COPY THIS FILE TO: helpline_app/test/unit/chat_message_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:helpline_app/services/conversation_store.dart';

void main() {
  group('ChatMessage', () {
    test('toMap/fromMap round-trips a plain user message', () {
      final msg = ChatMessage(role: 'user', text: 'I have a headache');
      final restored = ChatMessage.fromMap(msg.toMap());
      expect(restored.role, 'user');
      expect(restored.text, 'I have a headache');
      expect(restored.category, isNull);
      expect(restored.confidence, isNull);
      expect(restored.distressScore, isNull);
    });

    test('toMap/fromMap round-trips a fully-populated Emergency reply', () {
      final msg = ChatMessage(
        role: 'model',
        text: 'This is an emergency. Call 108 now.',
        category: 'Emergency',
        confidence: null,
        distressScore: 0.87,
      );
      final map = msg.toMap();
      expect(map['category'], 'Emergency');
      expect(map['distressScore'], 0.87);
      expect(map.containsKey('confidence'), isFalse,
          reason: 'null fields should be omitted from the map, not stored as null');

      final restored = ChatMessage.fromMap(map);
      expect(restored.category, 'Emergency');
      expect(restored.distressScore, 0.87);
      expect(restored.confidence, isNull);
    });

    test('toMap/fromMap round-trips a Medicine Query reply with confidence', () {
      final msg = ChatMessage(
        role: 'model',
        text: 'Paracetamol is commonly used for headaches.',
        category: 'Medicine Query',
        confidence: 0.99,
      );
      final restored = ChatMessage.fromMap(msg.toMap());
      expect(restored.category, 'Medicine Query');
      expect(restored.confidence, 0.99);
    });

    test('fromMap handles legacy stored messages with no classification fields', () {
      // Simulates a message saved to Firestore before this feature existed -
      // must not throw, must produce null metadata rather than crashing.
      final legacy = {'role': 'model', 'text': 'an old reply'};
      final restored = ChatMessage.fromMap(legacy);
      expect(restored.text, 'an old reply');
      expect(restored.category, isNull);
    });
  });

  group('Conversation', () {
    test('toJson/fromJson round-trips messages with their own categories intact', () {
      final convo = Conversation(
        id: 'c1',
        title: 'Test conversation',
        category: 'Emergency',
        messages: [
          ChatMessage(role: 'user', text: 'severe chest pain'),
          ChatMessage(role: 'model', text: 'Call 108 now.', category: 'Emergency', distressScore: 0.9),
          ChatMessage(role: 'user', text: 'I need more help'),
          ChatMessage(role: 'model', text: 'Still an emergency.', category: 'Emergency', distressScore: 0.95),
        ],
        updatedAt: 123456,
      );

      final restored = Conversation.fromJson('c1', convo.toJson());

      expect(restored.messages.length, 4);
      // This is the actual regression test for the bug that was fixed:
      // each message must keep its OWN category after a save/reload
      // round-trip, not just whatever the conversation's overall
      // category happens to be.
      expect(restored.messages[1].category, 'Emergency');
      expect(restored.messages[3].category, 'Emergency');
      expect(restored.messages[3].distressScore, 0.95);
      expect(restored.messages[0].category, isNull,
          reason: 'user messages never carry a classification');
    });
  });
}
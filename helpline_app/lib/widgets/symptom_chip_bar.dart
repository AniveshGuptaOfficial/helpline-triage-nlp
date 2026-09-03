import 'package:flutter/material.dart';
import '../theme.dart';
import '../localization/vaidyum_strings.dart';

/// Large, icon-forward symptom chips shown when the chat is empty, so a
/// low-literacy or first-time user can start a conversation with one tap
/// instead of typing. Tapping a chip hands the fully-formed phrase (in the
/// currently selected helpline language) back to the caller, which sends
/// it exactly like a typed message - no new backend behavior involved.
class SymptomChipBar extends StatelessWidget {
  final String languageCode;
  final ValueChanged<String> onSymptomSelected;

  const SymptomChipBar({
    super.key,
    required this.languageCode,
    required this.onSymptomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: kQuickSymptoms.map((symptom) {
        final phrase = symptom.phraseFor(languageCode);
        return InkWell(
          onTap: () => onSymptomSelected(phrase),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(symptom.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    phrase,
                    style: const TextStyle(
                      fontSize: kFontLabel,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
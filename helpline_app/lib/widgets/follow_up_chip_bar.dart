import 'package:flutter/material.dart';
import '../theme.dart';
import '../localization/vaidyum_strings.dart';

/// Shown under the latest reply so the user can continue the SAME
/// conversation thread with one tap instead of typing a follow-up.
/// Color-matches the active category so it reads as part of that
/// conversation, not a generic/unrelated control.
class FollowUpChipBar extends StatelessWidget {
  final String languageCode;
  final String? category;
  final ValueChanged<String> onFollowUpSelected;

  const FollowUpChipBar({
    super.key,
    required this.languageCode,
    required this.category,
    required this.onFollowUpSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: kFollowUpOptions.map((option) {
          final phrase = option.phraseFor(languageCode);
          return InkWell(
            onTap: () => onFollowUpSelected(phrase),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    phrase,
                    style: TextStyle(
                      fontSize: kFontLabel,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
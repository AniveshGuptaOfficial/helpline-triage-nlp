import 'package:flutter/material.dart';
import '../theme.dart';

/// Compact horizontal language switcher for the chat screen itself, so
/// changing the helpline language doesn't require a trip to Profile.
/// Shares the same persisted preference (kLanguagePrefKey) that Profile's
/// full-detail language list reads and writes, so a change here is picked
/// up there too, and vice versa.
class LanguageSwitcherBar extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onLanguageSelected;

  const LanguageSwitcherBar({
    super.key,
    required this.selectedCode,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: kSupportedLanguages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final lang = kSupportedLanguages[i];
          final selected = lang.code == selectedCode;
          return InkWell(
            onTap: () => onLanguageSelected(lang.code),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? kPrimary : kCardBorder),
              ),
              child: Text(
                lang.english == lang.native ? lang.english : lang.native,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
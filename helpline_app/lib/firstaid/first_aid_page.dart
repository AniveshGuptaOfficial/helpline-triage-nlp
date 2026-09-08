import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/emergency_call_fab.dart';
import '../localization/vaidyum_strings.dart';

/// Maps each topic to its icon + the key used to look it up in
/// kFirstAidTranslations (see vaidyum_strings.dart) - the actual title,
/// steps, and warning text live there now, in all 5 languages, instead of
/// being hardcoded English here.
class _FirstAidTopicMeta {
  final IconData icon;
  final String translationKey;
  const _FirstAidTopicMeta({required this.icon, required this.translationKey});
}

const List<_FirstAidTopicMeta> _kFirstAidTopics = [
  _FirstAidTopicMeta(icon: Icons.pest_control_rounded, translationKey: 'snakeBite'),
  _FirstAidTopicMeta(icon: Icons.bloodtype_rounded, translationKey: 'heavyBleeding'),
  _FirstAidTopicMeta(icon: Icons.local_fire_department_rounded, translationKey: 'burns'),
  _FirstAidTopicMeta(icon: Icons.air_rounded, translationKey: 'choking'),
  _FirstAidTopicMeta(icon: Icons.wb_sunny_rounded, translationKey: 'heatStroke'),
  _FirstAidTopicMeta(icon: Icons.accessibility_new_rounded, translationKey: 'boneInjury'),
];

/// Looks up a topic's translation for the given language, falling back to
/// English if that language somehow isn't covered for this key.
FirstAidTranslation _translationFor(String topicKey, String languageCode) {
  final byLanguage = kFirstAidTranslations[topicKey]!;
  return byLanguage[languageCode] ?? byLanguage['en']!;
}

class FirstAidPage extends StatefulWidget {
  const FirstAidPage({super.key});

  @override
  State<FirstAidPage> createState() => _FirstAidPageState();
}

class _FirstAidPageState extends State<FirstAidPage> {
  String _languageCode = 'en';

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(uiLabel('firstAidTitle', _languageCode),
                style: const TextStyle(
                    color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(uiLabel('firstAidSubtitle', _languageCode),
                style: const TextStyle(fontSize: 12, color: kNeutral)),
          ],
        ),
      ),
      body: ListView(
        // Extra bottom padding so the last card can't end up hidden under
        // the floating Call 108 button - it floats over scrollable
        // content by design, so the list needs to reserve room for it.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.offline_bolt_rounded, color: kPrimary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uiLabel('firstAidOfflineNote', _languageCode),
                    style: const TextStyle(fontSize: 12.5, color: kPrimary),
                  ),
                ),
              ],
            ),
          ),
          ..._kFirstAidTopics.map((meta) {
            final translation = _translationFor(meta.translationKey, _languageCode);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kCardBorder),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FirstAidDetailPage(icon: meta.icon, translation: translation),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: kEmergencyBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(meta.icon, color: kEmergency, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          translation.title,
                          style: const TextStyle(
                              fontSize: kFontLarge, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: kNeutral, size: 28),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: const EmergencyCallFab(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

/// Step-by-step detail view for one First Aid topic - big icon, numbered
/// steps in large text, and a highlighted warning line at the bottom.
/// Takes the already-resolved translation rather than a language code, so
/// it doesn't need its own SharedPreferences read.
class _FirstAidDetailPage extends StatelessWidget {
  final IconData icon;
  final FirstAidTranslation translation;
  const _FirstAidDetailPage({required this.icon, required this.translation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kEmergency,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(translation.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: kEmergencyBg, shape: BoxShape.circle),
              child: Icon(icon, color: kEmergency, size: 46),
            ),
          ),
          const SizedBox(height: 24),
          ...translation.steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(fontSize: kFontBody, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kEmergencyBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kEmergencyBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: kEmergency, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    translation.warning,
                    style: const TextStyle(
                        fontSize: 13.5, color: kEmergency, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: EmergencyCallFab.call108,
              icon: const Icon(Icons.call_rounded, size: 22),
              label: const Text('Call Ambulance (108)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmergency,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(kMinTapTarget),
                textStyle: const TextStyle(fontSize: kFontLarge, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
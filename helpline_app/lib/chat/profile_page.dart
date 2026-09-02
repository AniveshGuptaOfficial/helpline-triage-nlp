import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';

/// SharedPreferences key for the chosen helpline response language, so
/// other screens (e.g. a future translation step) can read it later.
const String kLanguagePrefKey = 'vaidyum_helpline_language_code';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _selectedLanguageCode = 'hi'; // Hindi default, matches the mockup
  bool _isLoadingPrefs = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kLanguagePrefKey);
      if (!mounted) return;
      setState(() {
        if (saved != null) _selectedLanguageCode = saved;
        _isLoadingPrefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPrefs = false);
    }
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selectedLanguageCode = code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLanguagePrefKey, code);
    } catch (_) {
      // Non-fatal: the selection still applies for this session even if
      // persistence fails (e.g. platform channel not ready yet).
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out from helpline?'),
        content: const Text('You can sign back in anytime with your phone number.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: kEmergency),
              child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSigningOut = true);
    await FirebaseAuth.instance.signOut();
    // AuthGate in main.dart listens to authStateChanges() and swaps to
    // LoginPage automatically; no manual navigation needed here.
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumber = FirebaseAuth.instance.currentUser?.phoneNumber ?? 'Not signed in';

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
        title: const Text('Your Profile',
            style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isLoadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kCardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: kPrimaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: kPrimary),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(phoneNumber,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          const Text('Registered Helpline User',
                              style: TextStyle(fontSize: 12, color: kNeutral)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Helpline Response Language',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                ...kSupportedLanguages.map((lang) {
                  final selected = lang.code == _selectedLanguageCode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _selectLanguage(lang.code),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? kPrimary : kCardBorder,
                            width: selected ? 1.6 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lang.english == lang.native
                                    ? lang.english
                                    : '${lang.english} (${lang.native})',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected ? kPrimary : Colors.black87,
                                ),
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: kPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white),
                              )
                            else
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kCardBorder, width: 1.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: _isSigningOut
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Logout from Helpline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kEmergency,
                      side: const BorderSide(color: kEmergency),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Column(
                    children: [
                      Text('Vaidyum App Version 1.4.2',
                          style: TextStyle(fontSize: 11.5, color: kNeutral)),
                      SizedBox(height: 2),
                      Text('Supported by Ministry of Health & Family Welfare',
                          style: TextStyle(fontSize: 11.5, color: kNeutral)),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}
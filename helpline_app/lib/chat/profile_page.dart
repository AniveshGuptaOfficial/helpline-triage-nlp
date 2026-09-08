import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/emergency_call_fab.dart';
import '../localization/vaidyum_strings.dart';

/// One saved emergency contact (name + phone number).
class EmergencyContact {
  String name;
  String phone;
  EmergencyContact({required this.name, required this.phone});

  Map<String, String> toJson() => {'name': name, 'phone': phone};
  static EmergencyContact fromJson(Map<String, dynamic> j) =>
      EmergencyContact(name: j['name'] ?? '', phone: j['phone'] ?? '');
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _selectedLanguageCode = 'hi'; // Hindi default, matches the mockup
  bool _isLoadingPrefs = true;
  bool _isSigningOut = false;
  bool _isSharingEmergency = false;
  List<EmergencyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadEmergencyContacts();
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

  // --- Emergency Contacts: stored locally as a JSON list, capped at 3
  // per the spec. No backend involved - this is purely on-device, same
  // storage mechanism the language preference already uses. ---

  Future<void> _loadEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kEmergencyContactsPrefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        final loaded = decoded
            .map((e) => EmergencyContact.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (mounted) setState(() => _emergencyContacts = loaded);
      }
    } catch (_) {
      if (mounted) setState(() => _emergencyContacts = []);
    }
  }

  Future<void> _saveEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kEmergencyContactsPrefKey,
        jsonEncode(_emergencyContacts.map((c) => c.toJson()).toList()),
      );
    } catch (_) {
      // Non-fatal: contacts still apply for this session even if
      // persistence fails.
    }
  }

  Future<void> _addOrEditContact({EmergencyContact? existing, int? index}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');

    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? uiLabel('addEmergencyContact', _selectedLanguageCode) : 'Edit Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: uiLabel('nameLabel', _selectedLanguageCode)),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: uiLabel('phoneLabel', _selectedLanguageCode)),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(uiLabel('cancel', _selectedLanguageCode)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              if (name.isEmpty || phone.isEmpty) return;
              Navigator.pop(ctx, EmergencyContact(name: name, phone: phone));
            },
            child: Text(uiLabel('save', _selectedLanguageCode)),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() {
      if (index != null) {
        _emergencyContacts[index] = result;
      } else if (_emergencyContacts.length < 3) {
        _emergencyContacts.add(result);
      }
    });
    await _saveEmergencyContacts();
  }

  Future<void> _deleteContact(int index) async {
    setState(() => _emergencyContacts.removeAt(index));
    await _saveEmergencyContacts();
  }

  /// Opens the SMS composer prefilled to a specific saved contact with a
  /// short emergency message. Uses a `sms:` URI via url_launcher rather
  /// than requiring the SEND_SMS permission, so it works with no extra
  /// permission prompts - the user reviews and sends it themselves.
  Future<void> _notifyContact(EmergencyContact contact) async {
    final uri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {
        'body': 'This is an emergency message from Vaidyum helpline. '
            'Please check on me or call me back as soon as you can.',
      },
    );
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the messaging app.")),
      );
    }
  }

  /// "Share Emergency" - the actual feature requested: one button that
  /// shares "I need help" plus the user's LIVE current location with the
  /// saved contacts, via the native share sheet (WhatsApp, SMS, email,
  /// etc.). Location fetch is best-effort: if GPS is off or permission is
  /// denied, the message still sends without a location link rather than
  /// blocking the whole action - getting a help message out matters more
  /// than having every field filled in.
  Future<void> _shareEmergency() async {
    setState(() => _isSharingEmergency = true);
    String locationLine = '';
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          final mapsLink =
              'https://www.google.com/maps?q=${position.latitude},${position.longitude}';
          locationLine = 'My current location: $mapsLink\n\n';
        }
      }
    } catch (_) {
      // Best-effort only - fall through and share without a location link.
    }

    if (!mounted) return;
    final contactsList = _emergencyContacts.isEmpty
        ? 'No emergency contacts saved yet.'
        : _emergencyContacts.map((c) => '${c.name}: ${c.phone}').join('\n');
    await Share.share(
      'I need help. This is an emergency message from Vaidyum helpline. '
      'Please check on me or call me back as soon as you can.\n\n'
      '$locationLine'
      'My saved emergency contacts:\n$contactsList',
    );
    if (mounted) setState(() => _isSharingEmergency = false);
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
        title: Text(uiLabel('profileTitle', _selectedLanguageCode),
            style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _isLoadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              // Extra bottom padding so Logout/Share Emergency aren't
              // hidden under the floating Call 108 button.
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
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
                          Text(uiLabel('registeredUser', _selectedLanguageCode),
                              style: const TextStyle(fontSize: 12, color: kNeutral)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(uiLabel('responseLanguage', _selectedLanguageCode),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(uiLabel('emergencyContactsTitle', _selectedLanguageCode),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Text('${_emergencyContacts.length}/3',
                        style: const TextStyle(fontSize: 12, color: kNeutral)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  uiLabel('emergencyContactsSubtitle', _selectedLanguageCode),
                  style: const TextStyle(fontSize: 12, color: kNeutral),
                ),
                const SizedBox(height: 10),
                ..._emergencyContacts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final contact = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kCardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: kEmergencyBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, color: kEmergency, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(contact.name,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(contact.phone,
                                  style: const TextStyle(fontSize: 12.5, color: kNeutral)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sms_rounded, color: kPrimary),
                          tooltip: 'Notify via SMS',
                          onPressed: () => _notifyContact(contact),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: kNeutral, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _addOrEditContact(existing: contact, index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: kNeutral, size: 20),
                          tooltip: 'Remove',
                          onPressed: () => _deleteContact(index),
                        ),
                      ],
                    ),
                  );
                }),
                if (_emergencyContacts.length < 3)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addOrEditContact(),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: Text(uiLabel('addEmergencyContact', _selectedLanguageCode)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSharingEmergency ? null : _shareEmergency,
                    icon: _isSharingEmergency
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.campaign_rounded, size: 18),
                    label: Text(uiLabel('shareEmergencyBtn', _selectedLanguageCode)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kEmergency,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
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
                        : Text(uiLabel('logoutBtn', _selectedLanguageCode)),
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
      floatingActionButton: const EmergencyCallFab(),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }
}
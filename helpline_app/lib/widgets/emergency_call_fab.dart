import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

/// A big, red, always-visible "Call 108" floating button. One tap dials
/// the national emergency ambulance number directly - no confirmation
/// dialog, no extra steps, since in a real emergency every second and
/// every tap counts. Shared across every main screen (Home, Hospitals,
/// Stats, Profile, First Aid) as a Scaffold's floatingActionButton, so
/// it's genuinely always reachable, not just inside the chat flow.
class EmergencyCallFab extends StatelessWidget {
  const EmergencyCallFab({super.key});

  static Future<void> call108() async {
    final uri = Uri(scheme: 'tel', path: '108');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: call108,
      backgroundColor: kEmergency,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.call_rounded, size: 26),
      label: const Text(
        'Call 108',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../theme.dart';

/// The 4-tab bottom bar shown on every main screen (Home / Hospitals /
/// Stats / Profile), matching the Vaidyum mockups. Each screen owns its
/// own instance with `currentIndex` set to itself; tapping a different
/// tab navigates to that screen.
///
/// Navigation strategy: Home (index 0) is the app's root (ChatPage, shown
/// right after login). The other three tabs are pushed on top of it, and
/// tapping "Home" from one of them pops back to that root rather than
/// pushing a second Home instance - this avoids a deep stack of duplicate
/// pages if the user hops between tabs a lot.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  const AppBottomNav({super.key, required this.currentIndex});

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.local_shipping_rounded, label: 'Hospitals'),
    (icon: Icons.pie_chart_rounded, label: 'Stats'),
    (icon: Icons.person_rounded, label: 'Profile'),
  ];

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    if (index == 0) {
      // Home: pop everything back to the root ChatPage instead of pushing
      // a fresh one, so we don't stack up duplicate chat screens.
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    // Going from a non-Home tab to another non-Home tab: unwind to root
    // first, then push the new tab, so the back stack stays shallow
    // (Home -> Tab) instead of growing (Home -> Tab A -> Tab B -> ...).
    if (currentIndex != 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    switch (index) {
      case 1:
        Navigator.of(context).pushNamed('/hospitals');
        break;
      case 2:
        Navigator.of(context).pushNamed('/stats');
        break;
      case 3:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i];
            final active = i == currentIndex;
            final color = active ? kPrimary : kNeutral;
            return InkWell(
              onTap: () => _onTap(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(tab.icon, color: color, size: 24),
                    const SizedBox(height: 3),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 3,
                      width: active ? 22 : 0,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
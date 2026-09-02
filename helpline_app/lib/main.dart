import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'auth/login_page.dart';
import 'auth/splash_page.dart';
import 'chat/chat_page.dart';
import 'chat/stats_page.dart';
import 'chat/profile_page.dart';
import 'hospitals/hospital_finder_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VaidyumApp());
}

class VaidyumApp extends StatelessWidget {
  const VaidyumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaidyum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary, primary: kPrimary),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      // Splash plays once at cold start, then hands off to AuthGate, which
      // decides between LoginPage and the signed-in ChatPage (Home tab).
      home: const AppRoot(),
      // Named routes for the three tabs that live outside the Home stack.
      // AppBottomNav (shared across Home/Hospitals/Stats/Profile) pushes
      // these by name so every tab can reach every other tab the same way.
      routes: {
        '/hospitals': (_) => const HospitalFinderPage(),
        '/stats': (_) => const StatsPage(),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}

/// Plays the Vaidyum splash screen once, then falls through to AuthGate.
/// Tapping the splash (its "X" button, matching the mockup) or waiting for
/// the timer both continue to AuthGate - neither path is skipped, so a
/// slow device just waits it out instead of getting stuck.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return SplashPage(onDismiss: () => setState(() => _splashDone = true));
    }
    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return const ChatPage();
        }
        return const LoginPage();
      },
    );
  }
}
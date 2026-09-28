import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationService().initialize();

    runApp(const ISGCoursApp());
  } catch (e) {
    runApp(
      FirebaseErrorApp(
        message: 'Erreur Firebase :\n\n$e',
      ),
    );
  }
}

// ============================================================
// FIREBASE ERROR
// ============================================================

class FirebaseErrorApp extends StatelessWidget {
  final String message;

  const FirebaseErrorApp({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 70,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Problème Firebase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// APP
// ============================================================

class ISGCoursApp extends StatelessWidget {
  const ISGCoursApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'ISG Cours',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

// ============================================================
// AUTH WRAPPER
// ============================================================

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<User?>? _authSubscription;

  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    debugPrint('[AuthWrapper] initState');

    final authService = context.read<AuthService>();

    _authSubscription = authService.authStateChanges.listen(
          (User? user) async {
        debugPrint(
          '[AuthWrapper] authStateChanges: ${user?.email}',
        );

        if (!mounted) {
          return;
        }

        if (user == null) {
          // On attend la fin de la frame en cours avant de changer
          // d'écran (HomeScreen -> LoginScreen). Ça évite une course
          // avec la fermeture d'un dialog encore en cours d'animation
          // (ex: le dialog "Votre avis avant de partir" au logout),
          // qui provoquait le crash Flutter interne
          // "'_dependents.isEmpty': is not true".
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _user = null;
              _loading = false;
            });
          });

          return;
        }

        try {
          await authService.loadProfile();
        } catch (e) {
          debugPrint(
            '[AuthWrapper] Profile loading error: $e',
          );
        }

        if (!mounted) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _user = user;
            _loading = false;
          });
        });
      },
      onError: (Object error) {
        debugPrint(
          '[AuthWrapper] Auth error: $error',
        );

        if (!mounted) {
          return;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _user = null;
            _loading = false;
          });
        });
      },
    );
  }

  @override
  void dispose() {
    debugPrint('[AuthWrapper] dispose');

    _authSubscription?.cancel();
    _authSubscription = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[AuthWrapper] build '
          'loading=$_loading '
          'user=${_user?.email}',
    );

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) {
      return const LoginScreen();
    }

    return const HomeScreen();
  }
}
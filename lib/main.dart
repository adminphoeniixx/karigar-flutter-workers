import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';

import 'controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'models/api_models.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/worker_api_service.dart';

part 'models/job.dart';
part 'screens/splash_screen.dart';
part 'screens/auth/onboarding_screen.dart';
part 'screens/auth/login_screen.dart';
part 'screens/auth/registration_screen.dart';
part 'screens/main_shell.dart';
part 'screens/home_screen.dart';
part 'screens/jobs/jobs_screen.dart';
part 'screens/jobs/job_detail_screen.dart';
part 'screens/applications_screen.dart';
part 'screens/notifications_screen.dart';
part 'screens/profile/profile_screen.dart';
part 'screens/profile/edit_profile_screen.dart';
part 'screens/profile/kyc_screen.dart';
part 'screens/jobs/saved_screen.dart';
part 'screens/profile/reviews_screen.dart';
part 'screens/profile/settings_screen.dart';
part 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.instance.initialize();
  } catch (error) {
    debugPrint('[FCM] Firebase initialization failed: $error');
  }
  runApp(const KarigarApp());
}

const brand = Color(0xFFF4470F);
const bg = Color(0xFFF6F7F9);
const line = Color(0xFFE9EBEF);
const ink = Color(0xFF16181D);
const muted = Color(0xFF6B7280);
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
final profileAvatarUrl = ValueNotifier<String?>(null);

extension AppThemeColors on BuildContext {
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get foregroundColor => Theme.of(this).colorScheme.onSurface;
  Color get borderColor => Theme.of(this).dividerColor;
  Color get fieldColor => Theme.of(this).inputDecorationTheme.fillColor!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get brandTint =>
      isDark ? const Color(0xFF30221D) : const Color(0xFFFFF3EE);
  Color get amberTint =>
      isDark ? const Color(0xFF332719) : const Color(0xFFFFF7ED);
  Color get greenTint =>
      isDark ? const Color(0xFF162A24) : const Color(0xFFECFDF5);
  Color get subduedColor =>
      isDark ? const Color(0xFF252932) : const Color(0xFFF0F1F4);
}

class KarigarApp extends StatelessWidget {
  const KarigarApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karigar — Worker App',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: mode,
      home: const AuthGate(),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF1B1E24) : Colors.white;
    final canvas = dark ? const Color(0xFF121419) : bg;
    final border = dark ? const Color(0xFF30343D) : line;
    final foreground = dark ? const Color(0xFFF5F6F8) : ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      primary: brand,
      surface: surface,
      onSurface: foreground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Outfit',
      scaffoldBackgroundColor: canvas,
      colorScheme: scheme,
      dividerColor: border,
      cardColor: surface,
      canvasColor: surface,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: foreground, fontSize: 14.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(bottom: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9AA1AD)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: brand, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _session = _initialize();

  Future<bool> _initialize() async {
    final results = await Future.wait<dynamic>([
      _restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    return results.first as bool;
  }

  Future<bool> _restoreSession() async {
    if (!ApiClient.instance.isAuthenticated) return false;
    try {
      await AuthService().me();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await ApiClient.instance.setToken(null);
        return false;
      }
      // Keep an existing session during temporary connectivity/server failures.
      return true;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const AppSplash();
      }
      return snapshot.data == true ? const MainShell() : const OnboardingPage();
    },
  );
}

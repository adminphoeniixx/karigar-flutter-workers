import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final preferences = await SharedPreferences.getInstance();
  appLocale.value = Locale(preferences.getString('app_locale') ?? 'en');
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
final appLocale = ValueNotifier<Locale>(const Locale('en'));
final profileAvatarUrl = ValueNotifier<String?>(null);

const _translations = <String, Map<String, String>>{
  'hi': {
    'Home': 'होम',
    'Jobs': 'नौकरियां',
    'Applied': 'आवेदन',
    'Alerts': 'सूचनाएं',
    'Profile': 'प्रोफ़ाइल',
    'Settings': 'सेटिंग्स',
    'Preferences': 'प्राथमिकताएं',
    'Language': 'भाषा',
    'Dark theme': 'डार्क थीम',
    'Job alerts': 'नौकरी सूचनाएं',
    'Account & security': 'खाता और सुरक्षा',
    'Login & security': 'लॉगिन और सुरक्षा',
    'Terms & Privacy': 'नियम और गोपनीयता',
    'Help & Support': 'सहायता',
    'Delete account': 'खाता हटाएं',
    'Log out': 'लॉग आउट',
    'Choose language': 'भाषा चुनें',
    'Pick your preferred app language.': 'ऐप की भाषा चुनें।',
  },
  'ta': {
    'Home': 'முகப்பு',
    'Jobs': 'வேலைகள்',
    'Applied': 'விண்ணப்பங்கள்',
    'Alerts': 'அறிவிப்புகள்',
    'Profile': 'சுயவிவரம்',
    'Settings': 'அமைப்புகள்',
    'Preferences': 'விருப்பங்கள்',
    'Language': 'மொழி',
    'Dark theme': 'இருண்ட தோற்றம்',
    'Job alerts': 'வேலை அறிவிப்புகள்',
    'Account & security': 'கணக்கு மற்றும் பாதுகாப்பு',
    'Login & security': 'உள்நுழைவு மற்றும் பாதுகாப்பு',
    'Terms & Privacy': 'விதிமுறைகள் மற்றும் தனியுரிமை',
    'Help & Support': 'உதவி',
    'Delete account': 'கணக்கை நீக்கு',
    'Log out': 'வெளியேறு',
    'Choose language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
    'Pick your preferred app language.':
        'உங்களுக்கு விருப்பமான மொழியைத் தேர்ந்தெடுக்கவும்.',
  },
  'te': {
    'Home': 'హోమ్',
    'Jobs': 'ఉద్యోగాలు',
    'Applied': 'దరఖాస్తులు',
    'Alerts': 'నోటిఫికేషన్లు',
    'Profile': 'ప్రొఫైల్',
    'Settings': 'సెట్టింగ్‌లు',
    'Preferences': 'ప్రాధాన్యతలు',
    'Language': 'భాష',
    'Dark theme': 'డార్క్ థీమ్',
    'Job alerts': 'ఉద్యోగ నోటిఫికేషన్లు',
    'Account & security': 'ఖాతా మరియు భద్రత',
    'Login & security': 'లాగిన్ మరియు భద్రత',
    'Terms & Privacy': 'నిబంధనలు మరియు గోప్యత',
    'Help & Support': 'సహాయం',
    'Delete account': 'ఖాతాను తొలగించండి',
    'Log out': 'లాగ్ అవుట్',
    'Choose language': 'భాషను ఎంచుకోండి',
    'Pick your preferred app language.': 'మీకు నచ్చిన యాప్ భాషను ఎంచుకోండి.',
  },
  'bn': {
    'Home': 'হোম',
    'Jobs': 'চাকরি',
    'Applied': 'আবেদন',
    'Alerts': 'বিজ্ঞপ্তি',
    'Profile': 'প্রোফাইল',
    'Settings': 'সেটিংস',
    'Preferences': 'পছন্দসমূহ',
    'Language': 'ভাষা',
    'Dark theme': 'ডার্ক থিম',
    'Job alerts': 'চাকরির বিজ্ঞপ্তি',
    'Account & security': 'অ্যাকাউন্ট ও নিরাপত্তা',
    'Login & security': 'লগইন ও নিরাপত্তা',
    'Terms & Privacy': 'শর্তাবলী ও গোপনীয়তা',
    'Help & Support': 'সহায়তা',
    'Delete account': 'অ্যাকাউন্ট মুছুন',
    'Log out': 'লগ আউট',
    'Choose language': 'ভাষা বেছে নিন',
    'Pick your preferred app language.': 'আপনার পছন্দের অ্যাপ ভাষা বেছে নিন।',
  },
  'mr': {
    'Home': 'मुख्यपृष्ठ',
    'Jobs': 'नोकऱ्या',
    'Applied': 'अर्ज',
    'Alerts': 'सूचना',
    'Profile': 'प्रोफाइल',
    'Settings': 'सेटिंग्ज',
    'Preferences': 'प्राधान्ये',
    'Language': 'भाषा',
    'Dark theme': 'डार्क थीम',
    'Job alerts': 'नोकरी सूचना',
    'Account & security': 'खाते आणि सुरक्षा',
    'Login & security': 'लॉगिन आणि सुरक्षा',
    'Terms & Privacy': 'अटी आणि गोपनीयता',
    'Help & Support': 'मदत',
    'Delete account': 'खाते हटवा',
    'Log out': 'लॉग आउट',
    'Choose language': 'भाषा निवडा',
    'Pick your preferred app language.': 'तुमची पसंतीची ॲप भाषा निवडा.',
  },
};

extension AppTranslations on BuildContext {
  String tr(String english) =>
      _translations[appLocale.value.languageCode]?[english] ?? english;
}

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
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: appLocale,
    builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Karigar — Worker App',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        locale: locale,
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('ta'),
          Locale('te'),
          Locale('bn'),
          Locale('mr'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AuthGate(),
      ),
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

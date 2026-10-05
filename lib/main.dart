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
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'controllers/auth_controller.dart';
import 'firebase_options.dart';
import 'models/api_models.dart';
import 'services/api_client.dart';
import 'services/meta_events_service.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'services/worker_api_service.dart';
import 'services/feed_location_service.dart';

part 'models/job.dart';
part 'widgets/app_language_button.dart';
part 'widgets/localized_text.dart';
part 'widgets/image_source_picker.dart';
part 'widgets/profile_options_picker.dart';
part 'l10n/translations.dart';
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
part 'screens/profile/resume_screen.dart';
part 'screens/profile/sessions_screen.dart';
part 'screens/conversations_screen.dart';
part 'widgets/common_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const KarigarApp(onInitialize: _initializeApp));
}

Future<void> _initializeApp() async {
  final preferences = await SharedPreferences.getInstance();
  // Hindi is the default until a worker chooses a different app language.
  final savedLanguage = preferences.getString('app_locale') ?? 'hi';
  selectedLanguageCode.value = savedLanguage;
  appLocale.value = _localeForLanguage(savedLanguage);
  await ApiClient.instance.initialize();
  unawaited(MetaEventsService.instance.initialize());
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.instance.initialize();
  } catch (error) {
    debugPrint('[FCM] Firebase initialization failed: $error');
  }
}

// Warm "Paper & Ink" palette shared with the approved worker-app HTML.
const brand = Color(0xFFBF3A16);
const bg = Color(0xFFF4EFE7);
const card = Color(0xFFFBF8F3);
const line = Color(0xFFE3DBD0);
const ink = Color(0xFF1E1712);
const muted = Color(0xFF6B5F55);
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
final appLocale = ValueNotifier<Locale>(const Locale('hi'));
final selectedLanguageCode = ValueNotifier<String>('hi');
final profileAvatarUrl = ValueNotifier<String?>(null);
// MaterialApp can rebuild while a new locale is applied. Keep this launch-only
// flag outside that subtree so choosing a language never opens a second dialog.
bool _hasShownStartupLanguagePrompt = false;
const _languagePromptSeenKey = 'language_prompt_seen';

Locale _localeForLanguage(String code) =>
    code == 'hinglish' ? const Locale('en') : Locale(code);

const _translations = <String, Map<String, String>>{
  'hi': {
    "Welcome back 👋": "वापसी पर स्वागत है 👋",
    "Available for work": "काम के लिए उपलब्ध",
    "Employers can discover you": "नियोक्ता आपको खोज सकते हैं",
    "You're hidden from employers": "आप नियोक्ताओं से छिपे हैं",
    "Available Jobs": "उपलब्ध नौकरियां",
    "KYC Status": "KYC स्थिति",
    "Applications": "आवेदन",
    "Profile complete": "प्रोफ़ाइल पूर्ण",
    "Add skills & KYC to get more jobs":
        "अधिक नौकरियों के लिए कौशल और KYC जोड़ें",
    "Complete": "पूरा करें",
    "LATEST JOBS NEAR YOU": "आपके पास नई नौकरियां",
    "See all →": "सभी देखें →",
    "No jobs available near you yet": "अभी आपके पास कोई नौकरी उपलब्ध नहीं है",
    "New matching jobs will appear here.": "नई उपयुक्त नौकरियां यहां दिखेंगी।",
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
    "Welcome back 👋": "மீண்டும் வரவேற்கிறோம் 👋",
    "Available for work": "வேலைக்குத் தயார்",
    "Employers can discover you": "முதலாளிகள் உங்களைக் கண்டறியலாம்",
    "You're hidden from employers": "முதலாளிகளுக்கு உங்கள் விவரம் தெரியாது",
    "Available Jobs": "கிடைக்கும் வேலைகள்",
    "KYC Status": "KYC நிலை",
    "Applications": "விண்ணப்பங்கள்",
    "Profile complete": "சுயவிவரம் நிறைவு",
    "Add skills & KYC to get more jobs":
        "மேலும் வேலைகளுக்குத் திறன்கள் மற்றும் KYC சேர்க்கவும்",
    "Complete": "நிறைவு செய்",
    "LATEST JOBS NEAR YOU": "அருகிலுள்ள புதிய வேலைகள்",
    "See all →": "அனைத்தையும் காண்க →",
    "No jobs available near you yet": "அருகில் இன்னும் வேலைகள் இல்லை",
    "New matching jobs will appear here.":
        "பொருத்தமான புதிய வேலைகள் இங்கே தோன்றும்.",
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
    "Welcome back 👋": "మళ్లీ స్వాగతం 👋",
    "Available for work": "పని చేయడానికి సిద్ధం",
    "Employers can discover you": "యజమానులు మిమ్మల్ని కనుగొనగలరు",
    "You're hidden from employers": "మీ వివరాలు యజమానులకు కనిపించవు",
    "Available Jobs": "అందుబాటులో ఉన్న ఉద్యోగాలు",
    "KYC Status": "KYC స్థితి",
    "Applications": "దరఖాస్తులు",
    "Profile complete": "ప్రొఫైల్ పూర్తి",
    "Add skills & KYC to get more jobs":
        "మరిన్ని ఉద్యోగాల కోసం నైపుణ్యాలు మరియు KYC జోడించండి",
    "Complete": "పూర్తి చేయండి",
    "LATEST JOBS NEAR YOU": "మీ సమీపంలోని కొత్త ఉద్యోగాలు",
    "See all →": "అన్నీ చూడండి →",
    "No jobs available near you yet": "మీ సమీపంలో ఇంకా ఉద్యోగాలు లేవు",
    "New matching jobs will appear here.":
        "కొత్త అనుకూల ఉద్యోగాలు ఇక్కడ కనిపిస్తాయి.",
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
    "Welcome back 👋": "আবার স্বাগতম 👋",
    "Available for work": "কাজের জন্য উপলব্ধ",
    "Employers can discover you": "নিয়োগকর্তারা আপনাকে খুঁজে পাবেন",
    "You're hidden from employers": "নিয়োগকর্তারা আপনাকে দেখতে পাবেন না",
    "Available Jobs": "উপলব্ধ চাকরি",
    "KYC Status": "KYC অবস্থা",
    "Applications": "আবেদন",
    "Profile complete": "প্রোফাইল সম্পূর্ণ",
    "Add skills & KYC to get more jobs":
        "আরও চাকরির জন্য দক্ষতা ও KYC যোগ করুন",
    "Complete": "সম্পূর্ণ করুন",
    "LATEST JOBS NEAR YOU": "আপনার কাছের নতুন চাকরি",
    "See all →": "সব দেখুন →",
    "No jobs available near you yet": "এখনও আপনার কাছে চাকরি নেই",
    "New matching jobs will appear here.": "নতুন উপযুক্ত চাকরি এখানে দেখাবে।",
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
    "Welcome back 👋": "पुन्हा स्वागत आहे 👋",
    "Available for work": "कामासाठी उपलब्ध",
    "Employers can discover you": "नियोक्ते तुम्हाला शोधू शकतात",
    "You're hidden from employers": "तुम्ही नियोक्त्यांना दिसत नाही",
    "Available Jobs": "उपलब्ध नोकऱ्या",
    "KYC Status": "KYC स्थिती",
    "Applications": "अर्ज",
    "Profile complete": "प्रोफाइल पूर्ण",
    "Add skills & KYC to get more jobs":
        "अधिक नोकऱ्यांसाठी कौशल्ये आणि KYC जोडा",
    "Complete": "पूर्ण करा",
    "LATEST JOBS NEAR YOU": "तुमच्या जवळील नवीन नोकऱ्या",
    "See all →": "सर्व पहा →",
    "No jobs available near you yet": "सध्या जवळ नोकऱ्या उपलब्ध नाहीत",
    "New matching jobs will appear here.": "नवीन योग्य नोकऱ्या येथे दिसतील.",
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
  String trArgs(String key, Map<String, String> arguments) {
    var translated = tr(key);
    for (final entry in arguments.entries) {
      translated = translated.replaceAll('{${entry.key}}', entry.value);
    }
    return translated;
  }

  String tr(String english) =>
      translateAppText(english, Localizations.localeOf(this).languageCode);
}

extension AppThemeColors on BuildContext {
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get foregroundColor => Theme.of(this).colorScheme.onSurface;
  Color get borderColor => Theme.of(this).dividerColor;
  Color get fieldColor => Theme.of(this).inputDecorationTheme.fillColor!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get brandTint =>
      isDark ? const Color(0xFF3A2119) : const Color(0xFFFDF3EE);
  Color get amberTint =>
      isDark ? const Color(0xFF332719) : const Color(0xFFFDF3E3);
  Color get greenTint =>
      isDark ? const Color(0xFF1D2C1B) : const Color(0xFFEEF4EC);
  Color get subduedColor =>
      isDark ? const Color(0xFF2B251F) : const Color(0xFFECE5DA);
}

class KarigarApp extends StatelessWidget {
  const KarigarApp({super.key, this.initialization, this.onInitialize});

  final Future<void>? initialization;
  final Future<void> Function()? onInitialize;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: appLocale,
    builder: (context, locale, _) => ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Super Karigar Worker',
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
          Locale('kn'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AuthGate(
          initialization: initialization,
          onInitialize: onInitialize,
        ),
      ),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF211B17) : card;
    final canvas = dark ? const Color(0xFF17120F) : bg;
    final border = dark ? const Color(0xFF443A32) : line;
    final foreground = dark ? const Color(0xFFF7F0E8) : ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      primary: brand,
      surface: surface,
      onSurface: foreground,
      onPrimary: Colors.white,
      surfaceContainerHighest: dark
          ? const Color(0xFF2B251F)
          : const Color(0xFFECE5DA),
      outline: border,
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
        hintStyle: TextStyle(
          color: dark ? const Color(0xFFA99B90) : const Color(0xFF8A7C70),
        ),
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
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: dark
            ? const Color(0xFF3A2119)
            : const Color(0xFFFDF3EE),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? brand : foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.initialization, this.onInitialize});

  final Future<void>? initialization;
  final Future<void> Function()? onInitialize;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _session = _initialize();
  bool _languagePromptShown = false;
  bool _checkingLanguagePrompt = false;

  Future<void> _showLanguagePrompt() async {
    if (_languagePromptShown ||
        _checkingLanguagePrompt ||
        _hasShownStartupLanguagePrompt) {
      return;
    }
    _checkingLanguagePrompt = true;
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (preferences.getBool(_languagePromptSeenKey) == true) {
      _hasShownStartupLanguagePrompt = true;
      _checkingLanguagePrompt = false;
      return;
    }
    _languagePromptShown = true;
    _hasShownStartupLanguagePrompt = true;
    _checkingLanguagePrompt = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _LanguageDialog(persistLocally: true),
      ).whenComplete(() => preferences.setBool(_languagePromptSeenKey, true));
    });
  }

  Future<bool> _initialize() async {
    final results = await Future.wait<dynamic>([
      _restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    return results.first as bool;
  }

  Future<bool> _restoreSession() async {
    // The first frame always renders AppSplash before platform initialization.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    await widget.initialization;
    await widget.onInitialize?.call();
    if (!ApiClient.instance.isAuthenticated) return false;
    try {
      final user = await AuthService().me();
      if (!user.isWorker) {
        await ApiClient.instance.setToken(null);
        return false;
      }
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
      unawaited(_showLanguagePrompt());
      return snapshot.data == true ? const MainShell() : const OnboardingPage();
    },
  );
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/services/feed_location_service.dart';

class NoTestLocation extends FeedLocationService {
  @override
  Future<FeedPosition?> current({bool requestPermission = false}) async => null;
}

Widget localized(Widget child, String language) => MaterialApp(
  locale: Locale(language),
  supportedLocales: appLanguages.map((e) => Locale(e.$1)),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

void main() {
  test('every catalog entry exists in all five translated languages', () {
    final keys = appTextTranslations['hi']!.keys.toSet();
    final placeholders = RegExp(r'\{\w+\}');
    for (final catalog in appTextTranslations.values) {
      expect(catalog.keys.toSet(), keys);
      for (final entry in catalog.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
        expect(
          placeholders.allMatches(entry.value).map((e) => e[0]).toSet(),
          placeholders.allMatches(entry.key).map((e) => e[0]).toSet(),
          reason: entry.key,
        );
      }
    }
  });

  test('static screen labels have translations', () {
    final pattern = RegExp(
      r'''(?:AppText|FieldLabel|SectionTitle|SectionHeader|PrimaryButton)\(\s*(?:'([^'\n]*)'|"([^"\n]*)")''',
    );
    const unchanged = {'IN', 'UPI ID', 'Super Karigar Worker · v1.0.0'};
    for (final file
        in Directory('lib/screens')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      for (final match in pattern.allMatches(file.readAsStringSync())) {
        final text = (match[1] ?? match[2]!).replaceAll(r'\n', '\n');
        if (text.contains(r'$') ||
            !RegExp('[a-zA-Z]').hasMatch(text) ||
            unchanged.contains(text)) {
          continue;
        }
        for (final language in appTextTranslations.keys) {
          expect(
            translateAppText(text, language),
            isNot(text),
            reason: '${file.path}: $language: $text',
          );
        }
      }
    }
  });

  testWidgets('cached text updates without recreating the screen', (
    tester,
  ) async {
    const screen = Scaffold(body: AppText('Saved Jobs'));
    await tester.pumpWidget(localized(screen, 'en'));
    expect(find.text('Saved Jobs'), findsOneWidget);
    for (final language in appTextTranslations.keys) {
      await tester.pumpWidget(localized(screen, language));
      await tester.pumpAndSettle();
      expect(
        find.text(translateAppText('Saved Jobs', language)),
        findsOneWidget,
      );
      expect(find.text('Saved Jobs'), findsNothing);
    }
  });

  for (final language in ['hi', 'ta', 'te', 'bn', 'mr']) {
    testWidgets('auth and settings render in $language at phone size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final screen in [
        const OnboardingPage(),
        const LoginPage(),
        const RegistrationPage(),
        JobsTab(locationService: NoTestLocation()),
        const ApplicationsTab(),
        const ProfileTab(),
        const EditProfilePage(),
        const SavedPage(),
        const ReviewsPage(),
        const ResumePage(),
        const KycPage(),
        const SessionsPage(),
        const SettingsPage(),
      ]) {
        await tester.pumpWidget(localized(screen, language));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$language: ${screen.runtimeType}',
        );
      }
      expect(find.text(translateAppText('Settings', language)), findsOneWidget);
      expect(find.text(translateAppText('Language', language)), findsNothing);
    });
  }
}

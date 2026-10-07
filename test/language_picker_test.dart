import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/services/api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLocale.value = const Locale('en');
    selectedLanguageCode.value = 'en';
  });
  tearDown(() {
    appLocale.value = const Locale('en');
    selectedLanguageCode.value = 'en';
  });

  Widget app(Future<String> Function(String) save) =>
      ValueListenableBuilder<Locale>(
        valueListenable: appLocale,
        builder: (_, locale, child) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  Text(context.tr('Home')),
                  AppLanguageButton(saveLocale: save),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('selection updates visible labels and persists language', (
    tester,
  ) async {
    String? saved;
    await tester.pumpWidget(
      app((code) async {
        saved = code;
        return code;
      }),
    );
    await tester.tap(find.byType(AppLanguageButton));
    await tester.pumpAndSettle();
    expect(find.text('Hindi + English'), findsOneWidget);
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(saved, 'hi');
    expect(find.text('होम'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('app_locale'),
      'hi',
    );
  });

  testWidgets('failure restores the earlier language and shows an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      app((_) async => throw ApiException('Try later', statusCode: 500)),
    );
    await tester.tap(find.byType(AppLanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(appLocale.value.languageCode, 'en');
    expect(find.text('Try later'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

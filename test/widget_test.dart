import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';

void main() {
  testWidgets('worker onboarding opens mobile login', (tester) async {
    await tester.pumpWidget(const KarigarApp());

    expect(find.text('Find work,\nnear your home.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Login with Mobile'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('all worker screens render at reference phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final screens = <Widget>[
      const LoginPage(),
      const RegistrationPage(),
      const MainShell(),
      JobDetailPage(jobs.first),
      const EditProfilePage(),
      const KycPage(),
      const SavedPage(),
      const ReviewsPage(),
      const SettingsPage(),
    ];

    for (final screen in screens) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: screen,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dark theme updates the complete app', (tester) async {
    appThemeMode.value = ThemeMode.light;
    await tester.pumpWidget(const KarigarApp());
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );

    appThemeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    appThemeMode.value = ThemeMode.light;
  });
}

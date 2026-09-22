import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';
import 'package:karigar_app/models/api_models.dart';

void main() {
  testWidgets('first frame shows splash while startup is pending', (tester) async {
    final initialization = Completer<void>();
    var initializationStarted = false;
    await tester.pumpWidget(KarigarApp(onInitialize: () {
      initializationStarted = true;
      return initialization.future;
    }));
    expect(initializationStarted, isTrue);

    expect(find.byType(AppSplash), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'Super Karigar. Kaam. Hunar. Bharosa.',
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AppSplash), findsOneWidget);
    expect(tester.takeException(), isNull);

    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AppSplash), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  test('review API fields are parsed according to the worker contract', () {
    final reviewed = ApplicationModel.fromJson({
      'id': 10,
      'status': 'accepted',
      'can_review': false,
      'has_reviewed': true,
    });
    final reviewable = ApplicationModel.fromJson({
      'id': 11,
      'status': 'accepted',
      'can_review': true,
      'has_reviewed': false,
    });

    expect(reviewed.canReview, isFalse);
    expect(reviewable.canReview, isTrue);
  });

  testWidgets('worker onboarding opens mobile login', (tester) async {
    await tester.pumpWidget(const KarigarApp());
    await tester.pump(const Duration(milliseconds: 1500));

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
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );

    appThemeMode.value = ThemeMode.light;
  });
}

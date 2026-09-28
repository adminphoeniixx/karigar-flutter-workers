import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(360, 800),
    Size(430, 932),
    Size(768, 1024),
    Size(1024, 768),
  ]) {
    testWidgets('splash preserves artwork proportions and margins at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: AppSplash()));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/worker_splash.png'),
          tester.element(find.byType(AppSplash)),
        );
      });
      await tester.pump();

      final column = tester.getRect(find.byType(Column));
      expect(column, Offset.zero & size);
      final sections = tester
          .widgetList<FittedBox>(find.byType(FittedBox))
          .toList();
      expect(sections.length, 3);
      final branding = sections[1];
      expect(branding.fit, BoxFit.contain);
      final brandingSize = tester.getSize(find.byType(FittedBox).at(1));
      final fitted = applyBoxFit(
        branding.fit,
        const Size(1080, 400),
        brandingSize,
      );
      expect(fitted.source, const Size(1080, 400));
      expect(fitted.destination.aspectRatio, closeTo(1080 / 400, 0.001));
      final footer = tester.getRect(find.byType(FittedBox).last);
      expect(footer.bottom, size.height);
      expect(footer.height, closeTo(size.height * .20, 0.001));
      for (final section in [0, 2]) {
        expect(sections[section].fit, BoxFit.cover);
      }
      expect(find.byType(ClipOval), findsNothing);
      expect(find.byType(SafeArea), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Super Karigar Worker'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

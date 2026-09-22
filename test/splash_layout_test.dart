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
    testWidgets('splash fills display at $size', (tester) async {
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

      final render = tester.renderObject<RenderImage>(find.byType(RawImage));
      final image = render.image!;
      final source = Size(image.width.toDouble(), image.height.toDouble());
      final fitted = applyBoxFit(render.fit!, source, render.size);
      expect(fitted.source, source, reason: 'Keep the entire reference visible');
      expect(fitted.destination.width, size.width);
      expect(fitted.destination.height, size.height);
      expect(tester.getRect(find.byType(RawImage)).top, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

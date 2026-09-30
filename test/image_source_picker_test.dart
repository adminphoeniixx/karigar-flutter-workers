import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karigar_app/main.dart';

void main() {
  for (final option in {
    'Take photo': ImageSource.camera,
    'Choose from gallery': ImageSource.gallery,
    'Cancel': null,
  }.entries) {
    testWidgets('${option.key} returns the correct image source', (
      tester,
    ) async {
      ImageSource? selected;
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showImageSourceChooser(context);
                  finished = true;
                },
                child: const Text('Upload'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      await tester.tap(find.text(option.key));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(selected, option.value);
      expect(tester.takeException(), isNull);
    });
  }
}

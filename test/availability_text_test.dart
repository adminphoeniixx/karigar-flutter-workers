import 'package:flutter_test/flutter_test.dart';
import 'package:karigar_app/main.dart';

void main() {
  test('the unavailable card is translated, not left in English', () {
    const texts = [
      "You're not available for work",
      "I'm available for work",
      'While "Available for work" is off you get no job alerts and see no jobs. Switch it on whenever you’re ready.',
      'Distance',
      'Any distance',
    ];
    for (final language in ['hi', 'ta', 'te', 'bn', 'mr']) {
      for (final text in texts) {
        expect(
          translateAppText(text, language),
          isNot(text),
          reason: '$language: $text',
        );
      }
    }
  });
}

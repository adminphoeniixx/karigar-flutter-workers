# App language strings

`AppText` resolves display strings using the current Flutter `Localizations` locale.
It updates even when its parent tab or dialog is cached. `context.tr()` is used
for text fields, tooltips and other string-only properties; `context.trArgs()`
substitutes named placeholders after translation.

Add every app-owned label to `lib/l10n/translations.dart` in Hindi, Tamil,
Telugu, Bengali and Marathi. The English source string is the lookup key.
The initial navigation/Home translations also live in `lib/main.dart`.

Keep dropdown values, filters and submitted API fields in their original form;
translate their display labels only. Keep names, chat messages, reviews and
employer-authored descriptions as supplied, using `Text` for free-form content.
Backend-authored legal documents and notification bodies need localized content
from the backend; the client catalog does not perform machine translation.

Run `flutter test test/app_localization_test.dart test/language_picker_test.dart`
to check catalog coverage, placeholders, cached-screen updates, persistence,
error handling and phone layouts in all five translated languages.

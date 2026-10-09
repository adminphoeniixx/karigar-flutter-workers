part of '../main.dart';

const appLanguages = [
  ('hinglish', 'Hindi + English', 'Hinglish'),
  ('en', 'English', 'English'),
  ('hi', 'हिन्दी', 'Hindi'),
  ('mr', 'मराठी', 'Marathi'),
  ('kn', 'ಕನ್ನಡ', 'Kannada'),
  ('te', 'తెలుగు', 'Telugu'),
  ('ta', 'தமிழ்', 'Tamil'),
  ('bn', 'বাংলা', 'Bangla'),
];

class AppLanguageButton extends StatelessWidget {
  const AppLanguageButton({super.key, this.saveLocale});
  final Future<String> Function(String)? saveLocale;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: context.tr('Choose language'),
    icon: const Icon(LucideIcons.languages, size: 21),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => _LanguageDialog(saveLocale: saveLocale),
    ),
  );
}

class _LanguageDialog extends StatefulWidget {
  const _LanguageDialog({this.saveLocale, this.persistLocally = false});
  final Future<String> Function(String)? saveLocale;
  final bool persistLocally;
  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  bool saving = false;
  String? error;
  late String selectedCode = selectedLanguageCode.value;

  Future<void> _submit() async {
    if (saving) return;
    if (selectedCode == selectedLanguageCode.value) {
      Navigator.pop(context);
      return;
    }
    final previousCode = selectedLanguageCode.value;
    final previousLocale = appLocale.value;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      saving = true;
      error = null;
    });

    // Switch the in-memory locale before any disk or network work. Every
    // AppText listens to MaterialApp's locale, so open and cached tabs update
    // in the same frame instead of waiting for the API response.
    selectedLanguageCode.value = selectedCode;
    appLocale.value = _localeForLanguage(selectedCode);
    Navigator.pop(context);

    try {
      // Hinglish is an app-only display preference; the worker API accepts
      // only its standard locale codes.
      // The server stores Hinglish as Hindi; retain the Hinglish code locally
      // so this device keeps the Roman-Hindi UI choice.
      late final String saved;
      if (widget.persistLocally) {
        saved = selectedCode;
      } else if (selectedCode == 'hinglish') {
        await (widget.saveLocale?.call('hi') ??
            WorkerApiService().setLocale('hi'));
        saved = selectedCode;
      } else {
        saved =
            await (widget.saveLocale?.call(selectedCode) ??
                WorkerApiService().setLocale(selectedCode));
      }
      if (!appLanguages.any((language) => language.$1 == saved)) {
        throw StateError('Unsupported language');
      }
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString('app_locale', saved)) {
        throw StateError('Could not save language');
      }
      // The API can normalize a code; keep the visible locale aligned with it.
      if (saved != selectedLanguageCode.value) {
        selectedLanguageCode.value = saved;
        appLocale.value = _localeForLanguage(saved);
      }
    } catch (exception) {
      // Do not leave the UI in a language that could not be saved or synced.
      selectedLanguageCode.value = previousCode;
      appLocale.value = previousLocale;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            exception is ApiException
                ? exception.message
                : 'Could not change language. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: AppText(context.tr('Choose language')),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (saving) const LinearProgressIndicator(),
              for (final language in appLanguages)
                ListTile(
                  title: AppText(language.$2),
                  subtitle: AppText(
                    language.$3,
                    style: const TextStyle(color: muted),
                  ),
                  selected: language.$1 == selectedCode,
                  trailing: language.$1 == selectedCode
                      ? const Icon(Icons.check, color: brand)
                      : null,
                  enabled: !saving,
                  onTap: () {
                    setState(() => selectedCode = language.$1);
                    _submit();
                  },
                ),
              if (error != null)
                AppText(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

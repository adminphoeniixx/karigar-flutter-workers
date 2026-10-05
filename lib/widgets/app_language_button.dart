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
    setState(() {
      saving = true;
      error = null;
    });
    try {
      // Hinglish is an app-only display preference; the worker API accepts
      // only its standard locale codes.
      final saved = widget.persistLocally || selectedCode == 'hinglish'
          ? selectedCode
          : await (widget.saveLocale?.call(selectedCode) ??
                WorkerApiService().setLocale(selectedCode));
      if (!appLanguages.any((language) => language.$1 == saved)) {
        throw StateError('Unsupported language');
      }
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString('app_locale', saved)) {
        throw StateError('Could not save language');
      }
      selectedLanguageCode.value = saved;
      appLocale.value = _localeForLanguage(saved);
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception is ApiException
              ? exception.message
              : 'Could not change language. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
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

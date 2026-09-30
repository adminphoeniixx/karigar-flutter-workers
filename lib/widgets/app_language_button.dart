part of '../main.dart';

const appLanguages = [
  ('en', 'English'),
  ('hi', 'हिन्दी'),
  ('ta', 'தமிழ்'),
  ('te', 'తెలుగు'),
  ('bn', 'বাংলা'),
  ('mr', 'मराठी'),
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
  const _LanguageDialog({this.saveLocale});
  final Future<String> Function(String)? saveLocale;
  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  bool saving = false;
  String? error;

  Future<void> _select(String code) async {
    if (saving) return;
    if (code == appLocale.value.languageCode) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved =
          await (widget.saveLocale?.call(code) ??
              WorkerApiService().setLocale(code));
      if (!appLanguages.any((language) => language.$1 == saved)) {
        throw StateError('Unsupported language');
      }
      final preferences = await SharedPreferences.getInstance();
      if (!await preferences.setString('app_locale', saved)) {
        throw StateError('Could not save language');
      }
      appLocale.value = Locale(saved);
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
                  selected: language.$1 == appLocale.value.languageCode,
                  trailing: language.$1 == appLocale.value.languageCode
                      ? const Icon(Icons.check, color: brand)
                      : null,
                  enabled: !saving,
                  onTap: () => _select(language.$1),
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

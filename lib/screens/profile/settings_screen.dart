part of '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool dark = false, alerts = true;

  @override
  void initState() {
    super.initState();
    dark = appThemeMode.value == ThemeMode.dark;
  }

  void _setDark(bool value) {
    setState(() => dark = value);
    appThemeMode.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  void _languages() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose language',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick your preferred app language · English, हिन्दी, தமிழ் & more',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...[
            ('English', 'English'),
            ('हिन्दी', 'Hindi'),
            ('தமிழ்', 'Tamil'),
            ('తెలుగు', 'Telugu'),
            ('বাংলা', 'Bengali'),
          ].map(
            (e) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                side: BorderSide(color: context.borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                e.$1,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(e.$2),
              trailing: e.$2 == 'English'
                  ? const Icon(LucideIcons.check, color: brand)
                  : null,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Settings', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            'PREFERENCES',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        MenuRow(LucideIcons.languages, 'Language', 'English', _languages),
        MenuRow(
          LucideIcons.moon,
          'Dark theme',
          'Switch to a darker screen',
          () => _setDark(!dark),
          trailing: Switch(
            value: dark,
            activeTrackColor: brand,
            onChanged: _setDark,
          ),
        ),
        MenuRow(
          LucideIcons.bell,
          'Job alerts',
          'Get notified about new jobs',
          () => setState(() => alerts = !alerts),
          trailing: Switch(
            value: alerts,
            activeTrackColor: brand,
            onChanged: (v) => setState(() => alerts = v),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 6),
          child: Text(
            'ACCOUNT & SECURITY',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        MenuRow(
          LucideIcons.lockKeyhole,
          'Login & security',
          'OTP · device sessions',
          () {},
        ),
        MenuRow(LucideIcons.fileText, 'Terms & Privacy', '', () {}),
        MenuRow(LucideIcons.circleHelp, 'Help & Support', '', () {}),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE11D48),
              side: const BorderSide(color: Color(0xFFFFF1F2)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingPage()),
              (_) => false,
            ),
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Log out'),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Karigar · v1.0.0',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

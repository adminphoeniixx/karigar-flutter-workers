part of '../../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool dark = false,
      alerts = true,
      messageAlerts = true,
      preferencesLoading = true;
  @override
  void initState() {
    super.initState();
    dark = appThemeMode.value == ThemeMode.dark;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final value = await WorkerApiService().fetchPreferences();
      if (!mounted) return;
      setState(() {
        alerts = value.jobAlerts;
        messageAlerts = value.messageAlerts;
        appThemeMode.value = switch (value.theme) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        };
        dark = value.theme == 'dark';
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => preferencesLoading = false);
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    try {
      await WorkerApiService().updatePreferences({key: value});
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
        await _loadPreferences();
      }
    }
  }

  void _setDark(bool value) {
    setState(() => dark = value);
    appThemeMode.value = value ? ThemeMode.dark : ThemeMode.light;
    _savePreference('theme', value ? 'dark' : 'light');
  }

  Future<void> _logout() async {
    try {
      await AuthService().logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Logged out successfully.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Delete account permanently?'),
        content: const AppText(
          'Your profile and account data will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Your account has been deleted.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingPage()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: AppText(
        context.tr('Settings'),
        style: const TextStyle(fontSize: 16),
      ),
    ),
    body: ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: AppText(
            context.tr('Preferences').toUpperCase(),
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        MenuRow(
          LucideIcons.moon,
          context.tr('Dark theme'),
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
          context.tr('Job alerts'),
          'Get notified about new jobs',
          () => setState(() => alerts = !alerts),
          trailing: Switch(
            value: alerts,
            activeTrackColor: brand,
            onChanged: preferencesLoading
                ? null
                : (v) {
                    setState(() => alerts = v);
                    _savePreference('job_alerts', v);
                  },
          ),
        ),
        MenuRow(
          LucideIcons.messageCircle,
          'Message alerts',
          'Get notified about employer messages',
          () {
            setState(() => messageAlerts = !messageAlerts);
            _savePreference('message_alerts', messageAlerts);
          },
          trailing: Switch(
            value: messageAlerts,
            activeTrackColor: brand,
            onChanged: preferencesLoading
                ? null
                : (v) {
                    setState(() => messageAlerts = v);
                    _savePreference('message_alerts', v);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
          child: AppText(
            context.tr('Account & security').toUpperCase(),
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        MenuRow(
          LucideIcons.lockKeyhole,
          context.tr('Login & security'),
          'OTP · device sessions',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionsPage()),
          ),
        ),
        MenuRow(
          LucideIcons.fileText,
          context.tr('Terms & Privacy'),
          'Terms of use and privacy policy',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegalDocumentsPage()),
          ),
        ),
        MenuRow(
          LucideIcons.circleHelp,
          context.tr('Help & Support'),
          'FAQs and contact support',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpSupportPage()),
          ),
        ),
        MenuRow(
          LucideIcons.trash2,
          context.tr('Delete account'),
          'Permanently remove your account',
          _deleteAccount,
        ),
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
            onPressed: _logout,
            icon: const Icon(LucideIcons.logOut),
            label: AppText(context.tr('Log out')),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: AppText(
            'Super Karigar Worker · v1.0.0',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class LegalDocumentsPage extends StatefulWidget {
  const LegalDocumentsPage({super.key});

  @override
  State<LegalDocumentsPage> createState() => _LegalDocumentsPageState();
}

class _LegalDocumentsPageState extends State<LegalDocumentsPage> {
  List<dynamic> documents = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final response = await WorkerApiService().legal();
      if (mounted) setState(() => documents = jsonList(response['documents']));
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Terms & Privacy')),
    body: error != null
        ? _SettingsLoadError(message: error!, onRetry: _load)
        : documents.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: documents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final document = jsonMap(documents[index]);
                return AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.fileText, color: brand),
                    title: AppText(
                      document['title']?.toString() ?? 'Legal document',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: AppText(
                        '${document['summary'] ?? ''}\n${context.trArgs('Updated {date}', {'date': '${document['updated_label'] ?? ''}'})}',
                      ),
                    ),
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LegalDocumentPage(
                          keyName: document['key']?.toString() ?? '',
                          initialTitle:
                              document['title']?.toString() ?? 'Legal document',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.keyName,
    required this.initialTitle,
  });
  final String keyName, initialTitle;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Map<String, dynamic>? document;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final response = await WorkerApiService().legalDocument(widget.keyName);
      if (mounted) setState(() => document = jsonMap(response['document']));
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: AppText(document?['title']?.toString() ?? widget.initialTitle),
    ),
    body: error != null
        ? _SettingsLoadError(message: error!, onRetry: _load)
        : document == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppText(
                context.trArgs('Updated {date}', {
                  'date': '${document!['updated_label'] ?? ''}',
                }),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              AppText(
                document!['intro']?.toString() ?? '',
                style: const TextStyle(height: 1.55),
              ),
              ...jsonList(document!['sections']).expand((value) {
                final section = jsonMap(value);
                return <Widget>[
                  const SizedBox(height: 24),
                  AppText(
                    section['title']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...jsonList(section['blocks']).map(_legalBlock),
                ];
              }),
            ],
          ),
  );

  Widget _legalBlock(dynamic value) {
    final block = jsonMap(value);
    final type = block['type']?.toString();
    if (type == 'list') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          children: jsonList(block['items'])
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText('•  ', style: TextStyle(height: 1.5)),
                      Expanded(
                        child: AppText(
                          item.toString(),
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    if (type == 'heading') {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: AppText(
          block['text']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppText(
        block['text']?.toString() ?? '',
        style: const TextStyle(height: 1.5),
      ),
    );
  }
}

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  Map<String, dynamic>? support;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final response = await WorkerApiService().support();
      if (mounted) setState(() => support = response);
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _openChannel(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to open this link.')),
      );
  }

  Future<void> _email(String address) async {
    final opened = await launchUrl(Uri(scheme: 'mailto', path: address));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('No email app is available.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = jsonMap(support?['channels']);
    final faqs = jsonList(support?['faqs']);
    return Scaffold(
      appBar: AppBar(title: const AppText('Help & Support')),
      body: error != null
          ? _SettingsLoadError(message: error!, onRetry: _load)
          : support == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Contact support',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        AppText(
                          channels['hours']?.toString() ?? '',
                          style: const TextStyle(color: muted),
                        ),
                        const SizedBox(height: 14),
                        if (channels['email']?.toString().trim().isNotEmpty ==
                            true)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _email(channels['email'].toString()),
                              icon: const Icon(LucideIcons.mail, size: 18),
                              label: Text(channels['email'].toString()),
                            ),
                          ),
                        if (channels['phone']?.toString().trim().isNotEmpty ==
                            true)
                          TextButton.icon(
                            onPressed: () => _openChannel(
                              Uri(
                                scheme: 'tel',
                                path: channels['phone'].toString(),
                              ),
                            ),
                            icon: const Icon(LucideIcons.phone, size: 18),
                            label: Text(channels['phone'].toString()),
                          ),
                        if (channels['whatsapp']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          TextButton.icon(
                            onPressed: () => _openChannel(
                              Uri.https('wa.me', '/${channels['whatsapp']}'),
                            ),
                            icon: const Icon(
                              LucideIcons.messageCircle,
                              size: 18,
                            ),
                            label: const Text('WhatsApp'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('Frequently asked questions'),
                  ...faqs.map((value) {
                    final faq = jsonMap(value);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ExpansionTile(
                        title: AppText(
                          faq['question']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          AppText(
                            faq['answer']?.toString() ?? '',
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.wifiOff, color: muted, size: 40),
          const SizedBox(height: 12),
          AppText(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: const AppText('Try again'),
          ),
        ],
      ),
    ),
  );
}

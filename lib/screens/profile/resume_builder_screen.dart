part of '../../main.dart';

/// The builder deliberately keeps its data as JSON.  The API owns the AI
/// schema, while this screen only exposes the fields a worker can change.
class ResumeBuilderPage extends StatefulWidget {
  const ResumeBuilderPage({super.key});

  @override
  State<ResumeBuilderPage> createState() => _ResumeBuilderPageState();
}

class _ResumeBuilderPageState extends State<ResumeBuilderPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _jobs = <Map<String, TextEditingController>>[];
  Map<String, dynamic>? _resume;
  Map<String, dynamic> _serverErrors = {};
  bool _loading = true, _writing = false, _saving = false;
  String _language = 'en';
  bool _relocate = false;

  static const _fieldLabels = {
    'name': 'Full name *',
    'phone': 'Phone',
    'email': 'Email',
    'city': 'City',
    'state': 'State',
    'trade': 'What work do you do? *',
    'experience_years': 'Total experience (years)',
    'skills': 'Skills (separate with commas)',
    'tools': 'Tools / machines',
    'education': 'Education',
    'training': 'Training / certificates',
    'languages': 'Languages you speak (separate with commas)',
    'about': 'About you',
    'achievements': 'Achievements',
    'expected_wage': 'Expected monthly salary (₹)',
  };

  TextEditingController _controller(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);
  Map<String, TextEditingController> _newJob([Map? value]) => {
    for (final key in ['role', 'employer', 'place', 'from', 'to', 'details'])
      key: TextEditingController(text: value?[key]?.toString() ?? ''),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await WorkerApiService().resumeBuilder();
      final form = data['form'] is Map
          ? Map<String, dynamic>.from(data['form'])
          : <String, dynamic>{};
      for (final key in _fieldLabels.keys) {
        final value = form[key];
        _controller(key).text = value is List
            ? value.join(', ')
            : value?.toString() ?? '';
      }
      _language = form['language']?.toString() == 'hi' ? 'hi' : 'en';
      _relocate = form['relocate'] == true;
      final work = form['work'] as List? ?? const [];
      _jobs.addAll(work.whereType<Map>().map(_newJob));
      if (_jobs.isEmpty) _jobs.add(_newJob());
      final saved = data['saved'];
      if (saved is Map) _resume = Map<String, dynamic>.from(saved);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _answers() => {
    'language': _language,
    'name': _controller('name').text.trim(),
    'phone': _controller('phone').text.trim(),
    'email': _controller('email').text.trim(),
    'city': _controller('city').text.trim(),
    'state': _controller('state').text.trim(),
    'trade': _controller('trade').text.trim(),
    'experience_years':
        num.tryParse(_controller('experience_years').text.trim()) ?? 0,
    'skills': _tags(_controller('skills').text),
    'tools': _controller('tools').text.trim(),
    'work': _jobs
        .where((j) => j['role']!.text.trim().isNotEmpty)
        .map((j) => j.map((k, v) => MapEntry(k, v.text.trim())))
        .toList(),
    'education': _controller('education').text.trim(),
    'training': _controller('training').text.trim(),
    'languages': _tags(_controller('languages').text),
    'about': _controller('about').text.trim(),
    'achievements': _controller('achievements').text.trim(),
    'expected_wage': num.tryParse(_controller('expected_wage').text.trim()),
    'relocate': _relocate,
  }..removeWhere((key, value) => value == null);
  List<String> _tags(String value) =>
      value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  String? _error(String key) {
    final error = _serverErrors[key];
    return error is List && error.isNotEmpty
        ? error.first.toString()
        : error?.toString();
  }

  void _message(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(text)));

  Future<void> _draft() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _writing = true;
      _serverErrors = {};
    });
    try {
      final value = await WorkerApiService().draftResume(_answers());
      if (mounted)
        setState(
          () => _resume = Map<String, dynamic>.from(value['resume'] as Map),
        );
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverErrors = e.errors);
      _message(
        e.statusCode == 429 ? 'Wait a minute and try again.' : e.message,
      );
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _save() async {
    if (_resume == null) return;
    setState(() => _saving = true);
    try {
      final result = await WorkerApiService().saveBuiltResume({
        ..._answers(),
        'resume': _resume,
      });
      if (!mounted) return;
      _message(result['message']?.toString() ?? 'Your resume is ready');
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Your resume is ready'),
          content: const Text(
            'Your new PDF is now used for employer downloads and match scores.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                _openPdf();
              },
              child: const Text('Open PDF'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPdf() async {
    try {
      final file = await WorkerApiService().downloadResumePdf();
      if (!mounted) return;
      final opened = await launchUrl(
        file.uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _message(
          'PDF downloaded, but no PDF viewer is available on this device.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) _message(e.message);
    }
  }

  Widget _input(String key, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _controller(key),
      maxLines: maxLines,
      keyboardType: key == 'expected_wage' || key == 'experience_years'
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: _fieldLabels[key],
        errorText: _error(key),
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        final text = v?.trim() ?? '';
        if ((key == 'name' || key == 'trade') && text.isEmpty)
          return 'This field is required.';
        if (key == 'email' &&
            text.isNotEmpty &&
            !RegExp(r'^\S+@\S+\.\S+$').hasMatch(text))
          return 'Enter a valid email.';
        final limit = {
          'name': 100,
          'trade': 100,
          'phone': 20,
          'city': 80,
          'state': 80,
          'tools': 300,
          'about': 600,
          'achievements': 600,
        }[key];
        return limit != null && text.length > limit
            ? 'Use at most $limit characters.'
            : null;
      },
    ),
  );

  Widget _details() => Form(
    key: _formKey,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Your details',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can write in Hinglish. AI will make it neat.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'hi', label: Text('हिंदी')),
          ],
          selected: {_language},
          onSelectionChanged: (v) => setState(() => _language = v.first),
        ),
        const SizedBox(height: 16),
        _input('name'),
        _input('phone'),
        _input('email'),
        _input('city'),
        _input('state'),
        _input('trade'),
        _input('experience_years'),
        _input('skills'),
        _input('tools', maxLines: 2),
        const Text(
          'Work experience',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        ..._jobs.asMap().entries.map(
          (entry) => _jobCard(entry.key, entry.value),
        ),
        TextButton.icon(
          onPressed: _jobs.length >= 5
              ? null
              : () => setState(() => _jobs.add(_newJob())),
          icon: const Icon(LucideIcons.plus),
          label: const Text('Add work experience'),
        ),
        _input('education'),
        _input('training', maxLines: 2),
        _input('languages'),
        _input('about', maxLines: 4),
        _input('achievements', maxLines: 4),
        _input('expected_wage'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ready to travel / relocate'),
          value: _relocate,
          onChanged: (v) => setState(() => _relocate = v),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _writing ? null : _draft,
          icon: _writing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.sparkles),
          label: AppText(
            _writing
                ? 'Your resume is being written…'
                : 'Write my resume with AI',
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );

  Widget _jobCard(int index, Map<String, TextEditingController> job) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppText(
              'Job ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (_jobs.length > 1)
              IconButton(
                onPressed: () => setState(() => _jobs.removeAt(index)),
                icon: const Icon(LucideIcons.trash2),
              ),
          ],
        ),
        for (final item in [
          ('role', 'Role *'),
          ('employer', 'Employer'),
          ('place', 'Place'),
          ('from', 'From'),
          ('to', 'To'),
          ('details', 'What did you do there?'),
        ])
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextFormField(
              controller: job[item.$1],
              maxLines: item.$1 == 'details' ? 3 : 1,
              decoration: InputDecoration(
                labelText: item.$2,
                errorText: _error('work.$index.${item.$1}'),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _reviewInput(String label, String key, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: _resume![key] is List
          ? (_resume![key] as List).join('\n')
          : _resume![key]?.toString() ?? '',
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => _resume![key] =
          key == 'skills' ||
              key == 'education' ||
              key == 'languages' ||
              key == 'extras'
          ? v
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : v,
    ),
  );
  Widget _review() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Check & save',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const Text(
        'Edit the wording before saving your PDF.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              _resume!['name']?.toString() ?? _controller('name').text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            AppText(_resume!['phone']?.toString() ?? _controller('phone').text),
            AppText(
              _resume!['location']?.toString() ??
                  '${_controller('city').text}, ${_controller('state').text}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _reviewInput('Headline', 'headline'),
      _reviewInput('Summary', 'summary', lines: 4),
      _reviewInput('Skills (one per line)', 'skills', lines: 3),
      ..._experienceEditors(),
      _reviewInput('Education (one per line)', 'education', lines: 3),
      _reviewInput('Languages (one per line)', 'languages', lines: 3),
      _reviewInput('Extras (one per line)', 'extras', lines: 3),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _resume = null),
              child: const Text('Edit details'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: _writing ? null : _draft,
              child: const Text('Write again'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: AppText(_saving ? 'Saving…' : 'Save as my resume'),
      ),
      const SizedBox(height: 16),
    ],
  );
  List<Widget> _experienceEditors() {
    final experiences = (_resume!['experience'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return experiences.asMap().entries.expand((entry) {
      final index = entry.key;
      final item = Map<String, dynamic>.from(entry.value);
      return [
        AppCard(
          child: Column(
            children: [
              TextFormField(
                initialValue: item['role']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  item['role'] = v;
                  (_resume!['experience'] as List)[index] = item;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: item['period']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  item['period'] = v;
                  (_resume!['experience'] as List)[index] = item;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: (item['points'] as List? ?? []).join('\n'),
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Work points (one per line)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  item['points'] = v
                      .split('\n')
                      .where((e) => e.trim().isNotEmpty)
                      .toList();
                  (_resume!['experience'] as List)[index] = item;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ];
    }).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Resume Builder')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _resume == null
        ? _details()
        : _review(),
  );
  @override
  void dispose() {
    for (final c in _fields.values) c.dispose();
    for (final j in _jobs) {
      for (final c in j.values) c.dispose();
    }
    super.dispose();
  }
}

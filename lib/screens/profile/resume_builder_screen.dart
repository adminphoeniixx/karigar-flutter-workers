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
  final _currentJobs = <bool>[];
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
      for (final item in work.whereType<Map>()) {
        _jobs.add(_newJob(item));
        _currentJobs.add(item['current'] == true);
      }
      if (_jobs.isEmpty) {
        _jobs.add(_newJob());
        _currentJobs.add(false);
      }
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
        .asMap()
        .entries
        .where((entry) => entry.value['role']!.text.trim().isNotEmpty)
        .map(
          (entry) => {
            ...entry.value.map((k, v) => MapEntry(k, v.text.trim())),
            'current': _currentJobs[entry.key],
          },
        )
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

  String? _answerError() {
    final skills = _tags(_controller('skills').text);
    final languages = _tags(_controller('languages').text);
    if (skills.length > 20 || skills.any((value) => value.length > 60)) {
      return 'Add up to 20 skills, with at most 60 characters each.';
    }
    if (languages.length > 8) return 'Add up to 8 languages.';
    final years = num.tryParse(_controller('experience_years').text.trim());
    if (years != null && (years < 0 || years > 60)) {
      return 'Experience must be between 0 and 60 years.';
    }
    for (final job in _jobs) {
      const limits = {
        'role': 100,
        'employer': 120,
        'place': 80,
        'from': 20,
        'to': 20,
        'details': 600,
      };
      for (final entry in limits.entries) {
        if (job[entry.key]!.text.trim().length > entry.value) {
          return '${entry.key[0].toUpperCase()}${entry.key.substring(1)} is too long.';
        }
      }
    }
    return null;
  }

  Future<void> _draft() async {
    if (!_formKey.currentState!.validate()) return;
    final answerError = _answerError();
    if (answerError != null) {
      _message(answerError);
      return;
    }
    setState(() {
      _writing = true;
      _serverErrors = {};
    });
    try {
      final value = await WorkerApiService().draftResume(_answers());
      if (mounted) {
        setState(
          () => _resume = Map<String, dynamic>.from(value['resume'] as Map),
        );
      }
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      maxLength: {
        'name': 100,
        'phone': 20,
        'city': 80,
        'state': 80,
        'trade': 100,
        'tools': 300,
        'education': 150,
        'training': 300,
        'about': 600,
        'achievements': 600,
      }[key],
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      validator: (v) {
        final text = v?.trim() ?? '';
        if ((key == 'name' || key == 'trade') && text.isEmpty) {
          return 'This field is required.';
        }
        if (key == 'email' &&
            text.isNotEmpty &&
            !RegExp(r'^\S+@\S+\.\S+$').hasMatch(text)) {
          return 'Enter a valid email.';
        }
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
        const FieldLabel('Resume language'),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(child: _languageChoice('en', 'English', 'ABC')),
            const SizedBox(width: 10),
            Expanded(child: _languageChoice('hi', 'हिंदी', 'अ')),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: AppText(
            _language == 'hi'
                ? 'Your resume will be written in Hindi.'
                : 'Your resume will be written in English.',
            key: ValueKey(_language),
            style: const TextStyle(color: muted, fontSize: 13),
          ),
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
        const SizedBox(height: 12),

        ..._jobs.asMap().entries.map(
          (entry) => _jobCard(entry.key, entry.value),
        ),
        TextButton.icon(
          onPressed: _jobs.length >= 5
              ? null
              : () => setState(() {
                  _jobs.add(_newJob());
                  _currentJobs.add(false);
                }),
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

  Widget _languageChoice(String value, String label, String icon) {
    final selected = _language == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _language = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: .10) : card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? brand : line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                color: selected ? brand : muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? brand : ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, color: brand, size: 17),
            ],
          ],
        ),
      ),
    );
  }

  Widget _jobCard(int index, Map<String, TextEditingController> job) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
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
                  onPressed: () => setState(() {
                    _jobs.removeAt(index);
                    _currentJobs.removeAt(index);
                  }),
                  icon: const Icon(LucideIcons.trash2),
                ),
            ],
          ),
          _jobField(index, job, 'role', 'Role *'),
          _jobField(index, job, 'employer', 'Employer'),
          _jobField(index, job, 'place', 'Place'),
          Row(
            children: [
              Expanded(child: _jobField(index, job, 'from', 'From')),
              const SizedBox(width: 10),
              Expanded(child: _jobField(index, job, 'to', 'To')),
            ],
          ),
          _jobField(index, job, 'details', 'What did you do there?', lines: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I currently work here'),
            value: _currentJobs[index],
            onChanged: (value) => setState(() => _currentJobs[index] = value),
          ),
        ],
      ),
    ),
  );

  Widget _jobField(
    int index,
    Map<String, TextEditingController> job,
    String key,
    String label, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      controller: job[key],
      maxLines: lines,
      maxLength: const {
        'role': 100,
        'employer': 120,
        'place': 80,
        'from': 20,
        'to': 20,
        'details': 600,
      }[key],
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration(
        labelText: label,
        errorText: _error('work.$index.$key'),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
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
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final j in _jobs) {
      for (final c in j.values) {
        c.dispose();
      }
    }
    super.dispose();
  }
}

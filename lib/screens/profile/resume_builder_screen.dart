part of '../../main.dart';

class ResumeBuilderPage extends StatefulWidget {
  const ResumeBuilderPage({super.key});
  @override
  State<ResumeBuilderPage> createState() => _ResumeBuilderPageState();
}

class _ResumeBuilderPageState extends State<ResumeBuilderPage> {
  final _fields = <String, TextEditingController>{};
  final _jobs = <Map<String, TextEditingController>>[];
  final _current = <bool>[];
  final _previewKey = GlobalKey();
  Timer? _previewTimer, _loaderTimer;
  Map<String, dynamic>? _resume, _record;
  Map<String, dynamic> _errors = {};
  List<String> _templates = ['modern', 'classic', 'bold'];
  List<String> _accents = ['#bf3a16', '#1e3a5f', '#4f6b4a', '#6b2d5c'];
  String _language = 'en', _template = 'modern', _accent = '#bf3a16';
  String? _photoUrl;
  bool _relocate = false, _showPhoto = true, _verified = false;
  bool _loading = true, _writing = false, _saving = false, _previewing = false;
  int _step = 0, _request = 0, _loaderLine = 0;
  List<int>? _preview;
  String _previewStatus = 'Waiting for your resume';

  static const _labels = <String, String>{
    'name': 'Full name *',
    'phone': 'Phone',
    'email': 'Email',
    'city': 'City',
    'state': 'State',
    'trade': 'What work do you do? *',
    'experience_years': 'Experience (years)',
    'skills': 'Skills (separate with commas)',
    'tools': 'Tools / machines you use',
    'education': 'Education',
    'training': 'Training / certificates',
    'languages': 'Languages (separate with commas)',
    'about': 'About you',
    'achievements': 'Achievements',
    'expected_wage': 'Expected monthly salary (₹)',
  };
  static const _limits = <String, int>{
    'name': 100,
    'phone': 20,
    'email': 150,
    'city': 80,
    'state': 80,
    'trade': 100,
    'tools': 300,
    'education': 150,
    'training': 300,
    'about': 600,
    'achievements': 600,
  };
  TextEditingController _c(String key) =>
      _fields.putIfAbsent(key, TextEditingController.new);
  Map<String, TextEditingController> _newJob([Map? value]) => {
    for (final key in ['role', 'employer', 'place', 'from', 'to', 'details'])
      key: TextEditingController(text: value?[key]?.toString() ?? ''),
  };
  String? _empty(String value) => value.trim().isEmpty ? null : value.trim();
  List<String> _tags(String text, [int max = 20]) => text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .take(max)
      .toList();
  List<String> _lines(String text) =>
      text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));

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
      for (final key in _labels.keys) {
        final value = form[key];
        _c(key).text = value is List
            ? value.join(', ')
            : value?.toString() ?? '';
      }
      _language = form['language'] == 'hi' ? 'hi' : 'en';
      _template = form['template']?.toString() ?? _template;
      _accent = form['accent']?.toString() ?? _accent;
      _showPhoto = form['show_photo'] != false;
      _relocate = form['relocate'] == true;
      _photoUrl = data['photo_url']?.toString();
      _verified = data['verified'] == true;
      _templates = (data['templates'] as List? ?? _templates)
          .map((e) => e.toString())
          .toList();
      _accents = (data['accents'] as List? ?? _accents)
          .map((e) => e.toString())
          .toList();
      for (final work in (form['work'] as List? ?? []).whereType<Map>()) {
        _jobs.add(_newJob(work));
        _current.add(work['current'] == true);
      }
      if (_jobs.isEmpty) {
        _jobs.add(_newJob());
        _current.add(false);
      }
      if (data['saved'] is Map) {
        _resume = Map<String, dynamic>.from(data['saved']);
        _step = 3;
      }
      if (data['resume'] is Map)
        _record = Map<String, dynamic>.from(data['resume']);
    } on ApiException catch (e) {
      _message(e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _answers() => {
    'language': _language,
    'name': _c('name').text.trim(),
    'phone': _c('phone').text.trim(),
    'email': _empty(_c('email').text),
    'city': _empty(_c('city').text),
    'state': _empty(_c('state').text),
    'trade': _c('trade').text.trim(),
    'experience_years': num.tryParse(_c('experience_years').text.trim()) ?? 0,
    'skills': _tags(_c('skills').text),
    'tools': _empty(_c('tools').text),
    'work': _jobs
        .asMap()
        .entries
        .where((e) => e.value['role']!.text.trim().isNotEmpty)
        .map(
          (e) => {
            for (final x in e.value.entries) x.key: _empty(x.value.text),
            'current': _current[e.key],
          },
        )
        .toList(),
    'education': _empty(_c('education').text),
    'training': _empty(_c('training').text),
    'languages': _tags(_c('languages').text, 8),
    'about': _empty(_c('about').text),
    'achievements': _empty(_c('achievements').text),
    'expected_wage': num.tryParse(_c('expected_wage').text.trim()),
    'relocate': _relocate,
    'template': _template,
    'accent': _accent,
    'show_photo': _showPhoto,
  };
  String? _error(String key) {
    final e = _errors[key];
    return e is List && e.isNotEmpty ? e.first.toString() : e?.toString();
  }

  bool _valid(int step) {
    final key = step == 0 ? 'name' : 'trade';
    if (_c(key).text.trim().isNotEmpty) return true;
    setState(
      () => _errors = {
        ..._errors,
        key: ['Please fill this in.'],
      },
    );
    return false;
  }

  void _next() {
    if (_step < 2 && !_valid(_step)) return;
    setState(() => _step++);
  }

  Future<void> _photo() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final file = File(image.path);
    if (await file.length() > 2 * 1024 * 1024) {
      _message('Please choose an image smaller than 2 MB.');
      return;
    }
    try {
      final url = await WorkerApiService().uploadAvatar(file);
      if (mounted) setState(() => _photoUrl = url);
    } on ApiException catch (e) {
      _message(e.message);
    }
  }

  Future<void> _draft() async {
    if (!_valid(0) || !_valid(1)) return;
    setState(() {
      _writing = true;
      _errors = {};
    });
    _loaderTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _loaderLine = (_loaderLine + 1) % 4);
    });
    try {
      final value = await WorkerApiService().draftResume(_answers());
      if (mounted)
        setState(() {
          _resume = Map<String, dynamic>.from(value['resume'] as Map);
          _step = 3;
        });
      _debouncePreview(const Duration(milliseconds: 50));
    } on ApiException catch (e) {
      if (mounted) setState(() => _errors = e.errors);
      _message(
        e.statusCode == 429
            ? 'Too many tries. Please wait a minute and try again.'
            : e.statusCode == 422
            ? 'Please fix the fields marked in red.'
            : 'Could not write the resume right now. Please try again.',
      );
      if (e.statusCode == 422) {
        final keys = e.errors.keys;
        setState(
          () => _step =
              keys.any(
                (k) => ['name', 'phone', 'email', 'city', 'state'].contains(k),
              )
              ? 0
              : keys.any(
                  (k) => k == 'trade' || k.startsWith('work') || k == 'skills',
                )
              ? 1
              : 2,
        );
      }
    } finally {
      _loaderTimer?.cancel();
      if (mounted) setState(() => _writing = false);
    }
  }

  Map<String, dynamic> _saveBody() => {..._answers(), 'resume': _resume};
  void _debouncePreview(Duration duration) {
    if (_resume == null) return;
    _previewTimer?.cancel();
    _previewTimer = Timer(duration, _refreshPreview);
  }

  Future<void> _refreshPreview() async {
    if (_resume == null) return;
    final request = ++_request;
    if (mounted) setState(() => _previewing = true);
    try {
      final bytes = await WorkerApiService().previewBuiltResume(_saveBody());
      if (mounted && request == _request)
        setState(() {
          _preview = bytes;
          _previewStatus = 'Up to date';
        });
    } on ApiException {
      if (mounted && request == _request)
        setState(() => _previewStatus = 'Could not update');
    } finally {
      if (mounted && request == _request) setState(() => _previewing = false);
    }
  }

  Future<void> _openPreview() async {
    if (_preview == null) {
      await _refreshPreview();
      if (_preview == null) return;
    }
    final file = File(
      '${Directory.systemTemp.path}/super-karigar-resume-preview.pdf',
    );
    await file.writeAsBytes(_preview!, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done)
      _message(
        result.message.isEmpty
            ? 'No PDF viewer is available on this device.'
            : result.message,
      );
  }

  Future<void> _save() async {
    if (_resume == null) return;
    setState(() => _saving = true);
    try {
      final result = await WorkerApiService().saveBuiltResume(_saveBody());
      if (!mounted) return;
      setState(() {
        _record = result['resume'] is Map
            ? Map<String, dynamic>.from(result['resume'])
            : _record;
        _saving = false;
      });
      _message(result['message']?.toString() ?? 'Resume saved');
      // Return to Profile → Resume so its card reloads the newly saved file.
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      _message(e.message);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Widget _field(String key, {int lines = 1, String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _c(key),
      maxLines: lines,
      maxLength: _limits[key],
      keyboardType: key == 'experience_years' || key == 'expected_wage'
          ? TextInputType.number
          : null,
      onChanged: (_) {
        if (_errors.containsKey(key)) setState(() => _errors.remove(key));
      },
      decoration: InputDecoration(
        labelText: _labels[key],
        hintText: hint,
        errorText: _error(key),
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _stepper() => Row(
    children: List.generate(4, (i) {
      final labels = [
        'About you',
        'Your work',
        'Education & more',
        'Design & save',
      ];
      final icons = [
        Icons.person_outline,
        Icons.build_outlined,
        Icons.school_outlined,
        Icons.palette_outlined,
      ];
      final enabled = i < 3 || _resume != null;
      return Expanded(
        child: InkWell(
          onTap: enabled ? () => setState(() => _step = i) : null,
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _step == i ? brand : line,
                child: Icon(
                  icons[i],
                  size: 18,
                  color: _step == i ? Colors.white : muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: enabled ? ink : muted),
              ),
            ],
          ),
        ),
      );
    }),
  );
  Widget _strength() {
    final checks = [
      _photoUrl != null && _showPhoto,
      _c('trade').text.trim().isNotEmpty,
      _c('experience_years').text.trim().isNotEmpty,
      _tags(_c('skills').text).length >= 3,
      _jobs.any(
        (j) =>
            j['role']!.text.isNotEmpty &&
            j['details']!.text.trim().length >= 20,
      ),
      _c('tools').text.trim().isNotEmpty,
      _c('education').text.trim().isNotEmpty ||
          _c('training').text.trim().isNotEmpty,
      _tags(_c('languages').text).isNotEmpty,
      _c('about').text.trim().isNotEmpty ||
          _c('achievements').text.trim().isNotEmpty,
    ];
    final pct = (checks.where((x) => x).length * 100 / 9).round();
    final clr = pct >= 80
        ? Colors.green
        : pct >= 50
        ? Colors.amber
        : brand;
    return AppCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Resume strength  $pct%',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: LinearProgressIndicator(value: pct / 100, color: clr),
        children: [
          Text(
            pct >= 80
                ? 'Strong — employers will like this'
                : pct >= 50
                ? 'Good — a few more details will help'
                : 'Basic — add more details',
            style: TextStyle(color: clr),
          ),
          const SizedBox(height: 8),
          const Text(
            '💡 AI writes only from your answers. You can type in Hindi or Hinglish too.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _about() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'About you',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const Text(
        'This goes at the top of your resume. We filled in what your profile already has.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: _photoUrl == null
                  ? null
                  : NetworkImage(_photoUrl!),
              child: _photoUrl == null
                  ? Text(
                      _c('name').text.isEmpty
                          ? '?'
                          : _c('name').text[0].toUpperCase(),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _photoUrl == null
                    ? 'No photo yet. Resumes with a photo get more calls.'
                    : 'A clear photo makes your resume stand out.',
              ),
            ),
            if (_photoUrl == null)
              TextButton(onPressed: _photo, child: const Text('Add photo')),
          ],
        ),
      ),
      if (_photoUrl != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show photo on resume'),
          value: _showPhoto,
          onChanged: (v) {
            setState(() => _showPhoto = v);
            _debouncePreview(const Duration(milliseconds: 150));
          },
        ),
      const FieldLabel('Resume language'),
      Row(
        children: [
          Expanded(child: _languageButton('en', 'English')),
          const SizedBox(width: 8),
          Expanded(child: _languageButton('hi', 'हिंदी')),
        ],
      ),
      const SizedBox(height: 12),
      _field('name'),
      _field('phone', hint: '+91…'),
      _field('email', hint: 'you@example.com'),
      _field('city'),
      _field('state'),
    ],
  );
  Widget _languageButton(String id, String label) => OutlinedButton(
    onPressed: () => setState(() => _language = id),
    style: OutlinedButton.styleFrom(
      backgroundColor: _language == id ? brand.withValues(alpha: .1) : null,
    ),
    child: Text('${_language == id ? '✓ ' : ''}$label'),
  );
  Widget _work() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your work',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const Text(
        'What you do and what you are good at.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 16),
      _field('trade', hint: 'e.g. Zari embroidery karigar'),
      _field('experience_years'),
      _field('skills', hint: 'e.g. Aari work — type or pick'),
      _field('tools', lines: 2),
      const Text(
        'Work experience',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const Text(
        'Where have you worked? Add your latest job first.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 8),
      ..._jobs.asMap().entries.map((e) => _jobCard(e.key, e.value)),
      if (_jobs.length < 5)
        TextButton.icon(
          onPressed: () => setState(() {
            _jobs.add(_newJob());
            _current.add(false);
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add another job'),
        ),
    ],
  );
  Widget _jobCard(int i, Map<String, TextEditingController> job) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Job ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_jobs.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    for (final c in _jobs.removeAt(i).values) {
                      c.dispose();
                    }
                    _current.removeAt(i);
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          _jobField(i, job, 'role', 'Your work there *'),
          _jobField(i, job, 'employer', 'Workshop / company'),
          _jobField(i, job, 'place', 'Place'),
          Row(
            children: [
              Expanded(child: _jobField(i, job, 'from', 'From (year)')),
              const SizedBox(width: 8),
              Expanded(
                child: _jobField(
                  i,
                  job,
                  'to',
                  'To (year)',
                  enabled: !_current[i],
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I still work here'),
            value: _current[i],
            onChanged: (v) => setState(() => _current[i] = v),
          ),
          _jobField(i, job, 'details', 'What did you do there?', lines: 3),
        ],
      ),
    ),
  );
  Widget _jobField(
    int i,
    Map<String, TextEditingController> job,
    String key,
    String label, {
    int lines = 1,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: job[key],
      enabled: enabled,
      maxLines: lines,
      maxLength: const {
        'role': 100,
        'employer': 120,
        'place': 80,
        'from': 20,
        'to': 20,
        'details': 600,
      }[key],
      decoration: InputDecoration(
        labelText: label,
        errorText: _error('work.$i.$key'),
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _more() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Education & languages',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const Text(
        'Schooling, any course or training, and languages you speak.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 16),
      _field('education'),
      _field('training', lines: 2),
      _field('languages', hint: 'Hindi, English, Urdu'),
      const Text(
        'More about you',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      _field('about', lines: 3),
      _field('achievements', lines: 3),
      _field('expected_wage', hint: '15000'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ready to travel or move for work'),
        value: _relocate,
        onChanged: (v) => setState(() => _relocate = v),
      ),
    ],
  );
  Color _colour(String hex) =>
      Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
  Widget _designs() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose a design',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const Text(
        'Pick a layout and a colour. The preview updates as you go.',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 12),
      Row(
        children: _templates
            .map(
              (t) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      setState(() => _template = t);
                      _debouncePreview(const Duration(milliseconds: 150));
                    },
                    child: Container(
                      height: 104,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _template == t ? brand : line,
                          width: _template == t ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        children: [
                          Expanded(child: _miniature(t)),
                          Text(
                            '${_template == t ? '✓ ' : ''}${t[0].toUpperCase()}${t.substring(1)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 14),
      const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        children: _accents
            .map(
              (a) => Semantics(
                label: a,
                child: InkWell(
                  onTap: () {
                    setState(() => _accent = a);
                    _debouncePreview(const Duration(milliseconds: 150));
                  },
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: a == _accent ? ink : Colors.transparent,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: _colour(a),
                      child: a == _accent
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      if (_photoUrl != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show photo on resume'),
          value: _showPhoto,
          onChanged: (v) {
            setState(() => _showPhoto = v);
            _debouncePreview(const Duration(milliseconds: 150));
          },
        ),
      if (_verified)
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '✓  "Verified" badge on your resume',
            style: TextStyle(color: Colors.green),
          ),
        ),
      TextButton.icon(
        onPressed: () => Scrollable.ensureVisible(_previewKey.currentContext!),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('See the preview'),
      ),
    ],
  );
  Widget _miniature(String type) {
    final a = _colour(_accent);
    return Padding(
      // The thumbnail lives above its label in a short phone-sized card.
      // Keep this compact so the Bold header cannot overflow vertically.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: type == 'modern'
          ? Row(
              children: [
                Container(width: 18, color: const Color(0xFF241D19)),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 35, height: 6, color: a),
                      const SizedBox(height: 6),
                      ...List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(height: 3, color: line),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(height: type == 'bold' ? 22 : 4, color: a),
                const SizedBox(height: 5),
                ...List.generate(
                  4,
                  (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                    child: Container(height: 4, color: line),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _editor() {
    if (_resume == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your resume',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Change any line you like. The preview updates as you type.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _writing ? null : _draft,
              child: const Text('Write again with AI'),
            ),
          ],
        ),
        _resumeField('Headline', 'headline'),
        _resumeField('Profile', 'summary', lines: 4),
        _resumeField('Skills (one per line)', 'skills', lines: 3, array: true),
        ..._experience(),
        _resumeField(
          'Education (one per line)',
          'education',
          lines: 3,
          array: true,
        ),
        _resumeField(
          'Languages (one per line)',
          'languages',
          lines: 3,
          array: true,
        ),
        _resumeField(
          'More about you (one per line)',
          'extras',
          lines: 3,
          array: true,
        ),
      ],
    );
  }

  Widget _resumeField(
    String label,
    String key, {
    int lines = 1,
    bool array = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextFormField(
      initialValue: _resume![key] is List
          ? (_resume![key] as List).join('\n')
          : _resume![key]?.toString() ?? '',
      maxLines: lines,
      onChanged: (v) {
        _resume![key] = array ? _lines(v) : v;
        _debouncePreview(const Duration(milliseconds: 900));
      },
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  List<Widget> _experience() {
    final list = (_resume!['experience'] as List? ?? [])
        .whereType<Map>()
        .toList();
    return list.asMap().entries.map((entry) {
      final i = entry.key;
      final item = Map<String, dynamic>.from(entry.value);
      Widget f(String key, String label, {int lines = 1}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextFormField(
          initialValue: key == 'points'
              ? (item[key] as List? ?? []).join('\n')
              : item[key]?.toString() ?? '',
          maxLines: lines,
          onChanged: (v) {
            item[key] = key == 'points' ? _lines(v).take(6).toList() : v;
            (_resume!['experience'] as List)[i] = item;
            _debouncePreview(const Duration(milliseconds: 900));
          },
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Work experience ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              f('role', 'Role'),
              f('period', 'Period (e.g. 2019 – 2023)'),
              Text(
                '${item['employer'] ?? ''} ${item['place'] ?? ''}',
                style: const TextStyle(color: muted),
              ),
              f('points', 'Work points (one per line)', lines: 4),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _previewCard() => Container(
    key: _previewKey,
    margin: const EdgeInsets.only(top: 16),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                Icons.circle,
                size: 10,
                color: _previewStatus == 'Up to date'
                    ? Colors.green
                    : _previewStatus.startsWith('Could')
                    ? Colors.red
                    : Colors.amber,
              ),
              const SizedBox(width: 5),
              Text(_previewStatus, style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: line),
            ),
            child: Center(
              child: _previewing
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 40,
                          color: _preview == null ? muted : brand,
                        ),
                        Text(
                          _preview == null
                              ? 'Your PDF preview will appear here'
                              : 'PDF preview is ready',
                        ),
                        if (_preview != null)
                          const SizedBox(height: 6),
                        if (_preview != null)
                          TextButton(
                            onPressed: _openPreview,
                            child: const Text('Open preview'),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _previewing ? null : _refreshPreview,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _preview == null ? null : _openPreview,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _ready() => _record?['source'] == 'ai'
      ? Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your resume is ready',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Saved ${_record?['uploaded_ago'] ?? ''}. Employers download it when you apply.',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final f = await WorkerApiService().downloadResumePdf();
                      await OpenFilex.open(f.path, type: 'application/pdf');
                    } on ApiException catch (e) {
                      _message(e.message);
                    }
                  },
                  child: const Text('Download PDF'),
                ),
              ],
            ),
          ),
        )
      : const SizedBox();
  Widget _actions() {
    if (_step == 3)
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 2),
              child: const Text('← Edit answers'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save as my resume'),
            ),
          ),
        ],
      );
    if (_step == 2)
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _writing ? null : _draft,
              icon: const Icon(Icons.auto_awesome),
              label: Text(
                _resume == null
                    ? 'Write my resume with AI'
                    : 'Write again with AI',
              ),
            ),
          ),
          if (_resume != null)
            TextButton(
              onPressed: () {
                setState(() => _step = 3);
                _debouncePreview(const Duration(milliseconds: 50));
              },
              child: const Text('Keep my current resume and go to design →'),
            ),
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Back'),
            ),
        ],
      );
    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Back'),
            ),
          ),
        if (_step > 0) const SizedBox(width: 10),
        Expanded(
          child: FilledButton(onPressed: _next, child: const Text('Next')),
        ),
      ],
    );
  }

  Widget _content() {
    final page = _step == 0
        ? _about()
        : _step == 1
        ? _work()
        : _step == 2
        ? _more()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _designs(),
              const SizedBox(height: 20),
              _editor(),
              _previewCard(),
            ],
          );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ready(),
        const Text(
          'AI Resume',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Answer a few questions. AI writes a professional resume, you pick a design, and employers can download it.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 20),
        _stepper(),
        const SizedBox(height: 14),
        if (_step < 3) _strength(),
        const SizedBox(height: 18),
        page,
        const SizedBox(height: 16),
        _actions(),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _overlay() {
    const lines = [
      'Reading your work history…',
      'Writing your profile…',
      'Turning your work into clear points…',
      'Laying out your resume…',
    ];
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: AppCard(
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: brand, size: 38),
                  const SizedBox(height: 12),
                  const Text(
                    'AI is writing your resume',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(lines[_loaderLine]),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                    'This takes about 10 seconds.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Resume')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Stack(children: [_content(), if (_writing) _overlay()]),
  );
  @override
  void dispose() {
    _previewTimer?.cancel();
    _loaderTimer?.cancel();
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final job in _jobs) {
      for (final c in job.values) {
        c.dispose();
      }
    }
    super.dispose();
  }
}

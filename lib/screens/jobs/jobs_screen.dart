part of '../../main.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  String query = '';
  String cat = 'All';
  String? filterState, filterCity, filterSkill;
  List<Job> apiJobs = [];
  List<String> categories = ['All'];
  List<String> states = [], skills = [];
  bool loading = true;
  String? error;
  Timer? searchTimer;

  @override
  void initState() {
    super.initState();
    _loadReference();
    _load();
  }

  Future<void> _loadReference() async {
    try {
      final reference = await WorkerApiService().reference();
      if (mounted) {
        setState(() {
        states = reference.states;
        skills = reference.skills;
        categories = ['All', ...reference.jobCategories];
      });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  void _search(String value) {
    query = value;
    searchTimer?.cancel();
    searchTimer = Timer(const Duration(milliseconds: 450), _load);
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => JobsApiFilterSheet(
        states: states,
        skills: skills,
        categories: categories.where((e) => e != 'All').toList(),
        selectedState: filterState,
        selectedCity: filterCity,
        selectedCategory: cat == 'All' ? null : cat,
        selectedSkill: filterSkill,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      filterState = result['state'];
      filterCity = result['city'];
      filterSkill = result['skill'];
      cat = result['category'] ?? 'All';
    });
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job filters applied successfully.')),
      );
    }
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final service = WorkerApiService();
      final response = await service.fetchJobs(filters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (cat != 'All') 'category': cat,
        if (filterState != null) 'state': filterState,
        if (filterCity != null) 'city': filterCity,
        if (filterSkill != null) 'skill': filterSkill,
      });
      if (!mounted) return;
      setState(() {
        apiJobs = response.jobs.map(Job.fromApi).toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => this.error = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  void dispose() {
    searchTimer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final filtered = apiJobs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Jobs'),
        actions: [
          IconButton(
            onPressed: _openFilter,
            icon: const Icon(LucideIcons.slidersHorizontal),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    hintText: 'Search job title, skill…',
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        categories.map((e) {
                          final active = cat == e;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() => cat = e);
                                _load();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? const Color(0xFFFFF3EE)
                                      : context.surfaceColor,
                                  border: Border.all(
                                    color: active
                                        ? const Color(0xFFFFE3D8)
                                        : context.borderColor,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  e,
                                  style: TextStyle(
                                    color: active
                                        ? const Color(0xFFC93A06)
                                        : muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${filtered.length} jobs${filterCity != null ? ' · $filterCity' : ''} · matched to your filters',
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (error != null)
                  AppCard(
                    child: Column(
                      children: [
                        const Icon(LucideIcons.triangleAlert, color: brand),
                        const SizedBox(height: 8),
                        Text(error!, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  )
                else if (filtered.isEmpty)
                  const AppCard(
                    child: Column(
                      children: [
                        Icon(LucideIcons.searchX, color: muted, size: 30),
                        SizedBox(height: 8),
                        Text('No matching jobs found', style: TextStyle(fontWeight: FontWeight.w700)),
                        SizedBox(height: 3),
                        Text('Try changing your search or filters.', style: TextStyle(color: muted)),
                      ],
                    ),
                  )
                else
                  ...filtered.map(JobCard.new),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JobsApiFilterSheet extends StatefulWidget {
  const JobsApiFilterSheet({super.key, required this.states, required this.skills, required this.categories, this.selectedState, this.selectedCity, this.selectedCategory, this.selectedSkill});
  final List<String> states, skills, categories;
  final String? selectedState, selectedCity, selectedCategory, selectedSkill;
  @override
  State<JobsApiFilterSheet> createState() => _JobsApiFilterSheetState();
}

class _JobsApiFilterSheetState extends State<JobsApiFilterSheet> {
  String? state, city, category, skill;
  List<String> cities = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    state = widget.selectedState;
    city = widget.selectedCity;
    category = widget.selectedCategory;
    skill = widget.selectedSkill;
    if (state != null) _loadCities(state!, keepCity: true);
  }

  Future<void> _loadCities(String value, {bool keepCity = false}) async {
    setState(() { state = value; if (!keepCity) city = null; loading = true; });
    try {
      final result = await WorkerApiService().cities(value);
      if (mounted && state == value) setState(() => cities = result);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Filter jobs', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        const FieldLabel('Category'),
        DropdownButtonFormField<String>(initialValue: category, isExpanded: true, hint: const Text('All categories'), items: widget.categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => category = v)),
        const SizedBox(height: 14),
        const FieldLabel('Skill'),
        DropdownButtonFormField<String>(initialValue: skill, isExpanded: true, menuMaxHeight: 400, hint: const Text('All skills'), items: widget.skills.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => skill = v)),
        const SizedBox(height: 14),
        const FieldLabel('State'),
        DropdownButtonFormField<String>(initialValue: state, isExpanded: true, menuMaxHeight: 400, hint: const Text('All states'), items: widget.states.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) { if (v != null) _loadCities(v); }),
        const SizedBox(height: 14),
        const FieldLabel('City'),
        DropdownButtonFormField<String>(key: ValueKey(state), initialValue: city, isExpanded: true, menuMaxHeight: 400, hint: Text(loading ? 'Loading cities...' : 'All cities'), items: cities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: loading ? null : (v) => setState(() => city = v)),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, <String, String?>{}), child: const Text('Reset'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, {'state': state, 'city': city, 'category': category, 'skill': skill}), child: const Text('Apply'))),
        ]),
      ]),
    ),
  );
}

class JobCard extends StatelessWidget {
  const JobCard(this.job, {super.key, this.trailing, this.onTap});
  final Job job;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          onTap ??
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => JobDetailPage(job)),
          ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tag(job.category),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (job.id > 0)
                      const StatusPill(
                        'New',
                        Color(0xFFECFDF5),
                        Color(0xFF047857),
                      ),
                    if (job.id > 0 && trailing != null)
                      const SizedBox(width: 6),
                    if (trailing != null) trailing!,
                  ],
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${job.employer} · ★ ${job.rating}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 7,
              children: [
                Meta(LucideIcons.mapPin, job.city),
                Meta(LucideIcons.indianRupee, job.wage, bold: true),
                Meta(LucideIcons.calendarDays, '${job.openings} openings'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

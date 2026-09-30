part of '../../main.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({
    super.key,
    this.refreshToken = 0,
    this.api,
    this.locationService,
  });
  final int refreshToken;
  final WorkerApiService? api;
  final FeedLocationService? locationService;
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  late final service = widget.api ?? WorkerApiService();
  late final locationService = widget.locationService ?? FeedLocationService();
  FeedPosition? position;
  JobFeedModel? feed;
  bool showAll = false;
  bool loadingMore = false;
  PaginationModel? pagination;
  String query = '';
  String cat = 'All';
  String? filterState, filterCity, filterSkill;
  List<Job> apiJobs = [];
  List<String> categories = ['All'];
  List<String> states = [], skills = [];
  bool loading = true;
  String? error;
  String? referenceError;
  Timer? searchTimer;
  int _loadSequence = 0;
  String? _lastLoggedSearch;

  @override
  void initState() {
    super.initState();
    _loadReference();
    _load(refreshLocation: true);
  }

  @override
  void didUpdateWidget(covariant JobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken)
      _load(refreshLocation: true);
  }

  Map<String, dynamic> get requestFilters => {
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (cat != 'All') 'category': cat,
    if (filterState != null) 'state': filterState,
    if (filterCity != null) 'city': filterCity,
    if (filterSkill != null) 'skill': filterSkill,
    if (showAll) 'all': 1,
    ...?position?.query,
  };

  Future<void> _loadMore() async {
    if (loading ||
        loadingMore ||
        pagination == null ||
        pagination!.currentPage >= pagination!.lastPage)
      return;
    final sequence = _loadSequence;
    setState(() => loadingMore = true);
    try {
      final response = await service.fetchJobs(
        filters: requestFilters,
        page: pagination!.currentPage + 1,
      );
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        final ids = apiJobs.map((job) => job.id).toSet();
        apiJobs.addAll(
          response.jobs.where((job) => ids.add(job.id)).map(Job.fromApi),
        );
        pagination = response.pagination;
      });
    } on ApiException catch (e) {
      if (mounted && sequence == _loadSequence)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted && sequence == _loadSequence)
        setState(() => loadingMore = false);
    }
  }

  Future<void> _loadReference() async {
    if (mounted) setState(() => referenceError = null);
    try {
      final reference = await service.reference();
      if (mounted) {
        setState(() {
          states = reference.states;
          skills = reference.skills;
          categories = ['All', ...reference.jobCategories];
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => referenceError = e.message);
    }
  }

  void _search(String value) {
    query = value;
    searchTimer?.cancel();
    searchTimer = Timer(const Duration(milliseconds: 450), () => _load());
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
        const SnackBar(content: AppText('Job filters applied successfully.')),
      );
    }
  }

  Future<void> _load({bool refreshLocation = false}) async {
    final sequence = ++_loadSequence;
    setState(() {
      loading = true;
      loadingMore = false;
      error = null;
    });
    if (refreshLocation) {
      final current = await locationService.current(requestPermission: true);
      if (!mounted || sequence != _loadSequence) return;
      position = current;
    }
    final filters = requestFilters;
    // This key stays in memory only; free text and locations never go to Meta.
    final searchKey = filters.toString();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await service.fetchJobs(filters: filters);
      if (!mounted || sequence != _loadSequence) return;
      if ([
            'q',
            'category',
            'state',
            'city',
            'skill',
          ].any(filters.containsKey) &&
          _lastLoggedSearch != searchKey) {
        _lastLoggedSearch = searchKey;
        unawaited(
          MetaEventsService.instance.jobsSearched(
            hasQuery: filters.containsKey('q'),
            hasFilters: [
              'category',
              'state',
              'city',
              'skill',
            ].any(filters.containsKey),
            resultCount: response.jobs.length,
          ),
        );
      } else if (filters.isEmpty) {
        _lastLoggedSearch = null;
      }
      setState(() {
        apiJobs = response.jobs.map(Job.fromApi).toList();
        feed = response.feed;
        pagination = response.pagination;
      });
    } on ApiException catch (error) {
      if (mounted && sequence == _loadSequence) {
        setState(() => this.error = error.message);
      }
    } finally {
      if (mounted && sequence == _loadSequence) {
        setState(() => loading = false);
      }
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
        title: const AppText('Browse Jobs'),
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
                    hintText: context.tr('Search job title, skill…'),
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                if (referenceError != null)
                  TextButton(
                    onPressed: _loadReference,
                    child: const AppText('Reload skills and categories'),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((e) {
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
                            padding: const EdgeInsets.symmetric(horizontal: 11),
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
                            child: AppText(
                              e,
                              style: TextStyle(
                                color: active ? const Color(0xFFC93A06) : muted,
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
            child: RefreshIndicator(
              onRefresh: () => _load(refreshLocation: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const AppText('Show all jobs'),
                    value: showAll,
                    onChanged: (value) {
                      setState(() => showAll = value);
                      _load();
                    },
                  ),
                  if (feed != null && !loading)
                    AppText(
                      feed!.categories.isEmpty
                          ? context.tr('Jobs near you')
                          : context.trArgs('Jobs for {categories} near you', {
                              'categories': feed!.categories
                                  .map(context.tr)
                                  .join(', '),
                            }),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (!loading &&
                      (feed?.location == 'city' || feed?.location == 'none'))
                    TextButton.icon(
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: const AppText(
                        'Turn on location to see jobs near you',
                      ),
                      onPressed: () async {
                        if (!await Geolocator.isLocationServiceEnabled()) {
                          await Geolocator.openLocationSettings();
                        } else if (await Geolocator.checkPermission() ==
                            LocationPermission.deniedForever) {
                          await Geolocator.openAppSettings();
                        }
                        if (mounted) await _load(refreshLocation: true);
                      },
                    ),
                  if (feed == null)
                    AppText(
                      context.trArgs('{count} jobs matched to your filters', {
                            'count': '${filtered.length}',
                          }) +
                          (filterCity != null ? ' · $filterCity' : ''),
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
                          AppText(error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _load,
                            child: const AppText('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (filtered.isEmpty)
                    const AppCard(
                      child: Column(
                        children: [
                          Icon(LucideIcons.searchX, color: muted, size: 30),
                          SizedBox(height: 8),
                          AppText(
                            'No matching jobs found',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 3),
                          AppText(
                            'Try changing your search or filters.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filtered.map(JobCard.new),
                  if (!loading &&
                      pagination != null &&
                      pagination!.currentPage < pagination!.lastPage)
                    TextButton(
                      onPressed: loadingMore ? null : _loadMore,
                      child: AppText(
                        loadingMore ? 'Please wait…' : 'Load more',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JobsApiFilterSheet extends StatefulWidget {
  const JobsApiFilterSheet({
    super.key,
    required this.states,
    required this.skills,
    required this.categories,
    this.selectedState,
    this.selectedCity,
    this.selectedCategory,
    this.selectedSkill,
  });
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
    setState(() {
      state = value;
      if (!keepCity) city = null;
      loading = true;
    });
    try {
      final result = await WorkerApiService().cities(value);
      if (mounted && state == value) setState(() => cities = result);
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Filter jobs',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Category'),
          DropdownButtonFormField<String>(
            initialValue: category,
            isExpanded: true,
            hint: const AppText('All categories'),
            items: widget.categories
                .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
                .toList(),
            onChanged: (v) => setState(() => category = v),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Skill'),
          DropdownButtonFormField<String>(
            initialValue: skill,
            isExpanded: true,
            menuMaxHeight: 400,
            hint: const AppText('All skills'),
            items: widget.skills
                .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
                .toList(),
            onChanged: (v) => setState(() => skill = v),
          ),
          const SizedBox(height: 14),
          const FieldLabel('State'),
          DropdownButtonFormField<String>(
            initialValue: state,
            isExpanded: true,
            menuMaxHeight: 400,
            hint: const AppText('All states'),
            items: widget.states
                .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) _loadCities(v);
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('City'),
          DropdownButtonFormField<String>(
            key: ValueKey(state),
            initialValue: city,
            isExpanded: true,
            menuMaxHeight: 400,
            hint: AppText(loading ? 'Loading cities...' : 'All cities'),
            items: cities
                .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
                .toList(),
            onChanged: loading ? null : (v) => setState(() => city = v),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, <String, String?>{}),
                  child: const AppText('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, {
                    'state': state,
                    'city': city,
                    'category': category,
                    'skill': skill,
                  }),
                  child: const AppText('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
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
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Tag(job.category),
                      ),
                    ),
                    if (trailing != null) const SizedBox(width: 8),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 9),
                AppText(
                  job.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 3),
                AppText(
                  job.employer,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (job.employerVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: VerifiedEmployerBadge(),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 7,
                  children: [
                    Meta(LucideIcons.mapPin, job.city),
                    if (job.distanceKm != null)
                      Meta(
                        LucideIcons.navigation,
                        context.trArgs('{distance} km away', {
                          'distance': job.distanceKm!.toStringAsFixed(1),
                        }),
                      ),
                    Meta(LucideIcons.indianRupee, job.wage, bold: true),
                    Meta(
                      LucideIcons.calendarDays,
                      context.trArgs('{count} openings', {
                        'count': '${job.openings}',
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

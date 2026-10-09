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
  bool unavailable = false;
  String? unavailableMessage;
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
        unavailable = response.unavailable;
        unavailableMessage = response.message;
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
          if (!unavailable)
            IconButton(
              onPressed: _openFilter,
              icon: const Icon(LucideIcons.slidersHorizontal),
            ),
        ],
      ),
      body: unavailable && !loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: UnavailableJobsCard(
                  message: unavailableMessage,
                  onEnable: () async {
                    await service.setAvailability(true);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: AppText('You are now available for work.'),
                        ),
                      );
                    await _load(refreshLocation: true);
                  },
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    border: Border(
                      bottom: BorderSide(color: context.borderColor),
                    ),
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
                      FeedLocationBar(
                        location: feed == null
                            ? null
                            : {
                                'mode': feed!.location,
                                'label': feed!.locationLabel,
                              },
                        onChanged: () => _load(refreshLocation: true),
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
                                  child: AppText(
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
                                : context.trArgs(
                                    'Jobs for {categories} near you',
                                    {
                                      'categories': feed!.categories
                                          .map(context.tr)
                                          .join(', '),
                                    },
                                  ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        if (!loading &&
                            (feed?.location == 'city' ||
                                feed?.location == 'none'))
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
                            context.trArgs(
                                  '{count} jobs matched to your filters',
                                  {'count': '${filtered.length}'},
                                ) +
                                (filterCity != null ? ' · $filterCity' : ''),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12.5,
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (loading)
                          const Center(child: CircularProgressIndicator())
                        else if (error != null)
                          AppCard(
                            child: Column(
                              children: [
                                const Icon(
                                  LucideIcons.triangleAlert,
                                  color: brand,
                                ),
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
                                Icon(
                                  LucideIcons.searchX,
                                  color: muted,
                                  size: 30,
                                ),
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

class FeedLocationBar extends StatelessWidget {
  const FeedLocationBar({
    super.key,
    required this.location,
    required this.onChanged,
  });
  final Map<String, dynamic>? location;
  final Future<void> Function() onChanged;
  String get _label {
    final chosen =
        location?['mode']?.toString() == 'chosen' ||
        location?['location']?.toString() == 'chosen';
    final label =
        location?['label']?.toString() ??
        location?['location_label']?.toString();
    return chosen && label?.isNotEmpty == true ? label! : 'Current location';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () async {
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FeedLocationSheet(location: location),
      );
      if (changed == true) await onChanged();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPin, color: brand, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 13),
                children: [
                  const TextSpan(text: 'Jobs near '),
                  TextSpan(
                    text: _label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Change ›',
            style: TextStyle(color: brand, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class FeedLocationSheet extends StatefulWidget {
  const FeedLocationSheet({super.key, this.location});
  final Map<String, dynamic>? location;
  @override
  State<FeedLocationSheet> createState() => _FeedLocationSheetState();
}

class _FeedLocationSheetState extends State<FeedLocationSheet> {
  final service = WorkerApiService();
  final search = TextEditingController();
  Timer? timer;
  List<dynamic> places = [];
  bool loading = false;
  Future<void> _search() async {
    final q = search.text.trim();
    if (q.length < 2) return;
    setState(() => loading = true);
    try {
      final response = await service.searchPlaces(q);
      if (mounted) setState(() => places = jsonList(response['places']));
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pick(Map<String, dynamic> place) async {
    final response = await service.setFeedLocation(
      latitude: (place['latitude'] as num).toDouble(),
      longitude: (place['longitude'] as num).toDouble(),
      label: place['label']?.toString(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            response['message']?.toString() ?? 'Location updated.',
          ),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Show jobs near',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.locateFixed),
            title: const Text('Use my current location'),
            trailing: widget.location?['mode']?.toString() == 'current'
                ? const Icon(LucideIcons.check, color: brand)
                : null,
            onTap: () async {
              final response = await service.clearFeedLocation();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: AppText(
                      response['message']?.toString() ??
                          'Using your current location.',
                    ),
                  ),
                );
                Navigator.pop(context, true);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.map),
            title: const Text('Pick on map'),
            onTap: () async {
              final location = await FeedLocationService().current(
                requestPermission: true,
              );
              if (!context.mounted) return;
              final pin = await showModalBottomSheet<LatLng>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _MapPinPicker(
                  initial: LatLng(
                    location?.latitude ?? 20.5937,
                    location?.longitude ?? 78.9629,
                  ),
                ),
              );
              if (pin != null)
                await _pick({
                  'latitude': pin.latitude,
                  'longitude': pin.longitude,
                });
            },
          ),
          TextField(
            controller: search,
            onChanged: (_) {
              timer?.cancel();
              timer = Timer(const Duration(milliseconds: 600), _search);
            },
            onSubmitted: (_) => _search(),
            decoration: const InputDecoration(
              prefixIcon: Icon(LucideIcons.search),
              hintText: 'Search a town or PIN code',
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (search.text.trim().length >= 2 && places.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No place found. Try a nearby town or the PIN code.'),
            ),
          ...places.map((value) {
            final place = jsonMap(value);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.mapPin),
              title: Text(place['label']?.toString() ?? ''),
              onTap: () => _pick(place),
            );
          }),
        ],
      ),
    ),
  );
}

class _MapPinPicker extends StatefulWidget {
  const _MapPinPicker({required this.initial});
  final LatLng initial;
  @override
  State<_MapPinPicker> createState() => _MapPinPickerState();
}

class _MapPinPickerState extends State<_MapPinPicker> {
  late LatLng pin = widget.initial;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Tap the map to place a pin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pin,
                initialZoom: 11,
                onTap: (_, point) => setState(() => pin = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.superkarigar.worker',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pin,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        LucideIcons.mapPin,
                        color: brand,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, pin),
                child: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
          SearchableOptionField(
            title: 'Category',
            options: widget.categories,
            value: category,
            hint: 'All categories',
            onChanged: (value) => setState(() => category = value),
          ),
          const SizedBox(height: 14),
          const FieldLabel('Skill'),
          SearchableOptionField(
            title: 'Skill',
            options: widget.skills,
            value: skill,
            hint: 'All skills',
            onChanged: (value) => setState(() => skill = value),
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

part of '../../main.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({
    super.key,
    this.refreshToken = 0,
    this.api,
    this.locationService,
    this.onAvailabilityChanged,
  });
  final int refreshToken;
  final WorkerApiService? api;
  final FeedLocationService? locationService;

  /// Tells the shell, so Home reloads the next time it is shown.
  final VoidCallback? onAvailabilityChanged;
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  late final service = widget.api ?? WorkerApiService();
  late final locationService = widget.locationService ?? FeedLocationService();
  FeedPosition? position;
  JobFeedModel? feed;
  Map<String, dynamic>? feedPlace;
  bool showAll = false;
  bool loadingMore = false;
  PaginationModel? pagination;
  String query = '';
  String cat = 'All';
  String? filterState, filterCity, filterSkill;

  /// Only jobs this close, in km (server `radius`); null for any distance.
  int? radiusKm;
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
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load(refreshLocation: true);
    }
  }

  Map<String, dynamic> get requestFilters => {
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (cat != 'All') 'category': cat,
    if (filterState != null) 'state': filterState,
    if (filterCity != null) 'city': filterCity,
    if (filterSkill != null) 'skill': filterSkill,
    if (showAll) 'all': 1,
    // Only "near me": a picked state or city searches that place instead.
    if (radiusKm != null && filterState == null && filterCity == null)
      'radius': radiusKm,
    ...?position?.query,
  };

  Future<void> _loadMore() async {
    if (loading ||
        loadingMore ||
        pagination == null ||
        pagination!.currentPage >= pagination!.lastPage) {
      return;
    }
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
      if (mounted && sequence == _loadSequence) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted && sequence == _loadSequence) {
        setState(() => loadingMore = false);
      }
    }
  }

  void _removeAppliedJob(int jobId) {
    if (!mounted) return;
    setState(() => apiJobs.removeWhere((job) => job.id == jobId));
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
        selectedRadius: radiusKm,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      filterState = result['state'];
      filterCity = result['city'];
      filterSkill = result['skill'];
      cat = result['category'] ?? 'All';
      radiusKm = int.tryParse(result['radius'] ?? '');
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
    Future<FeedPosition?>? positionFuture;
    setState(() {
      loading = true;
      loadingMore = false;
      error = null;
      // Do not use a previous position while a fresh one is being acquired.
      if (refreshLocation) position = null;
    });
    if (refreshLocation) {
      // A cold GPS can take seconds. Keep it outside the initial jobs request
      // so the tab is useful immediately with the server's normal fallback.
      positionFuture = locationService.current(requestPermission: true);
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
        if (response.feed != null) {
          feedPlace = {
            'mode': response.feed!.location,
            'label': response.feed!.locationLabel,
          };
        }
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
    if (positionFuture != null) {
      unawaited(_refreshForCurrentLocation(positionFuture, sequence));
    }
  }

  Future<void> _refreshForCurrentLocation(
    Future<FeedPosition?> positionFuture,
    int sequence,
  ) async {
    final current = await positionFuture;
    if (!mounted || sequence != _loadSequence || current == null) return;
    position = current;
    final filters = requestFilters;
    try {
      final response = await service.fetchJobs(filters: filters);
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        apiJobs = response.jobs.map(Job.fromApi).toList();
        feed = response.feed;
        if (response.feed != null) {
          feedPlace = {
            'mode': response.feed!.location,
            'label': response.feed!.locationLabel,
          };
        }
        pagination = response.pagination;
        unavailable = response.unavailable;
        unavailableMessage = response.message;
      });
    } on ApiException {
      // Keep the initial city/profile results visible if this optional
      // location-based refresh is unavailable.
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
              // A dot while a filter from the sheet is on, so a short list
              // doesn't look like there are no jobs.
              icon: Badge(
                isLabelVisible:
                    radiusKm != null ||
                    filterState != null ||
                    filterCity != null ||
                    filterSkill != null,
                smallSize: 8,
                child: const Icon(LucideIcons.slidersHorizontal),
              ),
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
                    try {
                      await service.setAvailability(true);
                      widget.onAvailabilityChanged?.call();
                    } on ApiException catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: AppText(error.message)),
                        );
                      }
                      return;
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: AppText('You are now available for work.'),
                        ),
                      );
                    }
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
                        // A search reply has no feed; keep saying what the
                        // last feed was near, not "Current location".
                        location: feedPlace,
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
                        // Not while the list failed to load: offline it said
                        // "0 jobs matched" above the error.
                        if (feed == null && error == null)
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
                          ...filtered.map(
                            (job) => JobCard(
                              job,
                              onApplied: () => _removeAppliedJob(job.id),
                            ),
                          ),
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
    if (chosen && label?.isNotEmpty == true) return label!;
    // Said "Current location" even with location off, while the server
    // measured from the profile pin or the city.
    return switch ((location?['mode'] ?? location?['location'])?.toString()) {
      'profile' => 'Your profile location',
      'city' => 'Your city',
      _ => 'Current location',
    };
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
                  TextSpan(text: '${context.tr('Jobs near')} '),
                  TextSpan(
                    text: context.tr(_label),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const AppText(
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
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
              final Map<String, dynamic> response;
              try {
                response = await service.clearFeedLocation();
              } on ApiException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: AppText(error.message)));
                }
                return;
              }
              if (context.mounted) {
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
              if (pin != null) {
                await _pick({
                  'latitude': pin.latitude,
                  'longitude': pin.longitude,
                });
              }
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
    this.selectedRadius,
  });
  final List<String> states, skills, categories;
  final String? selectedState, selectedCity, selectedCategory, selectedSkill;
  final int? selectedRadius;
  @override
  State<JobsApiFilterSheet> createState() => _JobsApiFilterSheetState();
}

class _JobsApiFilterSheetState extends State<JobsApiFilterSheet> {
  String? state, city, category, skill;
  int? radius;
  List<String> cities = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    state = widget.selectedState;
    city = widget.selectedCity;
    category = widget.selectedCategory;
    skill = widget.selectedSkill;
    radius = widget.selectedRadius;
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
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
          // Measured from the place the feed uses (current location or the
          // one picked under "Jobs near").
          const FieldLabel('Distance'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                const <(int?, String)>[
                      (null, 'Any distance'),
                      (5, '5 km'),
                      (10, '10 km'),
                      (25, '25 km'),
                      (50, '50 km'),
                      (100, '100 km'),
                    ]
                    .map(
                      (item) => ChoiceChip(
                        label: AppText(item.$2),
                        selected: radius == item.$1,
                        // A distance is measured from where the karigar is,
                        // so it can't go with another city: picking one
                        // clears the other.
                        onSelected: (_) => setState(() {
                          radius = item.$1;
                          if (radius != null) {
                            state = null;
                            city = null;
                            cities = [];
                          }
                        }),
                      ),
                    )
                    .toList(),
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
          // Searchable like Category and Skill: a state has up to a thousand
          // towns, too many to scroll through in a plain dropdown.
          SearchableOptionField(
            key: ValueKey('state-$state'),
            title: 'State',
            options: widget.states,
            value: state,
            hint: 'All states',
            onChanged: (v) {
              if (v == null) return;
              // Another state means searching outside "near me".
              setState(() => radius = null);
              _loadCities(v);
            },
          ),
          const SizedBox(height: 14),
          const FieldLabel('City'),
          SearchableOptionField(
            key: ValueKey('city-$state-${cities.length}'),
            title: 'City',
            options: cities,
            value: city,
            hint: loading ? 'Loading cities...' : 'All cities',
            onChanged: (v) => setState(() => city = v),
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
                    'radius': radius?.toString(),
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
  const JobCard(
    this.job, {
    super.key,
    this.trailing,
    this.onTap,
    this.onApplied,
  });
  final Job job;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onApplied;

  Future<void> _openDetail(BuildContext context) async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => JobDetailPage(job, onApplied: onApplied),
      ),
    );
    if (applied == true) onApplied?.call();
  }

  // A stripe down the left (red for urgent jobs), the pay as a bold pill
  // with an arrow button beside it, and the distance highlighted: what a
  // karigar scans a list for first.
  @override
  Widget build(BuildContext context) {
    final incentive = JobRequirements.incentiveLabel(
      job,
      language: selectedLanguageCode.value,
    );
    final stripe = job.isUrgent ? const Color(0xFFB3261E) : brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border.all(color: context.borderColor),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D101828),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap ?? () => _openDetail(context),
                // A Stack, not IntrinsicHeight, so any trailing widget is safe.
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 13, 13, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Tag(
                                      job.category.trim().isEmpty
                                          ? 'Other'
                                          : job.category,
                                    ),
                                    if (job.isUrgent) const _UrgentTag(),
                                  ],
                                ),
                              ),
                              if (trailing != null) const SizedBox(width: 8),
                              ?trailing,
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppText(
                            job.title,
                            style: const TextStyle(
                              fontSize: 16.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: AppText(
                                  job.employer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.mutedText,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              if (job.employerVerified) ...[
                                const SizedBox(width: 6),
                                const VerifiedEmployerBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 7,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (job.distanceKm != null)
                                _JobPill(
                                  icon: LucideIcons.navigation,
                                  label: context.trArgs('{distance} km away', {
                                    'distance': formatKm(job.distanceKm!),
                                  }),
                                  strong: true,
                                ),
                              _JobPill(
                                icon: LucideIcons.mapPin,
                                label: job.city,
                              ),
                              if (job.workMode == 'remote' ||
                                  job.workMode == 'both')
                                _JobPill(
                                  icon: LucideIcons.house,
                                  label: job.workModeLabel,
                                ),
                              _JobPill(
                                icon: LucideIcons.usersRound,
                                label: context.trArgs(
                                  job.openings == 1
                                      ? '{count} opening'
                                      : '{count} openings',
                                  {'count': '${job.openings}'},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.greenTint,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.indianRupee,
                                          size: 14,
                                          color: context.isDark
                                              ? const Color(0xFFA9C7A2)
                                              : const Color(0xFF3F5C3A),
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: AppText(
                                            job.wage,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: context.isDark
                                                  ? const Color(0xFFA9C7A2)
                                                  : const Color(0xFF3F5C3A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: brand,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.arrowRight,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          if (incentive.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AppText(
                                incentive,
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: 5,
                      child: ColoredBox(color: stripe),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One detail on a job card. [strong] (the distance) gets the brand tint.
class _JobPill extends StatelessWidget {
  const _JobPill({
    required this.icon,
    required this.label,
    this.strong = false,
  });
  final IconData icon;
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? context.brandText : context.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? context.brandTint : Colors.transparent,
        border: Border.all(
          color: strong ? context.brandTintBorder : context.borderColor,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: AppText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentTag extends StatelessWidget {
  const _UrgentTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const AppText(
      'Urgent hiring',
      style: TextStyle(
        color: Color(0xFFB91C1C),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

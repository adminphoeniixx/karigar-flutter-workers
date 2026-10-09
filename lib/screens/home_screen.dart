part of '../main.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.refreshToken = 0,
    this.api,
    this.locationService,
    required this.onBrowse,
    required this.onAlerts,
    required this.onProfile,
    required this.onUnreadChanged,
  });
  final int refreshToken;
  final WorkerApiService? api;
  final FeedLocationService? locationService;
  final VoidCallback onBrowse, onAlerts, onProfile;
  final ValueChanged<int> onUnreadChanged;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _loadSequence = 0;
  bool available = true;
  bool loading = true;
  String? loadError;
  bool accessDenied = false;
  Map<String, dynamic> dashboard = {};
  List<Job> latestJobs = [];
  String? currentLocationAddress;
  Map<String, dynamic>? feedLocation;

  Map<String, dynamic> get stats =>
      Map<String, dynamic>.from(dashboard['stats'] as Map? ?? {});
  Map<String, dynamic> get profile =>
      Map<String, dynamic>.from(dashboard['profile'] as Map? ?? {});
  String get workerName =>
      dashboard['greeting']?.toString() ??
      profile['name']?.toString() ??
      'Worker';
  int get completion => (stats['profile_completion'] as num?)?.toInt() ?? 0;
  int get unreadNotifications =>
      (stats['unread_notifications'] as num?)?.toInt() ?? 0;
  bool get hasChosenFeedLocation =>
      feedLocation?['mode']?.toString() == 'chosen';
  String? get homeLocationLabel {
    final chosen = feedLocation?['label']?.toString().trim();
    if (hasChosenFeedLocation && chosen?.isNotEmpty == true) return chosen;
    return currentLocationAddress;
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    final sequence = ++_loadSequence;
    if (mounted) {
      setState(() {
        loading = true;
        loadError = null;
        accessDenied = false;
        currentLocationAddress = null;
      });
    }
    try {
      final service = widget.api ?? WorkerApiService();
      final position = await (widget.locationService ?? FeedLocationService())
          .current(requestPermission: true);
      if (!mounted || sequence != _loadSequence) return;
      final response = await service.fetchDashboard(location: position?.query);
      final homeJobs = response.latestJobs;
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        dashboard = {
          'greeting': response.greeting,
          'profile': response.profile.data,
          'stats': {
            'available_jobs': response.stats.availableJobs,
            'applications': response.stats.applications,
            'saved_jobs': response.stats.savedJobs,
            'kyc_status_label': response.stats.kycStatusLabel,
            'profile_completion': response.stats.profileCompletion,
            'unread_notifications': response.stats.unreadNotifications,
          },
        };
        available = response.profile.available;
        profileAvatarUrl.value = response.profile.data['avatar_url']
            ?.toString();
        latestJobs = homeJobs.map(Job.fromApi).toList();
        feedLocation = response.feedLocation;
      });
      // A selected feed location is the location the jobs are actually using.
      // Never overwrite it with the phone's reverse-geocoded address.
      if (position != null && !hasChosenFeedLocation) {
        unawaited(_resolveCurrentLocation(position, sequence));
      }
      widget.onUnreadChanged(response.stats.unreadNotifications);
    } on ApiException catch (error) {
      if (mounted && sequence == _loadSequence) {
        setState(() {
          accessDenied = error.statusCode == 401 || error.statusCode == 403;
          loadError = error.statusCode == 401
              ? 'Your session has expired. Please sign in again.'
              : error.statusCode == 403
              ? 'This account cannot access the worker dashboard. Sign in with a worker account. If this is a worker account, contact support.'
              : error.message;
        });
      }
    } finally {
      if (mounted && sequence == _loadSequence) setState(() => loading = false);
    }
  }

  Future<void> _resolveCurrentLocation(
    FeedPosition position,
    int sequence,
  ) async {
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted || sequence != _loadSequence || places.isEmpty) return;
      final place = places.first;
      final address =
          [
                place.name,
                place.street,
                place.subLocality,
                place.locality,
                place.subAdministrativeArea,
                place.administrativeArea,
                place.postalCode,
              ]
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .join(', ');
      if (address.isNotEmpty && mounted && sequence == _loadSequence) {
        setState(() => currentLocationAddress = address);
      }
    } catch (_) {
      // The nearby-jobs feed still works when reverse geocoding is unavailable.
    }
  }

  Future<void> _signInAgain() async {
    await ApiClient.instance.setToken(null);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _setAvailability(bool value) async {
    final previous = available;
    setState(() => available = value);
    try {
      final saved = await WorkerApiService().setAvailability(value);
      if (mounted) {
        setState(() => available = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              saved
                  ? 'You are now available for work.'
                  : 'Availability turned off.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => available = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: loading || loadError != null
        ? AppBar(actions: const [AppLanguageButton(), SizedBox(width: 12)])
        : AppBar(
            toolbarHeight: 88,
            leadingWidth: 58,
            leading: Padding(
              padding: EdgeInsets.only(left: 16, top: 10, bottom: 10),
              child: Tooltip(
                message: context.tr('Profile'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: widget.onProfile,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: profileAvatarUrl,
                    builder: (context, avatarUrl, _) => CircleAvatar(
                      backgroundColor: const Color(0xFFFFE3D8),
                      backgroundImage: avatarUrl?.isNotEmpty == true
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl?.isNotEmpty == true
                          ? null
                          : AppText(
                              workerName
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .take(2)
                                  .map((e) => e.isEmpty ? '' : e[0])
                                  .join()
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFC93A06),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            titleSpacing: 8,
            title: Tooltip(
              message: context.tr('Profile'),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      context.tr('Welcome back 👋'),
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    AppText(
                      workerName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (homeLocationLabel?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 12,
                              color: muted,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                homeLocationLabel!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: const AppLanguageButton(),
              ),
            ],
          ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    accessDenied
                        ? LucideIcons.lockKeyhole
                        : LucideIcons.wifiOff,
                    color: muted,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  AppText(loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: accessDenied ? _signInAgain : _loadDashboard,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: AppText(
                      accessDenied ? 'Sign in again' : 'Try again',
                    ),
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadDashboard,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              context.tr('Available for work'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!available)
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Text(
                                  'No job alerts or jobs while off',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                            AppText(
                              available
                                  ? context.tr('Employers can discover you')
                                  : context.tr("You're hidden from employers"),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: available,
                        activeTrackColor: brand,
                        onChanged: _setAvailability,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        stats['available_jobs']?.toString() ?? '0',
                        context.tr('Available Jobs'),
                        LucideIcons.briefcaseBusiness,
                        Color(0xFFFFF3EE),
                        brand,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        stats['kyc_status_label']?.toString() ??
                            'Not submitted',
                        context.tr('KYC Status'),
                        LucideIcons.shieldCheck,
                        Color(0xFFFFF7ED),
                        Color(0xFFB45309),
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        stats['applications']?.toString() ?? '0',
                        context.tr('Applications'),
                        LucideIcons.check,
                        Color(0xFFECFDF5),
                        Color(0xFF047857),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        '$completion%',
                        context.tr('Profile complete'),
                        LucideIcons.clock,
                        Color(0xFFEEF2FF),
                        Color(0xFF4F46E5),
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: context.brandTint,
                    border: Border.all(
                      color: context.isDark
                          ? const Color(0xFF68402F)
                          : const Color(0xFFFFC5B0),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  '${context.tr('Profile complete')}: $completion%',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 2),
                                AppText(
                                  context.tr(
                                    'Add skills & KYC to get more jobs',
                                  ),
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: widget.onProfile,
                            child: AppText(
                              context.tr('Complete'),
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: completion / 100,
                          minHeight: 7,
                          backgroundColor: context.surfaceColor,
                          color: brand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 17),
                SectionHeader(
                  context.tr('LATEST JOBS NEAR YOU'),
                  action: context.tr('See all →'),
                  onTap: widget.onBrowse,
                ),
                const SizedBox(height: 4),
                FeedLocationBar(
                  location: feedLocation,
                  onChanged: _loadDashboard,
                ),
                const SizedBox(height: 8),
                if (!available)
                  UnavailableJobsCard(
                    onEnable: () =>
                        _setAvailability(true).then((_) => _loadDashboard()),
                  )
                else if (latestJobs.isEmpty)
                  AppCard(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.briefcaseBusiness,
                          color: muted,
                          size: 28,
                        ),
                        SizedBox(height: 8),
                        AppText(
                          context.tr('No jobs available near you yet'),
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        AppText(
                          context.tr('New matching jobs will appear here.'),
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  ...latestJobs.map(JobCard.new),
              ],
            ),
          ),
  );
}

class UnavailableJobsCard extends StatelessWidget {
  const UnavailableJobsCard({super.key, required this.onEnable, this.message});
  final VoidCallback onEnable;
  final String? message;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        const Icon(LucideIcons.circleOff, color: muted, size: 30),
        const SizedBox(height: 8),
        const Text(
          "You're not available for work",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          message ??
              'While "Available for work" is off you get no job alerts and see no jobs. Switch it on whenever you’re ready.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onEnable,
          child: const Text("I'm available for work"),
        ),
      ],
    ),
  );
}

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
    this.onAvailabilityChanged,
  });
  final int refreshToken;

  /// Tells the shell, so the Jobs tab reloads the next time it is shown.
  final VoidCallback? onAvailabilityChanged;
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
      // Location acquisition can take several seconds on a cold GPS.  Do not
      // keep the entire home screen waiting for it: show the server's normal
      // (chosen/profile-city) feed first, then refresh nearby jobs once a
      // fresh position is available.
      final locationService = widget.locationService ?? FeedLocationService();
      // The last known position is instant, so the first answer is usually
      // already the nearby one and Home asks the server only once.
      final known = await locationService.lastKnown();
      final position = locationService.current(requestPermission: true);
      final response = await service.fetchDashboard(location: known?.query);
      if (!mounted || sequence != _loadSequence) return;
      _applyDashboard(response);
      unawaited(
        _refreshForCurrentLocation(service, position, sequence, known: known),
      );
    } on ApiException catch (error) {
      final denied = error.statusCode == 401 || error.statusCode == 403;
      // Already showing a dashboard: keep it and say the refresh failed.
      // Offline, Home used to go blank with only "Try again".
      if (mounted &&
          sequence == _loadSequence &&
          !denied &&
          dashboard.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: AppText(error.message)));
      } else if (mounted && sequence == _loadSequence) {
        setState(() {
          accessDenied = denied;
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

  void _applyDashboard(DashboardModel response) {
    setState(() {
      dashboard = {
        'greeting': response.greeting,
        'profile': response.profile.data,
        'stats': {
          'available_jobs': response.stats.availableJobs,
          'applications': response.stats.applications,
          'saved_jobs': response.stats.savedJobs,
          'kyc_status_label': response.stats.kycStatusLabel,
          'kyc_status': response.stats.kycStatus,
          'profile_completion': response.stats.profileCompletion,
          'unread_notifications': response.stats.unreadNotifications,
        },
        'features': {'verification_enabled': response.verificationEnabled},
      };
      available = response.profile.available;
      profileAvatarUrl.value = response.profile.data['avatar_url']?.toString();
      latestJobs = response.latestJobs.map(Job.fromApi).toList();
      feedLocation = response.feedLocation;
    });
    widget.onUnreadChanged(response.stats.unreadNotifications);
  }

  void _removeAppliedJob(int jobId) {
    if (!mounted) return;
    setState(() => latestJobs.removeWhere((job) => job.id == jobId));
  }

  Future<void> _refreshForCurrentLocation(
    WorkerApiService service,
    Future<FeedPosition?> positionFuture,
    int sequence, {
    FeedPosition? known,
  }) async {
    final position = await positionFuture;
    if (!mounted || sequence != _loadSequence || position == null) return;
    // Within a kilometre of the position already used: same jobs, so only
    // the address line needs the fresh position.
    if (known != null &&
        FeedLocationService.distanceBetween(known, position) < 1000) {
      if (!hasChosenFeedLocation) {
        unawaited(_resolveCurrentLocation(position, sequence));
      }
      return;
    }
    try {
      final response = await service.fetchDashboard(location: position.query);
      if (!mounted || sequence != _loadSequence) return;
      _applyDashboard(response);
      // A selected feed location is the location the jobs are actually using.
      // Never overwrite it with the phone's reverse-geocoded address.
      if (!hasChosenFeedLocation) {
        unawaited(_resolveCurrentLocation(position, sequence));
      }
    } on ApiException {
      // The first dashboard response remains visible if the location refresh
      // fails, so a transient GPS/network failure cannot block Home.
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

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadDashboard();
  }

  Future<void> _setAvailability(bool value) async {
    final previous = available;
    setState(() => available = value);
    try {
      final saved = await WorkerApiService().setAvailability(value);
      widget.onAvailabilityChanged?.call();
      if (mounted) {
        setState(() => available = saved);
        // The latest jobs and the count change with it: off shows none.
        unawaited(_loadDashboard());
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

  _HomeStat _kycStat() {
    final status = stats['kyc_status']?.toString() ?? 'not_submitted';
    final (value, color) = switch (status) {
      'verified' => ('Verified', const Color(0xFF047857)),
      'pending' => ('Under review', const Color(0xFFB45309)),
      'rejected' => ('Rejected', const Color(0xFFB91C1C)),
      // The KYC *status*, not the action: "Verify now" read as verified.
      _ => ('Not submitted', brand),
    };
    return _HomeStat(
      icon: status == 'verified' ? LucideIcons.shieldCheck : LucideIcons.shield,
      color: color,
      value: context.tr(value),
      label: context.tr('KYC'),
      onTap: () => _openPage(const KycPage()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: (loading && dashboard.isEmpty) || loadError != null
        ? AppBar(actions: const [AppLanguageButton(), SizedBox(width: 12)])
        : AppBar(
            // Refreshing over the data already shown: a thin line, not a
            // blank screen.
            bottom: loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2, color: brand),
                  )
                : null,
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
              // Chats with employers used to be reachable only from Profile.
              IconButton(
                tooltip: context.tr('Messages'),
                onPressed: () => _openPage(const ConversationsPage()),
                icon: const Icon(LucideIcons.messageSquare),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: const AppLanguageButton(),
              ),
            ],
          ),
    body: loading && dashboard.isEmpty
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
                // Top card: what is waiting for the karigar, a way straight
                // into search, and the availability switch, in one place.
                _HomeHero(
                  jobCount: stats['available_jobs']?.toString() ?? '0',
                  available: available,
                  onSearch: widget.onBrowse,
                  onAvailability: _setAvailability,
                ),
                const SizedBox(height: 10),
                // Find jobs and Applied already have their own tabs (and
                // Applied is in the strip below), so only the two pages
                // without a tab get a shortcut here.
                Row(
                  children: [
                    _QuickAction(
                      LucideIcons.bookmark,
                      context.tr('Saved Jobs'),
                      () => _openPage(const SavedPage()),
                    ),
                    const SizedBox(width: 8),
                    _QuickAction(
                      LucideIcons.fileText,
                      context.tr('My Resume'),
                      () => _openPage(const ResumePage()),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _HomeStatStrip(
                  stats: [
                    _HomeStat(
                      icon: LucideIcons.send,
                      color: const Color(0xFF3F5C3A),
                      value: stats['applications']?.toString() ?? '0',
                      label: context.tr('Applied'),
                      onTap: () => _openPage(const ApplicationsTab()),
                    ),
                    if (dashboard['features'] is Map &&
                        (dashboard['features']
                                as Map)['verification_enabled'] ==
                            true)
                      _kycStat(),
                    _HomeStat(
                      icon: LucideIcons.userRoundCheck,
                      color: brand,
                      value: '$completion%',
                      label: context.tr('Profile'),
                      onTap: widget.onProfile,
                    ),
                  ],
                ),
                // Nothing left to add once the profile is full and KYC is done;
                // it used to keep asking for "skills & KYC" at 100%.
                if (completion < 100 ||
                    (dashboard['features']?['verification_enabled'] == true &&
                        stats['kyc_status'] != 'verified')) ...[
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  AppText(
                                    context.tr(
                                      'Add skills & KYC to get more jobs',
                                    ),
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
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
                ],
                // The location row already says "Jobs near …", so it is the
                // heading; "See all" sits under the list. Saves a row so jobs
                // start in the top half of the screen.
                const SizedBox(height: 6),
                FeedLocationBar(
                  location: feedLocation,
                  onChanged: _loadDashboard,
                ),
                const SizedBox(height: 8),
                if (!available)
                  UnavailableJobsCard(onEnable: () => _setAvailability(true)),
                // While unavailable the server sends no jobs; the card above
                // says so, and old cards must not linger under it.
                if (!available)
                  const SizedBox.shrink()
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
                  ...latestJobs.map(
                    (job) => JobCard(
                      job,
                      onApplied: () => _removeAppliedJob(job.id),
                    ),
                  ),
                if (available && latestJobs.isNotEmpty)
                  Center(
                    child: TextButton(
                      onPressed: widget.onBrowse,
                      child: AppText(context.tr('See all →')),
                    ),
                  ),
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
        const AppText(
          "You're not available for work",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        AppText(
          message ??
              'While "Available for work" is off you get no job alerts and see no jobs. Switch it on whenever you’re ready.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onEnable,
          child: const AppText("I'm available for work"),
        ),
      ],
    ),
  );
}

/// The top of Home: jobs waiting, search, and "Available for work".
class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.jobCount,
    required this.available,
    required this.onSearch,
    required this.onAvailability,
  });
  final String jobCount;
  final bool available;
  final VoidCallback onSearch;
  final ValueChanged<bool> onAvailability;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brand, Color.lerp(brand, Colors.black, .28)!],
      ),
      boxShadow: [
        BoxShadow(
          color: brand.withValues(alpha: .25),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    // Kept to two short rows so the job list starts in the top half of the
    // screen when the app opens.
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: AppText(
                  available
                      ? context.trArgs('{count} jobs match your skills', {
                          'count': jobCount,
                        })
                      : context.tr("You're hidden from employers"),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: available
                    ? const Color(0xFF4ADE80)
                    : Colors.white.withValues(alpha: .5),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            AppText(
              context.tr('Available'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Semantics(
              label: context.tr('Available for work'),
              child: Transform.scale(
                scale: .8,
                child: Switch(
                  value: available,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeThumbColor: brand,
                  activeTrackColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: .25),
                  onChanged: onAvailability,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.search, color: brand, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        context.tr('Search job title, skill…'),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(
                      LucideIcons.arrowRight,
                      color: Color(0xFF9CA3AF),
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// One round shortcut under the top card.
class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// A slim pill (icon, label, arrow) so the job list starts higher.
  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.brandTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: context.brandText, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: AppText(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: context.mutedText,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeStat {
  const _HomeStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String value, label;
  final VoidCallback? onTap;
}

/// One card with equal columns (applied / KYC / profile). The three separate
/// tiles were cramped and came out at different heights.
class _HomeStatStrip extends StatelessWidget {
  const _HomeStatStrip({required this.stats});
  final List<_HomeStat> stats;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        cells.add(
          VerticalDivider(width: 1, thickness: 1, color: context.borderColor),
        );
      }
      cells.add(Expanded(child: _cell(context, stats[i])));
    }
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border.all(color: context.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ),
    );
  }

  // Dark green/indigo were hard to read on the dark surface.
  Color _tone(BuildContext context, Color color) =>
      context.isDark ? Color.lerp(color, Colors.white, .45)! : color;

  Widget _cell(BuildContext context, _HomeStat stat) => Semantics(
    button: stat.onTap != null,
    label: '${stat.label}: ${stat.value}',
    child: InkWell(
      onTap: stat.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(stat.icon, color: _tone(context, stat.color), size: 15),
                  const SizedBox(width: 5),
                  Text(
                    stat.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: _tone(context, stat.color),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                stat.label,
                maxLines: 1,
                style: const TextStyle(
                  color: muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

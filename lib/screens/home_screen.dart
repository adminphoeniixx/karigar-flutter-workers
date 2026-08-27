part of '../main.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.onBrowse,
    required this.onAlerts,
    required this.onProfile,
    required this.onUnreadChanged,
  });
  final VoidCallback onBrowse, onAlerts, onProfile;
  final ValueChanged<int> onUnreadChanged;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool available = true;
  bool loading = true;
  Map<String, dynamic> dashboard = {};
  List<Job> latestJobs = [];

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

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final service = WorkerApiService();
      final response = await service.fetchDashboard();
      var homeJobs = response.latestJobs;
      if (homeJobs.isEmpty) {
        final jobsPage = await service.fetchJobs(page: 1);
        homeJobs = jobsPage.jobs.take(3).toList();
      }
      if (!mounted) return;
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
      });
      widget.onUnreadChanged(response.stats.unreadNotifications);
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
            content: Text(
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
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 59,
      leadingWidth: 58,
      leading: Padding(
        padding: EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: ValueListenableBuilder<String?>(
          valueListenable: profileAvatarUrl,
          builder: (context, avatarUrl, _) => CircleAvatar(
            backgroundColor: const Color(0xFFFFE3D8),
            backgroundImage: avatarUrl?.isNotEmpty == true
                ? NetworkImage(avatarUrl!)
                : null,
            child: avatarUrl?.isNotEmpty == true
                ? null
                : Text(
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
      titleSpacing: 8,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back 👋',
            style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            workerName,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Stack(
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: context.surfaceColor,
                  side: BorderSide(color: context.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.onAlerts,
                icon: const Icon(LucideIcons.bell, size: 21),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available for work',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      available
                          ? 'Employers can discover you'
                          : "You're hidden from employers",
                      style: const TextStyle(color: muted, fontSize: 12),
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
                'Available Jobs',
                LucideIcons.briefcaseBusiness,
                Color(0xFFFFF3EE),
                brand,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                stats['kyc_status_label']?.toString() ?? 'Not submitted',
                'KYC Status',
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
                'Applications',
                LucideIcons.check,
                Color(0xFFECFDF5),
                Color(0xFF047857),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                '$completion%',
                'Profile complete',
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
                        Text(
                          'Profile $completion% complete',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Add skills & KYC to get more jobs',
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
                    child: const Text(
                      'Complete',
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
          'LATEST JOBS NEAR YOU',
          action: 'See all →',
          onTap: widget.onBrowse,
        ),
        const SizedBox(height: 4),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (latestJobs.isEmpty)
          AppCard(
            child: Column(
              children: [
                Icon(LucideIcons.briefcaseBusiness, color: muted, size: 28),
                SizedBox(height: 8),
                Text(
                  'No jobs available near you yet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'New matching jobs will appear here.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...latestJobs.map(JobCard.new),
      ],
    ),
  );
}

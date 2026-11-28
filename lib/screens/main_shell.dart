part of '../main.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  int feedRefresh = 0;
  int unreadAlerts = 0;
  late final List<Widget?> _pages;
  StreamSubscription<WorkerPushDestination>? _pushOpenSubscription;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(5, null);
    _pages[0] = _buildPage(0);
    _builtAt[0] = DateTime.now();
    _pushOpenSubscription = PushNotificationService.instance.openedDestinations
        .listen(_openPushDestination);
    final initialDestination = PushNotificationService.instance
        .takeInitialDestination();
    if (initialDestination != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPushDestination(initialDestination),
      );
    }
  }

  @override
  void dispose() {
    _pushOpenSubscription?.cancel();
    super.dispose();
  }

  void _openPushDestination(WorkerPushDestination destination) {
    if (!mounted) return;
    openWorkerDestination(
      context,
      destination,
      onApplications: () => _selectTab(2),
    );
  }

  void _setUnread(int value) {
    if (mounted && unreadAlerts != value) {
      setState(() => unreadAlerts = value);
    }
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => HomeTab(
        refreshToken: feedRefresh,
        onBrowse: () => _selectTab(1),
        onAlerts: () => _selectTab(3),
        onProfile: () => _selectTab(4),
        onUnreadChanged: _setUnread,
        onAvailabilityChanged: _availabilityChanged,
      ),
      1 => JobsTab(
        refreshToken: feedRefresh,
        onAvailabilityChanged: _availabilityChanged,
      ),
      2 => const ApplicationsTab(),
      3 => NotificationsTab(
        onUnreadChanged: _setUnread,
        onApplicationsRequested: () => _selectTab(2),
      ),
      4 => const ProfileTab(),
      _ => const SizedBox.shrink(),
    };
  }

  /// Home and Jobs reload when shown again only if their data is older than
  /// this; every tab switch used to ask the server again.
  static const feedRefreshAfter = Duration(minutes: 1);
  final _builtAt = <int, DateTime>{};

  /// Availability was switched on one tab: the other feed tab reloads the
  /// next time it is shown, not after the usual minute.
  void _availabilityChanged() {
    _builtAt.remove(0);
    _builtAt.remove(1);
  }

  void _selectTab(int value) {
    if (value == tab) return;
    if (value == 0 || value == 1) {
      final builtAt = _builtAt[value];
      if (_pages[value] == null ||
          builtAt == null ||
          DateTime.now().difference(builtAt) > feedRefreshAfter) {
        feedRefresh++;
        _pages[value] = _buildPage(value);
        _builtAt[value] = DateTime.now();
      }
    } else {
      _pages[value] ??= _buildPage(value);
    }
    setState(() => tab = value);
  }

  @override
  Widget build(BuildContext context) {
    // Back from another tab goes to Home first; only Home's back leaves.
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selectTab(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab,
          children: List<Widget>.generate(
            _pages.length,
            (index) => _pages[index] ?? const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: Row(
                children: [
                  _NavItem(
                    LucideIcons.home,
                    context.tr('Home'),
                    0,
                    tab,
                    _selectTab,
                  ),
                  _NavItem(
                    LucideIcons.briefcaseBusiness,
                    context.tr('Jobs'),
                    1,
                    tab,
                    _selectTab,
                  ),
                  _NavItem(
                    LucideIcons.fileCheck,
                    context.tr('Applied'),
                    2,
                    tab,
                    _selectTab,
                  ),
                  _NavItem(
                    LucideIcons.bell,
                    context.tr('Alerts'),
                    3,
                    tab,
                    _selectTab,
                    badge: unreadAlerts > 0 ? unreadAlerts.toString() : null,
                  ),
                  _NavItem(
                    LucideIcons.userRound,
                    context.tr('Profile'),
                    4,
                    tab,
                    _selectTab,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
    this.icon,
    this.label,
    this.index,
    this.current,
    this.onTap, {
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final int index, current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.only(top: 7, bottom: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 23, color: active ? brand : muted),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: Container(
                        height: 16,
                        constraints: const BoxConstraints(minWidth: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: brand,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: AppText(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              AppText(
                label,
                style: TextStyle(
                  color: active ? brand : muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens what a notification is about. The Applied tab belongs to the shell,
/// so that one is handed back through [onApplications].
Future<void> openWorkerDestination(
  BuildContext context,
  WorkerPushDestination destination, {
  required VoidCallback onApplications,
}) async {
  final Widget page;
  switch (destination) {
    case OpenApplications(:final applicationId):
      applicationFocus.value = applicationId;
      onApplications();
      return;
    case OpenKyc():
      page = const KycPage();
    case OpenJob(:final jobId):
      // The page loads the job itself; only its id is needed.
      page = JobDetailPage(
        Job('', '', '', '', '', '0', 0, const [], '', id: jobId),
      );
    case OpenConversation(:final conversationId):
      page = ConversationPage(conversationId);
  }
  await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

part of '../main.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  int unreadAlerts = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final dashboard = await WorkerApiService().fetchDashboard();
      if (mounted) {
        setState(() => unreadAlerts = dashboard.stats.unreadNotifications);
      }
    } on ApiException {
      // A badge should never show stale or invented data on request failure.
      if (mounted) setState(() => unreadAlerts = 0);
    }
  }

  void _selectTab(int value) {
    setState(() => tab = value);
    if (value == 3) _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        onBrowse: () => setState(() => tab = 1),
        onAlerts: () => _selectTab(3),
        onProfile: () => setState(() => tab = 4),
      ),
      const JobsTab(),
      const ApplicationsTab(),
      NotificationsTab(
        onUnreadChanged: (value) => setState(() => unreadAlerts = value),
      ),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
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
                  'Home',
                  0,
                  tab,
                  _selectTab,
                ),
                _NavItem(
                  LucideIcons.briefcaseBusiness,
                  'Jobs',
                  1,
                  tab,
                  _selectTab,
                ),
                _NavItem(
                  LucideIcons.fileCheck,
                  'Applied',
                  2,
                  tab,
                  _selectTab,
                ),
                _NavItem(
                  LucideIcons.bell,
                  'Alerts',
                  3,
                  tab,
                  _selectTab,
                  badge: unreadAlerts > 0 ? unreadAlerts.toString() : null,
                ),
                _NavItem(
                  LucideIcons.userRound,
                  'Profile',
                  4,
                  tab,
                  _selectTab,
                ),
              ],
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
                  Icon(
                    icon,
                    size: 23,
                    color: active ? brand : const Color(0xFF9AA1AD),
                  ),
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
                        child: Text(
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
              Text(
                label,
                style: TextStyle(
                  color: active ? brand : const Color(0xFF9AA1AD),
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

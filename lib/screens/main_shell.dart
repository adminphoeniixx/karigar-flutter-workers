part of '../main.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  int unreadAlerts = 0;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(5, null);
    _pages[0] = _buildPage(0);
  }

  void _setUnread(int value) {
    if (mounted && unreadAlerts != value) {
      setState(() => unreadAlerts = value);
    }
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => HomeTab(
        onBrowse: () => _selectTab(1),
        onAlerts: () => _selectTab(3),
        onProfile: () => _selectTab(4),
        onUnreadChanged: _setUnread,
      ),
      1 => const JobsTab(),
      2 => const ApplicationsTab(),
      3 => NotificationsTab(onUnreadChanged: _setUnread),
      4 => const ProfileTab(),
      _ => const SizedBox.shrink(),
    };
  }

  void _selectTab(int value) {
    if (value == tab) return;
    _pages[value] ??= _buildPage(value);
    setState(() => tab = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

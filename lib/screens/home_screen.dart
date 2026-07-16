part of '../main.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.onBrowse,
    required this.onAlerts,
    required this.onProfile,
  });
  final VoidCallback onBrowse, onAlerts, onProfile;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool available = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 59,
      leadingWidth: 58,
      leading: const Padding(
        padding: EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: CircleAvatar(
          backgroundColor: Color(0xFFFFE3D8),
          child: Text(
            'RK',
            style: TextStyle(
              color: Color(0xFFC93A06),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      titleSpacing: 8,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back 👋',
            style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            'Rakesh Kumar',
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
                onChanged: (v) => setState(() => available = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: StatCard(
                '128',
                'Available Jobs',
                LucideIcons.briefcaseBusiness,
                Color(0xFFFFF3EE),
                brand,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                'Not submitted',
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
        const Row(
          children: [
            Expanded(
              child: StatCard(
                '3',
                'Applications',
                LucideIcons.check,
                Color(0xFFECFDF5),
                Color(0xFF047857),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                '70%',
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile 70% complete',
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
                  value: .7,
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
        ...jobs.take(3).map(JobCard.new),
      ],
    ),
  );
}

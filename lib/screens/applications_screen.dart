part of '../main.dart';

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});
  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  String filter = 'All';
  static const data = [
    (
      'Plumber for Apartment Project',
      'Sri Sai Constructions',
      'Accepted',
      '10 Jul 2026',
    ),
    ('Electrician — House Wiring', 'Kumar Interiors', 'Pending', '11 Jul 2026'),
    ('Painters — interior', 'ColorHome Painters', 'Rejected', '6 Jul 2026'),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = filter == 'All' ? data : data.where((e) => e.$3 == filter);
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: Column(
        children: [
          Container(
            color: context.surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.isDark
                    ? const Color(0xFF252932)
                    : const Color(0xFFF0F1F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['All', 'Pending', 'Accepted'].map((e) {
                  final active = e == filter;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => setState(() => filter = e),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? context.surfaceColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: active
                              ? const [
                                  BoxShadow(
                                    color: Color(0x0D101828),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          e,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: active ? context.foregroundColor : muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: shown
                  .map(
                    (e) => _ApplicationItem(
                      title: e.$1,
                      employer: e.$2,
                      status: e.$3,
                      date: e.$4,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationItem extends StatelessWidget {
  const _ApplicationItem({
    required this.title,
    required this.employer,
    required this.status,
    required this.date,
  });
  final String title, employer, status, date;
  @override
  Widget build(BuildContext context) {
    final accepted = status == 'Accepted';
    final pending = status == 'Pending';
    final bgColor = accepted
        ? const Color(0xFFECFDF5)
        : pending
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFFFF1F2);
    final fgColor = accepted
        ? const Color(0xFF047857)
        : pending
        ? const Color(0xFFB45309)
        : const Color(0xFFE11D48);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        employer,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusPill(status, bgColor, fgColor),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                const Meta(LucideIcons.mapPin, 'Chennai'),
                const Meta(LucideIcons.indianRupee, '₹900/day', bold: true),
                Meta(LucideIcons.calendarDays, 'Applied $date'),
              ],
            ),
            if (accepted) ...[
              const SizedBox(height: 8),
              const Text(
                '★ Shortlisted by employer',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (accepted)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Contact employer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Leave review'),
                    ),
                  ),
                ],
              )
            else if (pending)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                  ),
                  onPressed: () {},
                  child: const Text('Withdraw'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Find similar jobs'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

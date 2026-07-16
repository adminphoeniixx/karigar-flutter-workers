part of '../../main.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage(this.job, {super.key});
  final Job job;
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool saved = false, applied = false;
  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const Text('Job Details', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: () => setState(() => saved = !saved),
            icon: Icon(
              LucideIcons.bookmark,
              color: saved ? brand : context.foregroundColor,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Tag(j.category),
          const SizedBox(height: 10),
          Text(
            j.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${j.employer} · ★ ${j.rating} (12 reviews)',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              MiniStat('Wage', j.wage),
              MiniStat('Openings', '${j.openings} needed'),
              MiniStat('Location', j.city),
              const MiniStat('Shift', 'Day'),
            ],
          ),
          const SectionTitle('Job description'),
          Text(
            j.description,
            style: const TextStyle(height: 1.55, color: Color(0xFF374151)),
          ),
          const SectionTitle('Skills required'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: j.skills.map(Tag.new).toList(),
          ),
          const SectionTitle('Perks & benefits'),
          const Wrap(spacing: 8, children: [Tag('Food'), Tag('Accommodation')]),
          const SectionTitle('Location'),
          const MapBox(),
          const SizedBox(height: 8),
          Text(
            '📍 ${j.city} · approx 4.2 km away',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.amberTint,
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  color: Color(0xFFB45309),
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Never pay an advance fee for work. Report anything that seems suspicious.',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(top: BorderSide(color: context.borderColor)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {},
                  child: const Icon(LucideIcons.phone, color: brand),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  applied ? 'Applied ✓' : 'Apply Now',
                  onPressed: applied
                      ? null
                      : () => showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) => ApplySheet(
                            onApply: () {
                              Navigator.pop(context);
                              setState(() => applied = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Application submitted! 🎉'),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

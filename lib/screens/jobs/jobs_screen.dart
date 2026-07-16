part of '../../main.dart';

class JobsTab extends StatefulWidget {
  const JobsTab({super.key});
  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  String query = '';
  String cat = 'All';
  @override
  Widget build(BuildContext context) {
    final filtered = jobs
        .where(
          (j) =>
              (cat == 'All' || j.category == cat) &&
              ('${j.title} ${j.category} ${j.skills.join(' ')}')
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Jobs'),
        actions: [
          IconButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => const FilterSheet(),
            ),
            icon: const Icon(LucideIcons.slidersHorizontal),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(bottom: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    hintText: 'Search job title, skill…',
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        [
                          'All',
                          'Plumbing',
                          'Electrical',
                          'Carpentry',
                          'Painting',
                          'Masonry',
                          'AC Repair',
                        ].map((e) {
                          final active = cat == e;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => cat = e),
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
                                child: Text(
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${filtered.length} jobs · Chennai, TN · matched to your skills',
                  style: const TextStyle(color: muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                ...filtered.map(JobCard.new),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class JobCard extends StatelessWidget {
  const JobCard(this.job, {super.key});
  final Job job;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => JobDetailPage(job)),
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tag(job.category),
                if (job == jobs.first || job == jobs[1] || job == jobs.last)
                  const StatusPill('New', Color(0xFFECFDF5), Color(0xFF047857)),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${job.employer} · ★ ${job.rating}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 7,
              children: [
                Meta(LucideIcons.mapPin, job.city),
                Meta(LucideIcons.indianRupee, job.wage, bold: true),
                Meta(LucideIcons.calendarDays, '${job.openings} openings'),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

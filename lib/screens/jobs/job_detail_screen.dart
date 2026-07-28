part of '../../main.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage(this.job, {super.key});
  final Job job;
  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  bool saved = false, applied = false;
  bool loading = false;
  bool detailLoading = true;
  bool canApply = true;
  RatingModel employerRating = const RatingModel(average: 0, count: 0);
  String? contactPhone;
  Job? detailJob;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (widget.job.id == 0) {
      if (mounted) setState(() => detailLoading = false);
      return;
    }
    try {
      final response = await WorkerApiService().fetchJob(widget.job.id);
      if (mounted) setState(() {
        detailJob = Job.fromApi(response.job);
        saved = response.isSaved;
        applied = response.application != null;
        canApply = response.canApply;
        employerRating = response.employerRating;
        contactPhone = response.contactPhone;
      });
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => detailLoading = false);
    }
  }

  Future<void> _toggleSaved() async {
    if (widget.job.id == 0 || loading) return;
    setState(() => loading = true);
    try {
      final result = await WorkerApiService().toggleSaved(widget.job.id);
      if (mounted) {
        setState(() => saved = result);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result ? 'Job saved successfully.' : 'Job removed from saved jobs.'),
        ));
      }
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _apply(String? coverNote, num? expectedWage) async {
    if (widget.job.id == 0 || loading) return;
    setState(() => loading = true);
    try {
      final response = await WorkerApiService().apply(
        widget.job.id,
        coverNote: coverNote,
        expectedWage: expectedWage,
      );
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => applied = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message']?.toString() ?? 'Application submitted!'),
      ));
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final j = detailJob ?? widget.job;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const Text('Job Details', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            onPressed: loading ? null : _toggleSaved,
            icon: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    LucideIcons.bookmark,
                    color: saved ? brand : context.foregroundColor,
                  ),
          ),
        ],
      ),
      body: detailLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
            '${j.employer} · ★ ${employerRating.average.toStringAsFixed(1)} (${employerRating.count} reviews)',
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
                  onPressed: contactPhone == null
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Employer contact: $contactPhone')),
                          ),
                  child: const Icon(LucideIcons.phone, color: brand),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  applied ? 'Applied ✓' : canApply ? 'Apply Now' : 'Applications closed',
                  isLoading: loading,
                  onPressed: applied || !canApply
                      ? null
                      : () => showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) => ApplySheet(
                            onApply: _apply,
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

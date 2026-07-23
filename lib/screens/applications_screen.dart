part of '../main.dart';

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});
  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab> {
  String filter = 'All';
  List<ApplicationModel> applications = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await WorkerApiService().fetchApplications(
        status: filter == 'All' ? null : filter.toLowerCase(),
      );
      if (mounted) setState(() => applications = response.applications);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _withdraw(ApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw application?'),
        content: const Text('This application will be withdrawn from the employer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await WorkerApiService().withdraw(application.id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application withdrawn.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _review(ApplicationModel application) async {
    var rating = 5;
    final comment = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate employer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setDialogState(() => rating = index + 1),
                  icon: Icon(index < rating ? Icons.star : Icons.star_border, color: const Color(0xFFFBBF24)),
                )),
              ),
              TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'Comment (optional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (submit == true) {
      try {
        await WorkerApiService().reviewEmployer(application.id, rating, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted.')));
      } on ApiException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    comment.dispose();
  }

  Future<void> _contact(ApplicationModel application) async {
    final job = application.job;
    if (job == null) return;
    try {
      final detail = await WorkerApiService().fetchJob(job.id);
      if (!mounted) return;
      final phone = detail.contactPhone;
      if (phone == null || phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employer contact is not available yet.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Contact employer'),
          content: SelectableText(phone, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done')),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Applications')),
    body: Column(
      children: [
        Container(
          color: context.surfaceColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: context.subduedColor, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: ['All', 'Pending', 'Accepted'].map((item) {
                final active = item == filter;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () { setState(() => filter = item); _load(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: active ? context.surfaceColor : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                      child: Text(item, textAlign: TextAlign.center, style: TextStyle(color: active ? context.foregroundColor : muted, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: _load, child: const Text('Try again'))]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: applications.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(top: 120),
                              children: const [
                                Icon(LucideIcons.fileX, color: muted, size: 42),
                                SizedBox(height: 12),
                                Text('No applications found', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                SizedBox(height: 4),
                                Text('Jobs you apply to will appear here.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: applications.map((application) => _ApiApplicationCard(
                                application: application,
                                onWithdraw: () => _withdraw(application),
                                onReview: () => _review(application),
                                onContact: () => _contact(application),
                              )).toList(),
                            ),
                    ),
        ),
      ],
    ),
  );
}

class _ApiApplicationCard extends StatelessWidget {
  const _ApiApplicationCard({required this.application, required this.onWithdraw, required this.onReview, required this.onContact});
  final ApplicationModel application;
  final VoidCallback onWithdraw, onReview, onContact;

  @override
  Widget build(BuildContext context) {
    final job = application.job;
    final status = application.status.toLowerCase();
    final accepted = status == 'accepted';
    final pending = status == 'pending';
    final color = accepted ? const Color(0xFF047857) : pending ? const Color(0xFFB45309) : const Color(0xFFE11D48);
    final background = accepted ? const Color(0xFFECFDF5) : pending ? const Color(0xFFFFF7ED) : const Color(0xFFFFF1F2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: job == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailPage(Job.fromApi(job)))),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job?.title ?? 'Job', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(job?.employer.name ?? '', style: const TextStyle(color: muted, fontSize: 12)),
              ])),
              StatusPill(application.statusLabel, background, color),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 6, children: [
              Meta(LucideIcons.mapPin, job?.locationLabel ?? ''),
              Meta(LucideIcons.indianRupee, job?.wageLabel ?? '', bold: true),
              Meta(LucideIcons.calendarDays, 'Applied ${application.createdAgo}'),
            ]),
            if (accepted || application.trackingSteps.any((step) => step.key == 'shortlisted' && step.state == 'done')) ...[
              const SizedBox(height: 9),
              const Text('★ Shortlisted by employer', style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
            if (application.trackingSteps.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ApplicationTracker(steps: application.trackingSteps, applicationStatus: status),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onWithdraw, child: const Text('Withdraw'))),
            ] else if (accepted) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: brand, minimumSize: const Size.fromHeight(44)),
                    onPressed: onContact,
                    child: const Text('Contact employer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    onPressed: onReview,
                    child: const Text('Leave review'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
  );
}
}

class _ApplicationTracker extends StatelessWidget {
  const _ApplicationTracker({required this.steps, required this.applicationStatus});
  final List<TrackingStepModel> steps;
  final String applicationStatus;

  static const labels = {
    'applied': 'Applied',
    'review': 'Under review',
    'shortlisted': 'Shortlisted',
    'decision': 'Decision',
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: context.borderColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Application status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 10),
        ...steps.indexed.map((entry) {
          final index = entry.$1;
          final step = entry.$2;
          final done = step.state == 'done' || applicationStatus == 'accepted';
          final current = step.state == 'current' && applicationStatus != 'accepted';
          final rejected = step.state == 'rejected' && applicationStatus != 'accepted';
          final activeColor = rejected ? const Color(0xFFE11D48) : done ? const Color(0xFF10B981) : current ? brand : muted;
          var label = labels[step.key] ?? step.key;
          if (step.key == 'decision' && applicationStatus == 'accepted') {
            label = 'Selected 🎉';
          }
          if (step.key == 'decision' && step.result?.isNotEmpty == true) {
            label = switch (step.result) {
              'accepted' => 'Selected 🎉',
              'rejected' => 'Not selected',
              'withdrawn' => 'Withdrawn',
              _ => '${step.result![0].toUpperCase()}${step.result!.substring(1)}',
            };
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: done || current || rejected ? activeColor : Colors.transparent, border: Border.all(color: activeColor, width: 2)),
                  child: Icon(rejected ? Icons.close : done ? Icons.check : current ? Icons.circle : null, size: 12, color: Colors.white),
                ),
                if (index < steps.length - 1) Container(width: 2, height: 22, color: done ? activeColor : context.borderColor),
              ]),
              const SizedBox(width: 9),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: done ? activeColor : step.state == 'upcoming' || step.state == 'skipped' ? muted : activeColor)),
              )),
            ],
          );
        }),
      ],
    ),
  );
}

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
                              )).toList(),
                            ),
                    ),
        ),
      ],
    ),
  );
}

class _ApiApplicationCard extends StatelessWidget {
  const _ApiApplicationCard({required this.application, required this.onWithdraw, required this.onReview});
  final ApplicationModel application;
  final VoidCallback onWithdraw, onReview;

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
              Meta(LucideIcons.calendarDays, application.createdAgo),
            ]),
            if (pending) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onWithdraw, child: const Text('Withdraw'))),
            ] else if (accepted) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onReview, child: const Text('Leave review'))),
            ],
          ]),
        ),
      ),
    );
  }
}

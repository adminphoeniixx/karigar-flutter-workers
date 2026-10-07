part of '../main.dart';

class ApplicationsTab extends StatefulWidget {
  const ApplicationsTab({super.key});
  @override
  State<ApplicationsTab> createState() => _ApplicationsTabState();
}

class _ApplicationsTabState extends State<ApplicationsTab>
    with WidgetsBindingObserver {
  String filter = 'All';
  List<ApplicationModel> applications = [];
  bool loading = true;
  String? error;
  StreamSubscription<RemoteMessage>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pushSubscription = PushNotificationService.instance.foregroundMessages
        .listen((message) {
          final type = message.data['type']?.toString() ?? '';
          if (type == 'application.accepted' || type == 'application.rejected')
            _load();
        });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
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
        title: const AppText('Withdraw application?'),
        content: const AppText(
          'This application will be withdrawn from the employer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await WorkerApiService().withdraw(application.id);
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Application withdrawn.')),
        );
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
    }
  }

  Future<void> _review(ApplicationModel application) async {
    var rating = 5;
    var comment = '';
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const AppText('Rate employer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ),
              TextField(
                key: const ValueKey('employer-review-comment'),
                onChanged: (value) => comment = value,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: context.tr('Comment (optional)'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const AppText('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submit != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const AppText('Submit this rating?'),
        content: AppText(
          '${context.trArgs('{rating} out of 5 stars', {'rating': '$rating'})}${comment.trim().isEmpty ? '' : '\n\n${comment.trim()}'}\n\n${context.tr('A rating cannot be edited or deleted after submission.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('Confirm & submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await WorkerApiService().reviewEmployer(
          application.id,
          rating,
          comment: comment.trim().isEmpty ? null : comment.trim(),
        );
        await _load();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('Review submitted.')));
      } on ApiException catch (e) {
        final alreadyReviewed =
            e.statusCode == 422 &&
            e.message.toLowerCase().contains('already reviewed');
        if (alreadyReviewed) {
          await _load();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: AppText(
                alreadyReviewed
                    ? 'You have already reviewed this employer.'
                    : e.message,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _contact(ApplicationModel application) async {
    final job = application.job;
    if (job == null) return;
    try {
      final conversation = await WorkerApiService().openConversation(
        employerId: job.employer.id,
        jobId: job.id,
      );
      if (!mounted) return;
      unawaited(MetaEventsService.instance.employerChatOpened(job.id));
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConversationPage(conversation.id)),
      );
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('My Applications')),
    body: Column(
      children: [
        Container(
          color: context.surfaceColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.subduedColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['All', 'Pending', 'Accepted'].map((item) {
                final active = item == filter;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () {
                      setState(() => filter = item);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? context.surfaceColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: AppText(
                        item,
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
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(error!),
                      TextButton(
                        onPressed: _load,
                        child: const AppText('Try again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: applications.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 120),
                          children: const [
                            Icon(LucideIcons.fileX, color: muted, size: 42),
                            SizedBox(height: 12),
                            AppText(
                              'No applications found',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            AppText(
                              'Jobs you apply to will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: muted),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: applications
                              .map(
                                (application) => _ApiApplicationCard(
                                  application: application,
                                  canReview: application.canReview,
                                  onWithdraw: () => _withdraw(application),
                                  onReview: () => _review(application),
                                  onContact: () => _contact(application),
                                ),
                              )
                              .toList(),
                        ),
                ),
        ),
      ],
    ),
  );
}

class _ApiApplicationCard extends StatelessWidget {
  const _ApiApplicationCard({
    required this.application,
    required this.canReview,
    required this.onWithdraw,
    required this.onReview,
    required this.onContact,
  });
  final ApplicationModel application;
  final bool canReview;
  final VoidCallback onWithdraw, onReview, onContact;

  @override
  Widget build(BuildContext context) {
    final job = application.job;
    final status = application.status.toLowerCase();
    final accepted = status == 'accepted';
    final pending = status == 'pending';
    final color = accepted
        ? const Color(0xFF047857)
        : pending
        ? const Color(0xFFB45309)
        : const Color(0xFFE11D48);
    final background = accepted
        ? const Color(0xFFECFDF5)
        : pending
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFFFF1F2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: job == null
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailPage(Job.fromApi(job)),
                    ),
                  ),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    job?.title ?? 'Job',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    job?.employer.name ?? '',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 7),
                  StatusPill(application.statusLabel, background, color),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Meta(LucideIcons.mapPin, job?.locationLabel ?? ''),
                      Meta(
                        LucideIcons.indianRupee,
                        job?.wageLabel ?? '',
                        bold: true,
                      ),
                      Meta(
                        LucideIcons.calendarDays,
                        context.trArgs('Applied {time}', {
                          'time': context.tr(application.createdAgo),
                        }),
                      ),
                    ],
                  ),
                  if (accepted ||
                      application.trackingSteps.any(
                        (step) =>
                            step.key == 'shortlisted' && step.state == 'done',
                      )) ...[
                    const SizedBox(height: 9),
                    const AppText(
                      '★ Shortlisted by employer',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (application.trackingSteps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ApplicationTracker(
                      steps: application.trackingSteps,
                      applicationStatus: status,
                    ),
                  ],
                  if (application.interview case final interview?) ...[
                    const SizedBox(height: 12),
                    _ApplicationInfo(
                      icon: LucideIcons.calendarCheck,
                      title:
                          '${context.tr('Interview')} • ${context.tr(interview.mode)}',
                      lines: [
                        interview.atLabel,
                        if (interview.note.isNotEmpty) interview.note,
                      ],
                    ),
                  ],
                  if (application.offer case final offer?) ...[
                    const SizedBox(height: 12),
                    _ApplicationInfo(
                      icon: LucideIcons.partyPopper,
                      title: 'Job offer',
                      lines: [
                        '₹${offer.wage.toStringAsFixed(2)} ${context.tr('/month')} • ${offer.startDate}',
                        if (offer.message.isNotEmpty) offer.message,
                      ],
                    ),
                  ],
                  if (pending) ...[
                    const SizedBox(height: 12),
                    _ResponsiveApplicationActions(
                      first: OutlinedButton(
                        onPressed: onWithdraw,
                        child: const AppText(
                          'Withdraw',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      second: FilledButton(
                        onPressed: onContact,
                        child: const AppText(
                          'Message employer',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ] else if (accepted) ...[
                    const SizedBox(height: 12),
                    _ResponsiveApplicationActions(
                      first: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: brand),
                        onPressed: onContact,
                        child: const AppText(
                          'Contact employer',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      second: canReview
                          ? OutlinedButton(
                              onPressed: onReview,
                              child: const AppText(
                                'Rate employer',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : const Center(
                              child: StatusPill(
                                'Review submitted',
                                Color(0xFFECFDF5),
                                Color(0xFF047857),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResponsiveApplicationActions extends StatelessWidget {
  const _ResponsiveApplicationActions({
    required this.first,
    required this.second,
  });

  final Widget first, second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final stack = constraints.maxWidth < 350 || textScale > 1.15;
      if (stack) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 46, child: first),
            const SizedBox(height: 8),
            SizedBox(height: 46, child: second),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: SizedBox(height: 46, child: first)),
          const SizedBox(width: 10),
          Expanded(child: SizedBox(height: 46, child: second)),
        ],
      );
    },
  );
}

class _ApplicationInfo extends StatelessWidget {
  const _ApplicationInfo({
    required this.icon,
    required this.title,
    required this.lines,
  });
  final IconData icon;
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.brandTint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: brand, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              ...lines.map(
                (e) => AppText(
                  e,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ApplicationTracker extends StatelessWidget {
  const _ApplicationTracker({
    required this.steps,
    required this.applicationStatus,
  });
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
        const AppText(
          'Application status',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 10),
        ...steps.indexed.map((entry) {
          final index = entry.$1;
          final step = entry.$2;
          final done = step.state == 'done' || applicationStatus == 'accepted';
          final current =
              step.state == 'current' && applicationStatus != 'accepted';
          final rejected =
              step.state == 'rejected' && applicationStatus != 'accepted';
          final activeColor = rejected
              ? const Color(0xFFE11D48)
              : done
              ? const Color(0xFF10B981)
              : current
              ? brand
              : muted;
          var label = labels[step.key] ?? step.key;
          if (step.key == 'decision' && applicationStatus == 'accepted') {
            label = 'Selected 🎉';
          }
          if (step.key == 'decision' && step.result?.isNotEmpty == true) {
            label = switch (step.result) {
              'accepted' => 'Selected 🎉',
              'rejected' => 'Not selected',
              'withdrawn' => 'Withdrawn',
              _ =>
                '${step.result![0].toUpperCase()}${step.result!.substring(1)}',
            };
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done || current || rejected
                          ? activeColor
                          : Colors.transparent,
                      border: Border.all(color: activeColor, width: 2),
                    ),
                    child: Icon(
                      rejected
                          ? Icons.close
                          : done
                          ? Icons.check
                          : current
                          ? Icons.circle
                          : null,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                  if (index < steps.length - 1)
                    Container(
                      width: 2,
                      height: 22,
                      color: done ? activeColor : context.borderColor,
                    ),
                ],
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: AppText(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? activeColor
                          : step.state == 'upcoming' || step.state == 'skipped'
                          ? muted
                          : activeColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    ),
  );
}

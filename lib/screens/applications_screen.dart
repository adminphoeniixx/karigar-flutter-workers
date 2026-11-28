part of '../main.dart';

/// The application an alert or push is about; the Applied tab brings it to
/// the top and highlights it, then clears this.
final applicationFocus = ValueNotifier<int?>(null);

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
  int? _highlighted;
  Timer? _highlightTimer;

  void _onFocus() {
    if (applicationFocus.value == null) return;
    // It may be under another filter: show them all.
    if (filter != 'All') setState(() => filter = 'All');
    _load();
  }

  /// Puts the focused application first and highlights it for a moment.
  void _applyFocus() {
    final id = applicationFocus.value;
    if (id == null) return;
    final index = applications.indexWhere((a) => a.id == id);
    if (index < 0) return;
    applicationFocus.value = null;
    final focused = applications.removeAt(index);
    applications.insert(0, focused);
    _highlighted = id;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _highlighted = null);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    applicationFocus.addListener(_onFocus);
    _pushSubscription = PushNotificationService.instance.foregroundMessages
        .listen((message) {
          final type = message.data['type']?.toString() ?? '';
          if (type == 'application.accepted' ||
              type == 'application.rejected' ||
              WorkerPushRoute.interviewTypes.contains(type)) {
            _load();
          }
        });
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    applicationFocus.removeListener(_onFocus);
    _highlightTimer?.cancel();
    _pushSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  static const filters = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
    'Withdrawn',
  ];
  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  String? get _status => filter == 'All' ? null : filter.toLowerCase();

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await WorkerApiService().fetchApplications(
        status: _status,
      );
      if (mounted) {
        setState(() {
          applications = response.applications;
          _page = response.pagination.currentPage;
          _lastPage = response.pagination.lastPage;
          _applyFocus();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The server sends 15 applications at a time; the rest load on scroll.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    final status = _status;
    setState(() => _loadingMore = true);
    try {
      final response = await WorkerApiService().fetchApplications(
        status: status,
        page: _page + 1,
      );
      if (!mounted || status != _status) return;
      final known = {for (final a in applications) a.id};
      setState(() {
        applications = [
          ...applications,
          ...response.applications.where((a) => !known.contains(a.id)),
        ];
        _page = response.pagination.currentPage;
        _lastPage = response.pagination.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Application withdrawn.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: AppText('Review submitted.')));
        }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((item) {
                  final active = item == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () {
                        setState(() => filter = item);
                        _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 14,
                        ),
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
                          children: [
                            ...applications.map(
                              (application) => _ApiApplicationCard(
                                application: application,
                                highlighted: application.id == _highlighted,
                                canReview: application.canReview,
                                onWithdraw: () => _withdraw(application),
                                onReview: () => _review(application),
                                onContact: () => _contact(application),
                              ),
                            ),
                            if (_page < _lastPage)
                              PageEndLoader(
                                key: ValueKey('applications-$filter-$_page'),
                                onReached: _loadMore,
                              ),
                          ],
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
    this.highlighted = false,
    required this.canReview,
    required this.onWithdraw,
    required this.onReview,
    required this.onContact,
  });
  final ApplicationModel application;
  final bool highlighted;
  final bool canReview;
  final VoidCallback onWithdraw, onReview, onContact;

  @override
  Widget build(BuildContext context) {
    final job = application.job;
    final status = application.status.toLowerCase();
    final accepted = status == 'accepted';
    final pending = status == 'pending';
    // A shortlisted application is still "pending" on the server; the pill
    // said Pending next to "Shortlisted by employer".
    final shortlisted =
        pending &&
        application.trackingSteps.any(
          (step) => step.key == 'shortlisted' && step.state == 'done',
        );
    final dark = context.isDark;
    final color = accepted || shortlisted
        ? (dark ? const Color(0xFF8FB487) : const Color(0xFF3F5C3A))
        : pending
        ? (dark ? const Color(0xFFE0B36A) : const Color(0xFF9A6413))
        : (dark ? const Color(0xFFF2A39E) : const Color(0xFFB3261E));
    final background = accepted || shortlisted
        ? context.greenTint
        : pending
        ? context.amberTint
        : (dark ? const Color(0xFF3A1D1B) : const Color(0xFFFDECEB));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted ? brand : Colors.transparent,
                width: 2,
              ),
            ),
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
              child: _StripeCard(
                color: color,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          shortlisted ? 'Shortlisted' : application.statusLabel,
                          background,
                          color,
                        ),
                        if (application.jobClosed)
                          const StatusPill(
                            'Job closed',
                            Color(0xFFF1F5F9),
                            Color(0xFF475569),
                          ),
                      ],
                    ),
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
                          // Only the parts the employer gave: an older hire
                          // has no pay or date and showed "₹0 /month •".
                          if ([
                                offer.wageLabel.isNotEmpty
                                    ? offer.wageLabel
                                    : offer.wage > 0
                                    ? '${formatRupees(offer.wage)} ${context.tr('/month')}'
                                    : '',
                                offer.startDateLabel.isNotEmpty
                                    ? context.trArgs('Joining {date}', {
                                        'date': offer.startDateLabel,
                                      })
                                    : '',
                              ].where((part) => part.isNotEmpty).join(' • ')
                              case final terms when terms.isNotEmpty)
                            terms,
                          if (offer.message.isNotEmpty) offer.message,
                          if (offer.address.isNotEmpty) offer.address,
                          if (offer.contactName.isNotEmpty ||
                              offer.contactPhone.isNotEmpty)
                            [
                              offer.contactName,
                              offer.contactPhone,
                            ].where((part) => part.isNotEmpty).join(' · '),
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
      ),
    );
  }
}

/// [AppCard] with a status-coloured stripe down the left edge.
class _StripeCard extends StatelessWidget {
  const _StripeCard({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: context.surfaceColor,
      border: Border.all(color: context.borderColor),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D101828),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    // A Stack, not IntrinsicHeight: the action buttons use a LayoutBuilder,
    // which cannot report an intrinsic height.
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: child,
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: 5,
          child: ColoredBox(color: color),
        ),
      ],
    ),
  );
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

  // One row: a dot per step joined by lines, the label under each. The old
  // vertical list took a third of the screen for four words.
  @override
  Widget build(BuildContext context) {
    final green = context.isDark
        ? const Color(0xFF8FB487)
        : const Color(0xFF3F5C3A);
    const rose = Color(0xFFB3261E);
    final items = steps.map((step) {
      final done = step.state == 'done' || applicationStatus == 'accepted';
      final current =
          step.state == 'current' && applicationStatus != 'accepted';
      final rejected =
          step.state == 'rejected' && applicationStatus != 'accepted';
      final color = rejected
          ? rose
          : done
          ? green
          : current
          ? context.brandText
          : context.borderColor;
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
      return (
        done: done,
        current: current,
        rejected: rejected,
        color: color,
        label: label,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
      decoration: BoxDecoration(
        color: context.subduedColor.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 0
                            ? const SizedBox.shrink()
                            : Container(
                                height: 2.5,
                                color:
                                    items[i].done ||
                                        items[i].current ||
                                        items[i].rejected
                                    ? items[i - 1].color
                                    : context.borderColor,
                              ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              items[i].done ||
                                  items[i].current ||
                                  items[i].rejected
                              ? items[i].color
                              : context.surfaceColor,
                          border: Border.all(color: items[i].color, width: 2),
                        ),
                        child: Icon(
                          items[i].rejected
                              ? Icons.close
                              : items[i].done
                              ? Icons.check
                              : items[i].current
                              ? Icons.circle
                              : null,
                          size: items[i].current ? 8 : 13,
                          color: context.isDark && items[i].done
                              ? const Color(0xFF17120F)
                              : Colors.white,
                        ),
                      ),
                      Expanded(
                        child: i == items.length - 1
                            ? const SizedBox.shrink()
                            : Container(
                                height: 2.5,
                                color:
                                    items[i + 1].done ||
                                        items[i + 1].current ||
                                        items[i + 1].rejected
                                    ? items[i].color
                                    : context.borderColor,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AppText(
                      items[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: items[i].current || items[i].rejected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color:
                            items[i].done ||
                                items[i].current ||
                                items[i].rejected
                            ? items[i].color
                            : context.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

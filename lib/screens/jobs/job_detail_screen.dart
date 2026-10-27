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
  VerificationGate? verification;
  bool _viewLogged = false;
  RatingModel employerRating = const RatingModel(average: 0, count: 0);
  String? contactPhone, contactName, contactDesignation;
  Job? detailJob;
  String _applicationWage = '', _applicationNote = '';

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
      if (mounted) {
        if (!_viewLogged) {
          _viewLogged = true;
          unawaited(MetaEventsService.instance.jobViewed(widget.job.id));
        }
        setState(() {
          detailJob = Job.fromApi(response.job);
          saved = response.isSaved;
          applied = response.application != null;
          canApply = response.canApply;
          verification = response.verification;
          employerRating = response.employerRating;
          contactPhone = response.contactPhone;
          contactName = response.contactName;
          contactDesignation = response.contactDesignation;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    } finally {
      if (mounted) setState(() => detailLoading = false);
    }
  }

  Future<void> _completeKyc() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KycPage()),
    );
    if (mounted) _loadDetail();
  }

  Future<void> _toggleSaved() async {
    if (widget.job.id == 0 || loading) return;
    setState(() => loading = true);
    try {
      final result = await WorkerApiService().toggleSaved(widget.job.id);
      if (mounted) {
        setState(() => saved = result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              result
                  ? 'Job saved successfully.'
                  : 'Job removed from saved jobs.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      final gate = error.errors['verification'];
      if (error.statusCode == 422 && error.code == 'verification_required') {
        setState(
          () => verification = gate is Map
              ? VerificationGate.fromJson(Map<String, dynamic>.from(gate))
              : const VerificationGate(
                  required: true,
                  status: '',
                  canApply: false,
                  message: 'Complete KYC before applying for jobs.',
                ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _callEmployer() async {
    final phone = contactPhone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Employer phone number is not available for this job.',
          ),
        ),
      );
      return;
    }
    final dialNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: dialNumber);
    final opened = await launchUrl(uri);
    if (opened) {
      unawaited(MetaEventsService.instance.employerDialerOpened(widget.job.id));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              context.trArgs('Unable to call {phone} on this device.', {
                'phone': phone,
              }),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openInGoogleMaps(Job job) async {
    final query = job.latitude != null && job.longitude != null
        ? '${job.latitude},${job.longitude}'
        : job.city.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Job location is not available.')),
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to open Google Maps.')),
      );
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
      // Tell the feed that opened this page to remove the job immediately.
      // The API also omits applied jobs from a later unfiltered feed refresh.
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            response['message']?.toString() ?? 'Application submitted!',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openApplicationSheet(Job job) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ApplySheet(
      jobTitle: job.title,
      initialWage: _applicationWage,
      initialNote: _applicationNote,
      onDraftChanged: (wage, note) {
        _applicationWage = wage;
        _applicationNote = note;
      },
      onApply: _apply,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final j = detailJob ?? widget.job;
    final needsKyc = verification?.canApply == false;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: const AppText('Job Details', style: TextStyle(fontSize: 16)),
        actions: [
          if (!detailLoading)
            IconButton(
              tooltip: context.tr(saved ? 'Remove saved job' : 'Save job'),
              onPressed: loading ? null : _toggleSaved,
              icon: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      saved ? LucideIcons.bookmarkCheck : LucideIcons.bookmark,
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  '${j.employer} · ★ ${employerRating.average.toStringAsFixed(1)} (${context.trArgs('{count} reviews', {'count': '${employerRating.count}'})})',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (j.employerVerified)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: VerifiedEmployerBadge(),
                  ),
                if (j.distanceKm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AppText(
                      context.trArgs('{distance} km away', {
                        'distance': j.distanceKm!.toStringAsFixed(1),
                      }),
                    ),
                  ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: MiniStat('Wage', j.wage),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniStat(
                            'Openings',
                            context.trArgs('{count} needed', {
                              'count': '${j.openings}',
                            }),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniStat('Location', j.city),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: MiniStat(
                            'Shift',
                            j.shiftHoursLabel.isEmpty
                                ? 'Not disclosed'
                                : j.shiftHoursLabel,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (j.experienceLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MiniStat('Experience', j.experienceLabel),
                  ),
                if (contactPhone?.isNotEmpty == true &&
                    contactName?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      [contactName, contactDesignation]
                          .whereType<String>()
                          .where((value) => value.trim().isNotEmpty)
                          .join(' · '),
                    ),
                  ),
                const SectionTitle('Job description'),
                Text(
                  j.description,
                  style: const TextStyle(
                    height: 1.55,
                    color: Color(0xFF374151),
                  ),
                ),
                const SectionTitle('Skills required'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: j.skills.map(Tag.new).toList(),
                ),
                const SectionTitle('Perks & benefits'),
                const Wrap(
                  spacing: 8,
                  children: [Tag('Food'), Tag('Accommodation')],
                ),
                const SectionTitle('Location'),
                Semantics(
                  button: true,
                  label: 'Open ${j.city} in Google Maps',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _openInGoogleMaps(j),
                    child: IgnorePointer(
                      child: MapBox(
                        latitude: j.latitude,
                        longitude: j.longitude,
                        address: j.city,
                        label: 'Tap to open in Google Maps',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openInGoogleMaps(j),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.mapPin, size: 16, color: brand),
                        const SizedBox(width: 5),
                        Expanded(
                          child: AppText(
                            j.city,
                            style: const TextStyle(
                              color: brand,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.externalLink,
                          size: 15,
                          color: brand,
                        ),
                      ],
                    ),
                  ),
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
                        child: AppText(
                          'Never pay an advance fee for work. Report anything that seems suspicious.',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
      bottomNavigationBar: detailLoading
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border(top: BorderSide(color: context.borderColor)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (needsKyc && verification!.message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppText(
                          verification!.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    Row(
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
                            onPressed: _callEmployer,
                            child: const Icon(LucideIcons.phone, color: brand),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            applied
                                ? 'Applied ✓'
                                : needsKyc
                                ? 'Complete KYC'
                                : canApply
                                ? 'Apply Now'
                                : 'Applications closed',
                            isLoading: loading,
                            onPressed: applied || (!canApply && !needsKyc)
                                ? null
                                : needsKyc
                                ? _completeKyc
                                : () => _openApplicationSheet(j),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

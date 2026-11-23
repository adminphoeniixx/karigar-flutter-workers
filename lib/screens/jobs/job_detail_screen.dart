part of '../../main.dart';

class JobDetailPage extends StatefulWidget {
  const JobDetailPage(this.job, {super.key, this.onApplied});
  final Job job;
  final VoidCallback? onApplied;
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
      // This pops the apply sheet, not the detail page. Update both this
      // screen and its source feed immediately after a successful apply.
      Navigator.pop(context);
      setState(() => applied = true);
      widget.onApplied?.call();
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
    final requirements = JobRequirements.rows(
      j,
      hindi: Localizations.localeOf(context).languageCode == 'hi',
    );
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
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Tag(j.category),
                    if (j.isPartTime) const Tag('Part time'),
                    if (j.isUrgent) const _JobUrgentTag(),
                  ],
                ),
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (j.shiftHoursLabel.isNotEmpty)
                      JobDetailChip(
                        icon: LucideIcons.clock3,
                        label: j.shiftHoursLabel,
                      ),
                    if (j.experienceLabel.isNotEmpty)
                      JobDetailChip(
                        icon: LucideIcons.briefcaseBusiness,
                        label: j.experienceLabel,
                      ),
                    JobDetailChip(
                      icon: LucideIcons.house,
                      label: j.workModeLabel,
                    ),
                    JobDetailChip(
                      icon: j.interviewMode == 'remote'
                          ? LucideIcons.video
                          : LucideIcons.handshake,
                      label: j.interviewModeLabel,
                    ),
                    if (JobRequirements.feeLabel(j).isNotEmpty)
                      JobDetailChip(
                        icon: LucideIcons.badgeIndianRupee,
                        label: JobRequirements.feeLabel(j),
                      ),
                  ],
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
                      ],
                    );
                  },
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
                if (requirements.isNotEmpty) ...[
                  const SectionTitle('Requirements'),
                  JobRequirementsList(rows: requirements),
                ],
                if (JobRequirements.relocationAllowed(j))
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: _RelocationNotice(),
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

class _JobUrgentTag extends StatelessWidget {
  const _JobUrgentTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const AppText(
      'Urgent hiring',
      style: TextStyle(
        color: Color(0xFFB91C1C),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RelocationNotice extends StatelessWidget {
  const _RelocationNotice();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.circleCheck, color: Color(0xFF2563EB), size: 18),
        SizedBox(width: 8),
        Expanded(
          child: AppText(
            'Karigars from other cities who will move here can apply',
            style: TextStyle(fontSize: 12.5, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class JobRequirementsList extends StatelessWidget {
  const JobRequirementsList({super.key, required this.rows});
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.surfaceColor,
      border: Border.all(color: context.borderColor),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  child: AppText(
                    rows[i].label,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].value,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1)
            Divider(height: 1, color: context.borderColor),
        ],
      ],
    ),
  );
}

class JobRequirements {
  static List<({String label, String value})> rows(
    Job job, {
    required bool hindi,
  }) {
    final data = job.details;
    String text(String key) => data[key]?.toString().trim() ?? '';
    List<String> list(String key) => (data[key] as List? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    String labelOr(
      String labelKey,
      String rawKey,
      String Function(String) localize,
    ) {
      final raw = text(rawKey);
      return hindi && raw.isNotEmpty ? localize(raw) : text(labelKey);
    }

    String days() {
      final values = list('work_days');
      if (!hindi) return text('work_days_label');
      if (values.length == 7) return 'हर दिन';
      const names = {
        'mon': 'सोम',
        'tue': 'मंगल',
        'wed': 'बुध',
        'thu': 'गुरु',
        'fri': 'शुक्र',
        'sat': 'शनि',
        'sun': 'रवि',
      };
      return values
          .map((value) => names[value.toLowerCase()] ?? value)
          .join(', ');
    }

    String interview() {
      final parts = [
        text('interview_days_label'),
        text('interview_hours_label'),
      ].where((value) => value.isNotEmpty).toList();
      var address = text('interview_address');
      if (address.isEmpty && job.interviewMode != 'remote') address = job.city;
      if (address.isNotEmpty) parts.add(address);
      return parts.join(' · ');
    }

    final items = <({String label, String value})>[];
    void add(String label, String value) {
      if (value.isNotEmpty) items.add((label: label, value: value));
    }

    add(
      'Job type',
      labelOr(
        'job_type_label',
        'job_type',
        (v) => v == 'part_time' ? 'पार्ट टाइम' : 'फ़ुल टाइम',
      ),
    );
    add('Education', labelOr('education_label', 'education', _hindiEducation));
    add('English', labelOr('english_label', 'english', _hindiEnglish));
    add('Age', text('age_label'));
    final languages = list('languages');
    add('Languages', languages.join(', '));
    final assets = hindi
        ? list('assets').map(_hindiAsset).toList()
        : list('asset_labels');
    add('Must have', assets.join(', '));
    add(
      'Karigars from',
      hindi ? _hindiReach(data, job.city) : text('reach_label'),
    );
    add('Working days', days());
    add('Interview', interview());
    add('Bonus / incentive', text('incentive_label'));
    add('Other requirements', text('other_requirements'));
    return items;
  }

  static bool relocationAllowed(Job job) =>
      jsonBool(job.details['relocation_allowed']);

  static String feeLabel(Job job) {
    final data = job.details;
    final rawFee =
        data['worker_fee_label'] ??
        data['worker_fee'] ??
        data['worker_fee_amount'] ??
        data['fee'];
    final fee = rawFee is num
        ? '₹${rawFee == rawFee.roundToDouble() ? rawFee.toInt() : rawFee}'
        : rawFee?.toString().trim() ?? '';
    final purpose = data['worker_fee_purpose_label']?.toString().trim() ?? '';
    if (fee.isEmpty) return '';
    return purpose.isEmpty
        ? 'Joining fee: $fee'
        : 'Joining fee: $fee · for $purpose';
  }

  static String _hindiEducation(String value) =>
      const {
        'below_10th': '10वीं से कम भी चलेगा',
        'below 10th': '10वीं से कम भी चलेगा',
        '10th': '10वीं पास या ऊपर',
        '10th_pass': '10वीं पास या ऊपर',
        '10th pass': '10वीं पास या ऊपर',
        '12th': '12वीं पास या ऊपर',
        '12th_pass': '12वीं पास या ऊपर',
        '12th pass': '12वीं पास या ऊपर',
        'iti_diploma': 'ITI / डिप्लोमा या ऊपर',
        'iti / diploma': 'ITI / डिप्लोमा या ऊपर',
        'graduate': 'ग्रेजुएट या ऊपर',
        'post_graduate': 'पोस्ट ग्रेजुएट',
        'post graduate': 'पोस्ट ग्रेजुएट',
      }[value.toLowerCase()] ??
      value;
  static String _hindiEnglish(String value) =>
      const {
        'none': 'अंग्रेज़ी ज़रूरी नहीं',
        'basic': 'थोड़ी अंग्रेज़ी',
        'good': 'अच्छी अंग्रेज़ी',
        'fluent': 'धाराप्रवाह अंग्रेज़ी',
      }[value.toLowerCase()] ??
      value;
  static String _hindiAsset(String value) =>
      const {
        'aadhaar': 'आधार कार्ड',
        'pan': 'पैन कार्ड',
        'bank_account': 'बैंक खाता',
        'smartphone': 'स्मार्टफ़ोन',
        'bike': 'बाइक',
        'driving_licence': 'ड्राइविंग लाइसेंस',
        'own_tools': 'अपने औज़ार',
        'certificate': 'ITI / ट्रेनिंग सर्टिफ़िकेट',
      }[value.toLowerCase()] ??
      value;
  static String _hindiReach(Map<String, dynamic> data, String city) {
    final reach = data['reach']?.toString();
    if (reach == 'nearby') return '${data['reach_km'] ?? 10} किमी के अंदर';
    if (reach == 'city') return '${city.isEmpty ? 'शहर' : city} में कहीं से भी';
    return data['reach_label']?.toString() ?? '';
  }
}

class JobDetailChip extends StatelessWidget {
  const JobDetailChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.isDark ? const Color(0xFF30221D) : const Color(0xFFFFF3EE),
      border: Border.all(color: context.borderColor),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: brand),
        const SizedBox(width: 5),
        Flexible(
          child: AppText(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

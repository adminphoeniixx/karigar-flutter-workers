part of '../main.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    this.onUnreadChanged,
    this.onApplicationsRequested,
  });
  final ValueChanged<int>? onUnreadChanged;
  final VoidCallback? onApplicationsRequested;
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<Map<String, dynamic>> notes = [];
  bool loading = true;
  bool markingAll = false;

  bool get hasUnread =>
      _unread > 0 || notes.any((note) => note['read'] != true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _page = 1, _lastPage = 1, _unread = 0;
  bool _loadingMore = false;

  Future<void> _load() async {
    try {
      final response = await WorkerApiService().notifications();
      if (mounted) setState(() => _apply(response, more: false));
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The next page of alerts once the list nears its end.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await WorkerApiService().notifications(page: _page + 1);
      if (mounted) setState(() => _apply(response, more: true));
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _apply(Map<String, dynamic> response, {required bool more}) {
    final page = Map<String, dynamic>.from(
      response['notifications'] as Map? ?? {},
    );
    final incoming = (page['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final known = {for (final note in notes) note['id']};
    notes = more
        ? [...notes, ...incoming.where((note) => !known.contains(note['id']))]
        : incoming;
    final pagination = page['meta'] is Map
        ? Map<String, dynamic>.from(page['meta'] as Map)
        : page;
    _page = (pagination['current_page'] as num?)?.toInt() ?? 1;
    _lastPage = (pagination['last_page'] as num?)?.toInt() ?? _page;
    // The server counts every unread alert, not only this page's.
    _unread =
        (response['unread'] as num?)?.toInt() ??
        notes.where((note) => note['read'] != true).length;
    widget.onUnreadChanged?.call(_unread);
  }

  Future<void> _read(int index, {bool announce = true}) async {
    if (notes[index]['read'] == true) return;
    try {
      final unread = await WorkerApiService().readNotification(
        notes[index]['id'].toString(),
      );
      if (mounted) {
        setState(() {
          notes[index]['read'] = true;
          _unread = unread;
        });
      }
      widget.onUnreadChanged?.call(unread);
      if (mounted && announce) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Notification marked as read.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    }
  }

  Future<void> _open(int index) async {
    final note = notes[index];
    final destination = WorkerPushRoute.fromData(note);
    // A network issue should not stop a worker reaching what the alert is
    // about. Marking it read is still attempted first.
    await _read(index, announce: destination == null);
    if (!mounted || destination == null) return;
    await openWorkerDestination(
      context,
      destination,
      onApplications: () => widget.onApplicationsRequested?.call(),
    );
  }

  Future<void> _readAll() async {
    if (markingAll || !hasUnread) return;
    setState(() => markingAll = true);
    try {
      await WorkerApiService().readAllNotifications();
      if (mounted) {
        setState(() {
          for (final note in notes) {
            note['read'] = true;
          }
          _unread = 0;
        });
        widget.onUnreadChanged?.call(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('All notifications marked as read.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => markingAll = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));

  String _localizedMessage(BuildContext context, String message) {
    if (Localizations.localeOf(context).languageCode != 'hi') return message;
    final match = RegExp(
      r'^Your application for "(.+)" was (.+)\.$',
    ).firstMatch(message);
    if (match == null) return message;
    final job = match.group(1)!;
    final status = match.group(2)!;
    return 'आपका "$job" के लिए आवेदन ${context.tr(status)} हो गया है।';
  }

  String _localizedCreatedAgo(BuildContext context, String value) {
    if (Localizations.localeOf(context).languageCode != 'hi') return value;
    final match = RegExp(r'^(\d+) months? ago$').firstMatch(value);
    if (match != null) return '${match.group(1)} महीने पहले';
    final days = RegExp(r'^(\d+) days? ago$').firstMatch(value);
    if (days != null) return '${days.group(1)} दिन पहले';
    final hours = RegExp(r'^(\d+) hours? ago$').firstMatch(value);
    if (hours != null) return '${hours.group(1)} घंटे पहले';
    if (value == 'Just now') return 'अभी';
    return value;
  }

  /// One icon per kind of alert, so a hire, a rejection and a chat no longer
  /// all look the same.
  IconData _iconFor(Map<String, dynamic> note) {
    final type = note['type']?.toString() ?? '';
    if (WorkerPushRoute.interviewTypes.contains(type)) {
      return LucideIcons.calendarCheck;
    }
    return switch (type) {
      'chat.message' => LucideIcons.messageSquare,
      'application.accepted' => LucideIcons.partyPopper,
      'application.rejected' => LucideIcons.circleX,
      'application.shortlisted' => LucideIcons.star,
      'job.posted' || 'job.invite' => LucideIcons.briefcaseBusiness,
      'kyc.reviewed' => LucideIcons.shieldCheck,
      _ => LucideIcons.bell,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Notifications'),
      actions: [
        if (!loading && hasUnread)
          if (MediaQuery.sizeOf(context).width < 380)
            IconButton(
              tooltip: context.tr('Mark all as read'),
              onPressed: markingAll ? null : _readAll,
              icon: markingAll
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.checkCheck),
            )
          else
            TextButton.icon(
              onPressed: markingAll ? null : _readAll,
              icon: markingAll
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.checkCheck, size: 16),
              label: const AppText('Mark all read'),
            ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: notes.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.brandTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.bellOff,
                            color: brand,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const AppText(
                        'No notifications yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const AppText(
                        'Job updates and application alerts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, height: 1.4),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: notes.length + (_page < _lastPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notes.length) {
                        return PageEndLoader(onReached: _loadMore);
                      }
                      final note = notes[index];
                      final unread = note['read'] != true;
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: unread
                                  ? (context.isDark
                                        ? const Color(0xFF30221D)
                                        : const Color(0xFFFFF3EE))
                                  : context.surfaceColor,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(color: context.borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _open(index),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: unread
                                              ? brand.withValues(alpha: .12)
                                              : context.subduedColor,
                                          borderRadius: BorderRadius.circular(
                                            11,
                                          ),
                                        ),
                                        child: Icon(
                                          _iconFor(note),
                                          color: unread ? brand : muted,
                                          size: 19,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AppText(
                                              _localizedMessage(
                                                context,
                                                note['message']?.toString() ??
                                                    '',
                                              ),
                                              softWrap: true,
                                              style: TextStyle(
                                                height: 1.4,
                                                fontWeight: unread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            AppText(
                                              _localizedCreatedAgo(
                                                context,
                                                note['created_ago']
                                                        ?.toString() ??
                                                    '',
                                              ),
                                              softWrap: true,
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (unread) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          margin: const EdgeInsets.only(top: 5),
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: brand,
                                            shape: BoxShape.circle,
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
                    },
                  ),
          ),
  );
}

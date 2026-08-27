part of '../main.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key, this.onUnreadChanged});
  final ValueChanged<int>? onUnreadChanged;
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<Map<String, dynamic>> notes = [];
  bool loading = true;
  bool markingAll = false;

  bool get hasUnread => notes.any((note) => note['read'] != true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await WorkerApiService().notifications();
      final page = Map<String, dynamic>.from(
        response['notifications'] as Map? ?? {},
      );
      if (mounted) {
        setState(() {
          notes = (page['data'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
        widget.onUnreadChanged?.call(
          notes.where((note) => note['read'] != true).length,
        );
      }
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _read(int index) async {
    if (notes[index]['read'] == true) return;
    try {
      await WorkerApiService().readNotification(notes[index]['id'].toString());
      if (mounted) setState(() => notes[index]['read'] = true);
      widget.onUnreadChanged?.call(
        notes.where((note) => note['read'] != true).length,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    }
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
        });
        widget.onUnreadChanged?.call(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read.')),
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
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        if (!loading && hasUnread)
          if (MediaQuery.sizeOf(context).width < 380)
            IconButton(
              tooltip: 'Mark all as read',
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
              label: const Text('Mark all read'),
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
                      const Text(
                        'No notifications yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Job updates and application alerts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, height: 1.4),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
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
                                onTap: unread ? () => _read(index) : null,
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
                                          LucideIcons.bell,
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
                                            Text(
                                              note['message']?.toString() ?? '',
                                              softWrap: true,
                                              style: TextStyle(
                                                height: 1.4,
                                                fontWeight: unread
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              note['created_ago']?.toString() ??
                                                  '',
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

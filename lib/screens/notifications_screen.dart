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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification marked as read.')),
      );
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    }
  }

  Future<void> _readAll() async {
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
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton.icon(
          onPressed: _readAll,
          icon: const Icon(LucideIcons.checkCheck, size: 16),
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
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final unread = note['read'] != true;
                return InkWell(
                  onTap: () => _read(index),
                  child: Container(
                    color: unread
                        ? (context.isDark
                              ? const Color(0xFF30221D)
                              : const Color(0xFFFFF3EE))
                        : context.surfaceColor,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: unread ? brand : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note['message']?.toString() ?? '',
                                style: TextStyle(
                                  height: 1.4,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note['created_ago']?.toString() ?? '',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );
}

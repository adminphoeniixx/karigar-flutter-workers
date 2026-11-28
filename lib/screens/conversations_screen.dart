part of '../main.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<ConversationModel> items = [];
  bool loading = true;
  String? error;
  StreamSubscription<RemoteMessage>? push;
  @override
  void initState() {
    super.initState();
    push = PushNotificationService.instance.foregroundMessages
        .where((m) => m.data['type'] == 'chat.message')
        .listen((_) {
          _load();
        });
    _load();
  }

  @override
  void dispose() {
    push?.cancel();
    super.dispose();
  }

  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  /// The server sends 20 chats at a time; the rest load on scroll.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final v = await WorkerApiService().fetchConversations(page: _page + 1);
      if (!mounted) return;
      final known = {for (final c in items) c.id};
      setState(() {
        items = [
          ...items,
          ...v.conversations.where((c) => !known.contains(c.id)),
        ];
        _page = v.pagination.currentPage;
        _lastPage = v.pagination.lastPage;
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

  Future<void> _load() async {
    try {
      final v = await WorkerApiService().fetchConversations();
      if (mounted) {
        setState(() {
          error = null;
          items = v.conversations;
          _page = v.pagination.currentPage;
          _lastPage = v.pagination.lastPage;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        // With nothing loaded, say why instead of "No conversations yet"
        // (offline it looked like the chats were gone).
        if (items.isEmpty) {
          setState(() => error = e.message);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText(e.message)));
        }
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _timeLabel(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    }
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Messages')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: items.isEmpty && error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 40, color: muted),
                      const SizedBox(height: 12),
                      AppText(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() => loading = true);
                            _load();
                          },
                          child: const AppText('Try again'),
                        ),
                      ),
                    ],
                  )
                : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                    children: const [Center(child: _MessagesEmptyState())],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: items.length + 1 + (_page < _lastPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == items.length + 1) {
                        return PageEndLoader(onReached: _loadMore);
                      }
                      if (index == 0) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
                          child: AppText(
                            'Messages from employers about your applications',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        );
                      }
                      final c = items[index - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationPage(c.id),
                                ),
                              );
                              _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: context.brandTint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      LucideIcons.building2,
                                      color: brand,
                                      size: 21,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AppText(
                                          c.otherParty,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        AppText(
                                          c.job?.title ?? 'Job conversation',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AppText(
                                        _timeLabel(c.lastMessageAt),
                                        style: const TextStyle(
                                          color: muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      if (c.unread > 0)
                                        Container(
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: brand,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${c.unread}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
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

class ConversationPage extends StatefulWidget {
  const ConversationPage(this.id, {super.key});
  final int id;

  /// How often an open chat checks for new messages, in case no push comes.
  static const pollEvery = Duration(seconds: 10);
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final input = TextEditingController();
  List<MessageModel> messages = [];
  ConversationModel? conversation;
  bool loading = true, sending = false;
  StreamSubscription<RemoteMessage>? push;

  Timer? _poll;
  int _olderPage = 1, _lastPage = 1;
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(ConversationPage.pollEvery, (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _load(quiet: true);
      }
    });
    push = PushNotificationService.instance.foregroundMessages
        .where(
          (m) =>
              m.data['type'] == 'chat.message' &&
              m.data['conversation_id']?.toString() == widget.id.toString(),
        )
        .listen((_) {
          _load();
        });
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    push?.cancel();
    input.dispose();
    super.dispose();
  }

  /// Merges by id, oldest first, so a refresh never drops older pages or
  /// shows a message twice.
  List<MessageModel> _merge(Iterable<MessageModel> incoming) {
    final byId = <int, MessageModel>{for (final m in messages) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    return byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  /// The newest page. [quiet] refreshes (the timer) don't show errors.
  Future<void> _load({bool quiet = false}) async {
    try {
      final v = await WorkerApiService().fetchConversation(widget.id);
      if (mounted) {
        setState(() {
          conversation = v.conversation;
          messages = _merge(v.messages);
          if (_olderPage == 1) _lastPage = v.pagination.lastPage;
        });
      }
    } on ApiException catch (e) {
      if (mounted && !quiet) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted && loading) setState(() => loading = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _olderPage >= _lastPage) return;
    setState(() => _loadingOlder = true);
    try {
      final v = await WorkerApiService().fetchConversation(
        widget.id,
        page: _olderPage + 1,
      );
      if (mounted) {
        setState(() {
          messages = _merge(v.messages);
          _olderPage = v.pagination.currentPage;
          _lastPage = v.pagination.lastPage;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    final body = input.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final m = await WorkerApiService().sendMessage(widget.id, body);
      if (mounted) {
        setState(() {
          messages = _merge([m]);
          input.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // Let Scaffold move the composer with the keyboard. Adding the keyboard
    // inset inside the composer as well makes it expand upward dramatically.
    resizeToAvoidBottomInset: true,
    appBar: AppBar(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            conversation?.otherParty ?? 'Conversation',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (conversation?.job != null)
            AppText(
              conversation!.job!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
        ],
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...messages.reversed.map(
                      (m) => Align(
                        alignment: m.mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .76,
                          ),
                          decoration: BoxDecoration(
                            color: m.mine ? brand : context.surfaceColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(m.mine ? 16 : 4),
                              bottomRight: Radius.circular(m.mine ? 4 : 16),
                            ),
                            border: m.mine
                                ? null
                                : Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: m.mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.body,
                                style: TextStyle(
                                  color: m.mine
                                      ? Colors.white
                                      : context.foregroundColor,
                                ),
                              ),
                              // When it was sent, like the employer app.
                              if (_sentAt(m.createdAt) case final sentAt?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    sentAt,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: m.mine ? Colors.white70 : muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_olderPage < _lastPage)
                      Center(
                        child: TextButton(
                          onPressed: _loadingOlder ? null : _loadOlder,
                          child: const AppText('Older messages'),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    border: Border(top: BorderSide(color: context.borderColor)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          // The server takes at most 2,000 characters.
                          maxLength: 2000,
                          buildCounter:
                              (
                                context, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => currentLength > 1800
                              ? Text('$currentLength/$maxLength')
                              : null,
                          textInputAction: TextInputAction.newline,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: context.tr('Type a message'),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          minimumSize: const Size(46, 46),
                        ),
                        onPressed: sending ? null : _send,
                        icon: const Icon(LucideIcons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class _MessagesEmptyState extends StatelessWidget {
  const _MessagesEmptyState();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.brandTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.messageCircle, color: brand, size: 30),
      ),
      const SizedBox(height: 18),
      const AppText(
        'No conversations yet',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      const AppText(
        'Employers can message you after you apply for a job.',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, height: 1.4),
      ),
    ],
  );
}

/// "3:05 PM" today, "26 Nov, 3:05 PM" on older days.
String? _sentAt(String value) {
  final at = DateTime.tryParse(value)?.toLocal();
  if (at == null) return null;
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final time =
      '$hour:${at.minute.toString().padLeft(2, '0')} ${at.hour >= 12 ? 'PM' : 'AM'}';
  final now = DateTime.now();
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return time;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${at.day} ${months[at.month - 1]}, $time';
}

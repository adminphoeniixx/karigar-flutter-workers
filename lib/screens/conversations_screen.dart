part of '../main.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<ConversationModel> items = [];
  bool loading = true;
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

  Future<void> _load() async {
    try {
      final v = await WorkerApiService().fetchConversations();
      if (mounted) setState(() => items = v.conversations);
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
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
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 110, 24, 24),
                    children: const [Center(child: _MessagesEmptyState())],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
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
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final input = TextEditingController();
  List<MessageModel> messages = [];
  ConversationModel? conversation;
  bool loading = true, sending = false;
  StreamSubscription<RemoteMessage>? push;
  @override
  void initState() {
    super.initState();
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
    push?.cancel();
    input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await WorkerApiService().fetchConversation(widget.id);
      if (mounted)
        setState(() {
          conversation = v.conversation;
          messages = v.messages;
        });
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final body = input.text.trim();
    if (body.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final m = await WorkerApiService().sendMessage(widget.id, body);
      if (mounted)
        setState(() {
          messages.add(m);
          input.clear();
        });
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
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
                  children: messages.reversed
                      .map(
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
                            child: Text(
                              m.body,
                              style: TextStyle(
                                color: m.mine
                                    ? Colors.white
                                    : context.foregroundColor,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
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

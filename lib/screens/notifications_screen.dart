part of '../main.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final unread = [true, true, true, false, false];
  final notes = [
    [
      '🎉 Sri Sai Constructions accepted your application! You can now contact the employer.',
      '2 hours ago',
    ],
    ["Your 'Electrician' application has been shortlisted.", '5 hours ago'],
    ['3 new Plumbing jobs were added in your area.', '1 day ago'],
    [
      'Complete your KYC — verified workers get 2x more responses.',
      '2 days ago',
    ],
    ['CoolFix Services gave you a ★4.9 rating. Congratulations!', '3 days ago'],
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton.icon(
          onPressed: () =>
              setState(() => unread.fillRange(0, unread.length, false)),
          icon: const Icon(LucideIcons.checkCheck, size: 16),
          label: const Text('Mark all read'),
        ),
      ],
    ),
    body: ListView.builder(
      itemCount: notes.length,
      itemBuilder: (c, i) => InkWell(
        onTap: () => setState(() => unread[i] = false),
        child: Container(
          color: unread[i]
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
                  color: unread[i] ? brand : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notes[i][0],
                      style: TextStyle(
                        height: 1.4,
                        fontWeight: unread[i]
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notes[i][1],
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

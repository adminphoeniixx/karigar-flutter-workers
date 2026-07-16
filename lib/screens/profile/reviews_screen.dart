part of '../../main.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Reviews & Ratings', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppCard(
          child: Column(
            children: [
              Text(
                '4.8',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '★★★★★',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 20,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Based on 23 reviews',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SectionTitle('What employers said'),
        const Review(
          'Sri Sai Constructions',
          'Great work — arrived on time and clean finishing. Will definitely call again.',
          'Jun 2026',
        ),
        const Review(
          'CoolFix Services',
          'Skilled plumber, no complaints at all. Highly recommended.',
          'May 2026',
        ),
        const Review(
          'BuildRight',
          'Good work overall, arrived a little late but the quality was excellent.',
          'Apr 2026',
        ),
      ],
    ),
  );
}

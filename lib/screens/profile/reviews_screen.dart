part of '../../main.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<Map<String, dynamic>> reviews = [];
  Map<String, dynamic> summary = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await WorkerApiService().reviews();
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(response['summary'] as Map? ?? {});
        reviews = (response['data'] as List? ??
                (response['reviews'] as Map?)?['data'] as List? ??
                [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Reviews & Ratings', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  child: Column(
                    children: [
                      Text(
                        summary['average']?.toString() ?? '0',
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: -1),
                      ),
                      const Text('★★★★★', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 20, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('Based on ${summary['count'] ?? 0} reviews', style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SectionTitle('What employers said'),
                ...reviews.map((review) {
                  final reviewer = Map<String, dynamic>.from(review['reviewer'] as Map? ?? review['employer'] as Map? ?? {});
                  return Review(
                    reviewer['name']?.toString() ?? 'Employer',
                    review['comment']?.toString() ?? '',
                    review['created_ago']?.toString() ?? review['created_at']?.toString() ?? '',
                  );
                }),
              ],
            ),
          ),
  );
}

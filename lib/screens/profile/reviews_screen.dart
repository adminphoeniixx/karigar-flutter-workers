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
    if (mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      final response = await WorkerApiService().fetchReviewPage();
      if (!mounted) return;
      setState(() {
        summary = {
          'average': response.summary.average,
          'count': response.summary.count,
        };
        reviews = response.reviews.map(_row).toList();
        _page = response.pagination.currentPage;
        _lastPage = response.pagination.lastPage;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  Map<String, dynamic> _row(ReviewModel review) => {
    'rating': review.rating,
    'comment': review.comment,
    'created_ago': review.createdAgo,
    'reviewer': {'name': review.reviewer.name},
    'job_title': review.jobTitle,
  };

  /// The server sends 15 ratings at a time; the rest load on scroll.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await WorkerApiService().fetchReviewPage(
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        reviews = [...reviews, ...response.reviews.map(_row)];
        _page = response.pagination.currentPage;
        _lastPage = response.pagination.lastPage;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const AppText('Reviews & Ratings', style: TextStyle(fontSize: 16)),
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
                      AppText(
                        ((summary['average'] as num?)?.toDouble() ?? 0)
                            .toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final average =
                              (summary['average'] as num?)?.toDouble() ?? 0;
                          return Icon(
                            index < average.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFBBF24),
                            size: 22,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        context.trArgs('Based on {count} reviews', {
                          'count': '${summary['count'] ?? 0}',
                        }),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Ratings received from employers'),
                if (reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: AppText(
                        'No ratings yet',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ),
                ...reviews.map((review) {
                  final reviewer = Map<String, dynamic>.from(
                    review['reviewer'] as Map? ??
                        review['employer'] as Map? ??
                        {},
                  );
                  return Review(
                    reviewer['name']?.toString() ?? 'Employer',
                    review['comment']?.toString() ?? '',
                    review['created_ago']?.toString() ??
                        review['created_at']?.toString() ??
                        '',
                    rating: (review['rating'] as num?)?.toInt() ?? 0,
                    jobTitle: review['job_title']?.toString(),
                  );
                }),
                if (_page < _lastPage)
                  PageEndLoader(
                    key: ValueKey('reviews-$_page'),
                    onReached: _loadMore,
                  ),
              ],
            ),
          ),
  );
}

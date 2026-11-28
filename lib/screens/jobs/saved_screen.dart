part of '../../main.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});
  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  List<SavedJobModel> saved = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _page = 1, _lastPage = 1;
  bool _loadingMore = false;

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await WorkerApiService().savedJobs();
      if (mounted) setState(() => _apply(response, more: false));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// The server sends 15 saved jobs at a time; the rest load on scroll.
  Future<void> _loadMore() async {
    if (_loadingMore || loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final response = await WorkerApiService().savedJobs(page: _page + 1);
      if (mounted) setState(() => _apply(response, more: true));
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

  void _apply(Map<String, dynamic> response, {required bool more}) {
    final incoming = jsonList(
      response['data'],
    ).map((e) => SavedJobModel.fromJson(jsonMap(e))).toList();
    final known = {for (final item in saved) item.job.id};
    saved = more
        ? [...saved, ...incoming.where((item) => !known.contains(item.job.id))]
        : incoming;
    final meta = PaginationModel.fromJson(jsonMap(response['meta']));
    _page = meta.currentPage > 0 ? meta.currentPage : 1;
    _lastPage = meta.lastPage;
  }

  Future<bool> _remove(SavedJobModel item, {bool updateList = true}) async {
    try {
      final isStillSaved = await WorkerApiService().toggleSaved(item.job.id);
      if (!mounted) return !isStillSaved;
      if (!isStillSaved) {
        if (updateList) {
          setState(() => saved.removeWhere((e) => e.job.id == item.job.id));
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Job removed from saved jobs.')),
        );
        return true;
      }
      return false;
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
      return false;
    }
  }

  Future<void> _open(SavedJobModel item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailPage(Job.fromApi(item.job))),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const AppText('Saved Jobs', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(error!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const AppText('Try again')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: saved.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 120),
                    children: const [
                      Icon(LucideIcons.bookmarkX, color: muted, size: 42),
                      SizedBox(height: 12),
                      AppText(
                        'No saved jobs yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      AppText(
                        'Tap the bookmark icon on a job to save it here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: saved.length + (_page < _lastPage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == saved.length) {
                        return PageEndLoader(onReached: _loadMore);
                      }
                      final item = saved[index];
                      final job = Job.fromApi(item.job);
                      return Dismissible(
                        key: ValueKey(item.job.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _remove(item, updateList: false),
                        onDismissed: (_) {
                          if (mounted) {
                            setState(
                              () => saved.removeWhere(
                                (entry) => entry.job.id == item.job.id,
                              ),
                            );
                          }
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            LucideIcons.trash2,
                            color: Colors.white,
                          ),
                        ),
                        child: JobCard(
                          job,
                          onTap: () => _open(item),
                          trailing: SizedBox.square(
                            dimension: 34,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              tooltip: context.tr('Remove saved job'),
                              onPressed: () => _remove(item),
                              icon: const Icon(
                                LucideIcons.bookmarkCheck,
                                color: brand,
                                size: 21,
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

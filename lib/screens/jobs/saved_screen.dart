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

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await WorkerApiService().fetchSavedJobs();
      if (mounted) setState(() => saved = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _remove(SavedJobModel item) async {
    try {
      final isStillSaved = await WorkerApiService().toggleSaved(item.job.id);
      if (!mounted) return !isStillSaved;
      if (!isStillSaved) {
        setState(() => saved.removeWhere((e) => e.job.id == item.job.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job removed from saved jobs.')),
        );
        return true;
      }
      return false;
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      title: const Text('Saved Jobs', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Try again')),
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
                          Text(
                            'No saved jobs yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap the bookmark icon on a job to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: saved.length,
                        itemBuilder: (context, index) {
                          final item = saved[index];
                          final job = Job.fromApi(item.job);
                          return Dismissible(
                            key: ValueKey(item.job.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _remove(item),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE11D48),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(LucideIcons.trash2, color: Colors.white),
                            ),
                            child: Stack(
                              children: [
                                JobCard(job),
                                Positioned.fill(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _open(item),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    tooltip: 'Remove saved job',
                                    onPressed: () => _remove(item),
                                    icon: const Icon(LucideIcons.bookmarkCheck, color: brand),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
  );
}

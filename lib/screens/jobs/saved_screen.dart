part of '../../main.dart';

class SavedPage extends StatelessWidget {
  const SavedPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Saved Jobs', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [JobCard(jobs[0]), JobCard(jobs[3]), JobCard(jobs[5])],
    ),
  );
}

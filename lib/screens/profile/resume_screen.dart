part of '../../main.dart';

class ResumePage extends StatefulWidget {
  const ResumePage({super.key});
  @override State<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends State<ResumePage> {
  ResumeModel? resume;
  bool loading = true, saving = false;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final value = await WorkerApiService().fetchResume(); if (mounted) setState(() => resume = value); }
    on ApiException catch (e) { if (mounted) _message(e.message); }
    finally { if (mounted) setState(() => loading = false); }
  }
  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      if (await file.length() > 4 * 1024 * 1024) {
        _message('Your resume must be smaller than 4 MB.');
        return;
      }
      setState(() => saving = true);
      final value = await WorkerApiService().uploadResume(file);
      if (mounted) { setState(() => resume = value); _message('Resume uploaded successfully.'); }
    } on MissingPluginException {
      if (mounted) {
        _message(
          'Resume picker was just installed. Close the app completely and run it again.',
        );
      }
    } on PlatformException catch (e) {
      if (mounted) _message(e.message ?? 'Unable to open the PDF picker.');
    } on ApiException catch (e) {
      if (mounted) _message(e.message); // Includes the actionable unreadable-PDF 422 message.
    } finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> _remove() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove resume?'), content: const Text('Future applications will be matched using your profile only.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
    ));
    if (yes != true) return;
    setState(() => saving = true);
    try { await WorkerApiService().removeResume(); if (mounted) setState(() => resume = null); }
    on ApiException catch (e) { if (mounted) _message(e.message); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Resume')),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(resume == null ? LucideIcons.fileUp : LucideIcons.fileCheck, color: brand, size: 32),
        const SizedBox(height: 12),
        Text(resume?.name ?? 'Add your resume', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(resume == null ? 'A readable resume can improve your match score and chances of being shortlisted.' : '${resume!.characters} characters read from your resume • Uploaded ${resume!.uploadedAgo}', style: const TextStyle(color: muted, height: 1.4)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : _pick, icon: const Icon(LucideIcons.upload), label: Text(resume == null ? 'Upload PDF' : 'Replace PDF'))),
        if (resume != null) SizedBox(width: double.infinity, child: TextButton(onPressed: saving ? null : _remove, child: const Text('Remove resume'))),
      ])),
      const SizedBox(height: 12),
      const Text('PDF only • Maximum 4 MB • Scanned/photo PDFs without readable text cannot be used.', style: TextStyle(color: muted, fontSize: 12)),
    ]),
  );
}

part of '../../main.dart';

class KycPage extends StatefulWidget {
  const KycPage({super.key});
  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycDraft {
  _KycDraft(this.definition);
  final VerificationDocumentDefinition definition;
  final number = TextEditingController(),
      alternateNumber = TextEditingController(),
      reason = TextEditingController();
  bool missing = false, hasExistingFile = false;
  String? alternate;
  File? file, alternateFile;
  void dispose() {
    number.dispose();
    alternateNumber.dispose();
    reason.dispose();
  }
}

class _KycPageState extends State<KycPage> {
  final api = WorkerApiService();
  final drafts = <_KycDraft>[];
  KycModel? existing;
  bool loading = true, submitting = false, unavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  VerificationDocumentDefinition _fallback(String key) =>
      VerificationDocumentDefinition(
        key: key,
        label: key == 'pan' ? 'PAN card' : 'Aadhaar card',
        numberField: '${key}_number',
        pattern: key == 'pan' ? r'^[A-Z]{5}[0-9]{4}[A-Z]$' : r'^\d{12}$',
        hint: key == 'pan' ? 'ABCDE1234F' : '12 digits',
        alternates: const [],
      );

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        api.reference(),
        api.fetchKycResponse(),
      ]);
      final reference = values[0] as ReferenceData;
      final result = values[1] as KycResponse;
      final keys = result.requiredDocuments.isNotEmpty
          ? result.requiredDocuments
          : (reference.verification.workerDocuments.isNotEmpty
                ? reference.verification.workerDocuments
                : const ['aadhaar', 'pan']);
      final definitions = keys.map((key) {
        for (final item in reference.verification.documents) {
          if (item.key == key) return item;
        }
        return _fallback(key);
      });
      if (!mounted) return;
      existing = result.kyc;
      for (final definition in definitions) {
        final draft = _KycDraft(definition);
        KycDocumentRecord? record;
        for (final item in existing?.documents ?? const <KycDocumentRecord>[]) {
          if (item.type == definition.key) record = item;
        }
        if (record != null) {
          draft.missing = record.missing;
          draft.number.text = record.number ?? '';
          draft.hasExistingFile =
              record.hasFile || (record.alternate?.hasFile ?? false);
          draft.alternate = record.alternate?.type;
          draft.alternateNumber.text = record.alternate?.number ?? '';
          draft.reason.text = record.alternate?.reason ?? '';
        }
        drafts.add(draft);
      }
      setState(() {});
    } on ApiException catch (error) {
      if (error.statusCode == 404)
        unavailable = true;
      else
        _message(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pick(_KycDraft draft, {required bool alternate}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    if (await file.length() > 5 * 1024 * 1024) {
      _message('Document must be 5 MB or smaller.');
      return;
    }
    setState(() {
      if (alternate)
        draft.alternateFile = file;
      else
        draft.file = file;
    });
  }

  Future<void> _submit() async {
    final fields = <String, String>{};
    final files = <String, File>{};
    for (final draft in drafts) {
      final key = draft.definition.key;
      if (draft.missing) {
        if (draft.alternate == null || draft.reason.text.trim().isEmpty) {
          _message('Choose an alternate document and enter a reason.');
          return;
        }
        if (draft.alternateFile == null && !draft.hasExistingFile) {
          _message('Upload the alternate document.');
          return;
        }
        fields['${key}_missing'] = '1';
        fields['${key}_alt_type'] = draft.alternate!;
        if (draft.alternateNumber.text.trim().isNotEmpty)
          fields['${key}_alt_number'] = draft.alternateNumber.text.trim();
        fields['${key}_reason'] = draft.reason.text.trim();
        if (draft.alternateFile != null)
          files['${key}_alt_doc'] = draft.alternateFile!;
      } else {
        final number = draft.number.text
            .trim()
            .replaceAll(' ', '')
            .toUpperCase();
        if (number.isEmpty ||
            !RegExp(draft.definition.pattern).hasMatch(number)) {
          _message('Enter a valid ${draft.definition.label} number.');
          return;
        }
        if (draft.file == null && !draft.hasExistingFile) {
          _message('Upload your ${draft.definition.label}.');
          return;
        }
        fields[draft.definition.numberField] = number;
        if (draft.file != null) files['${key}_doc'] = draft.file!;
      }
    }
    setState(() => submitting = true);
    try {
      final response = await api.submitKycDocuments(fields, files);
      if (!mounted) return;
      _message(response['message']?.toString() ?? 'KYC submitted for review.');
      for (final draft in drafts) {
        draft.dispose();
      }
      drafts.clear();
      loading = true;
      await _load();
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: AppText(value)));
  @override
  void dispose() {
    for (final draft in drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('KYC Verification', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : unavailable
        ? const SizedBox.shrink()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(existing: existing),
              if (existing == null || existing!.status == 'rejected') ...[
                const SizedBox(height: 16),
                ...drafts.map(_documentCard),
                const SizedBox(height: 8),
                PrimaryButton(
                  'Submit for Verification',
                  isLoading: submitting,
                  onPressed: _submit,
                ),
              ],
            ],
          ),
  );

  Widget _documentCard(_KycDraft draft) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            draft.definition.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: AppText(context.tr("I don't have this")),
            value: draft.missing,
            onChanged: (value) => setState(() => draft.missing = value),
          ),
          if (!draft.missing) ...[
            TextField(
              controller: draft.number,
              decoration: InputDecoration(hintText: draft.definition.hint),
            ),
            const SizedBox(height: 10),
            UploadTile(
              draft.file?.path.split(Platform.pathSeparator).last ??
                  (draft.hasExistingFile
                      ? 'Document on record'
                      : 'Upload photo / PDF'),
              LucideIcons.upload,
              dashed: true,
              onTap: () => _pick(draft, alternate: false),
            ),
          ] else ...[
            DropdownButtonFormField<String>(
              value: draft.alternate,
              hint: AppText(context.tr('Document you have')),
              items: draft.definition.alternates
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.key,
                      child: AppText(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => draft.alternate = value),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.alternateNumber,
              decoration: const InputDecoration(
                hintText: 'Document number (optional)',
              ),
            ),
            const SizedBox(height: 10),
            UploadTile(
              draft.alternateFile?.path.split(Platform.pathSeparator).last ??
                  'Upload alternate document',
              LucideIcons.upload,
              dashed: true,
              onTap: () => _pick(draft, alternate: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.reason,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: "Why don't you have it?",
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({this.existing});
  final KycModel? existing;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        const Icon(LucideIcons.shieldCheck, color: brand, size: 30),
        const SizedBox(height: 8),
        AppText(
          existing == null
              ? 'Verify to build trust'
              : (existing!.statusLabel.isNotEmpty
                    ? existing!.statusLabel
                    : 'KYC status: ${existing!.status}'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (existing?.status == 'rejected' &&
            existing?.remarks?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          AppText(
            existing!.remarks!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
        ],
      ],
    ),
  );
}

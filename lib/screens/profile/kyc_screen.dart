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
  DigilockerModel? digilocker;
  bool startingDigilocker = false;
  String? panError;
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
      digilocker = result.digilocker;
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
      if (error.code == 'verification_disabled') {
        unavailable = true;
        if (mounted) Navigator.of(context).pop();
      } else if (error.statusCode == 404) {
        unavailable = true;
      } else {
        _message(error.message);
      }
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
      // DigiLocker is the Aadhaar record: the server deliberately needs no
      // Aadhaar number or image once it has passed.
      if (key == 'aadhaar' && digilocker?.verified == true) continue;
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
      if (mounted) {
        final fieldError = error.errors['pan_number'];
        if (fieldError != null) {
          setState(
            () => panError = fieldError is List
                ? fieldError.join(' ')
                : fieldError.toString(),
          );
        } else {
          _message(error.message);
        }
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> _verifyWithDigilocker() async {
    if (startingDigilocker) return;
    setState(() => startingDigilocker = true);
    try {
      final start = await api.startDigilocker();
      final data = start['data'] is Map
          ? Map<String, dynamic>.from(start['data'])
          : start;
      final url = data['authorization_url']?.toString();
      final reference = data['reference']?.toString();
      final returnPrefix = data['return_url_prefix']?.toString();
      if (url == null ||
          reference == null ||
          returnPrefix == null ||
          url.isEmpty ||
          reference.isEmpty ||
          returnPrefix.isEmpty) {
        throw ApiException('DigiLocker could not be started.', statusCode: 0);
      }
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DigiLockerWebViewPage(
            authorizationUrl: url,
            returnUrlPrefix: returnPrefix,
          ),
        ),
      );
      if (!mounted) return;
      final outcome = await api.digilockerStatus(reference);
      final status = (outcome['status'] ?? (outcome['data'] as Map?)?['status'])
          ?.toString();
      if (status == 'passed') {
        await _reload();
      } else {
        await _showDigilockerFailure(
          (outcome['message'] ??
                  (outcome['data'] as Map?)?['message'] ??
                  (completed == true
                      ? 'DigiLocker verification was not completed.'
                      : 'DigiLocker did not share your Aadhaar. Try again and tap "Allow" at the end, or type your Aadhaar number instead.'))
              .toString(),
        );
      }
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => startingDigilocker = false);
    }
  }

  Future<void> _showDigilockerFailure(String message) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.info, color: brand, size: 30),
            const SizedBox(height: 12),
            AppText(message, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 18),
            PrimaryButton(
              'Try again',
              onPressed: () {
                Navigator.pop(sheetContext);
                _verifyWithDigilocker();
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Type Aadhaar number'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reload() async {
    for (final draft in drafts) {
      draft.dispose();
    }
    drafts.clear();
    setState(() => loading = true);
    await _load();
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
              if (digilocker?.verified == true) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Row(
                    children: [
                      const Icon(LucideIcons.badgeCheck, color: brand),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppText(
                          'Aadhaar verified: ${digilocker!.name.isEmpty ? 'Verified' : digilocker!.name}${digilocker!.maskedAadhaar.isEmpty ? '' : ' · ${digilocker!.maskedAadhaar}'}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (digilocker?.available == true &&
                  digilocker?.verified != true) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  existing?.status == 'pending'
                      ? 'Skip the wait: Verify with DigiLocker'
                      : 'Verify with DigiLocker',
                  isLoading: startingDigilocker,
                  onPressed: _verifyWithDigilocker,
                ),
                const SizedBox(height: 8),
                const Center(
                  child: AppText(
                    'Or enter Aadhaar number instead',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
              if (existing == null || existing!.status == 'rejected') ...[
                const SizedBox(height: 16),
                ...drafts
                    .where(
                      (draft) =>
                          !(draft.definition.key == 'aadhaar' &&
                              digilocker?.verified == true),
                    )
                    .map(_documentCard),
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
              decoration: InputDecoration(
                hintText: draft.definition.hint,
                errorText: draft.definition.key == 'pan' ? panError : null,
              ),
              onChanged: draft.definition.key == 'pan'
                  ? (_) {
                      if (panError != null) setState(() => panError = null);
                    }
                  : null,
            ),
            const SizedBox(height: 10),
            UploadTile(
              draft.file?.path.split(Platform.pathSeparator).last ??
                  (draft.hasExistingFile
                      ? 'Document on record'
                      : 'Upload photo / PDF (optional)'),
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
        if (existing != null &&
            (existing!.status == 'pending' || existing!.status == 'verified') &&
            (existing!.maskedAadhaar.isNotEmpty ||
                existing!.maskedPan.isNotEmpty)) ...[
          const SizedBox(height: 6),
          AppText(
            [
              existing!.maskedAadhaar,
              existing!.maskedPan,
            ].where((value) => value.isNotEmpty).join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

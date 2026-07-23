part of '../../main.dart';

class KycPage extends StatefulWidget {
  const KycPage({super.key});
  @override
  State<KycPage> createState() => _KycPageState();
}

class _KycPageState extends State<KycPage> {
  final pan = TextEditingController();
  final aadhaar = TextEditingController();
  File? panDoc, aadhaarDoc;
  KycModel? existing;
  bool loading = true, submitting = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final result = await WorkerApiService().fetchKyc();
      if (mounted) setState(() => existing = result);
    } on ApiException catch (e) { if (mounted) _message(e.message); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _pick(bool isPan) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (picked == null) return;
      final file = File(picked.path);
      if (await file.length() > 4 * 1024 * 1024) { _message('Document must be 4 MB or smaller.'); return; }
      if (mounted) setState(() { if (isPan) { panDoc = file; } else { aadhaarDoc = file; } });
    } on PlatformException catch (e) { if (mounted) _message(e.message ?? 'Unable to select document.'); }
  }

  Future<void> _submit() async {
    final panValue = pan.text.trim().toUpperCase();
    final aadhaarValue = aadhaar.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(panValue)) { _message('Enter a valid PAN number.'); return; }
    if (aadhaarValue.length != 12) { _message('Enter a valid 12-digit Aadhaar number.'); return; }
    if (panDoc == null || aadhaarDoc == null) { _message('Upload both PAN and Aadhaar documents.'); return; }
    setState(() => submitting = true);
    try {
      final response = await WorkerApiService().submitKyc(pan: panValue, aadhaar: aadhaarValue, panDoc: panDoc!, aadhaarDoc: aadhaarDoc!);
      if (!mounted) return;
      _message(response['message']?.toString() ?? 'KYC submitted for review.');
      Navigator.pop(context, true);
    } on ApiException catch (e) { if (mounted) _message(e.message); }
    finally { if (mounted) setState(() => submitting = false); }
  }

  void _message(String value) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(value)));
  @override
  void dispose() { pan.dispose(); aadhaar.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(LucideIcons.arrowLeft)), title: const Text('KYC Verification', style: TextStyle(fontSize: 16))),
    body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.brandTint, border: Border.all(color: const Color(0xFFFFC5B0)), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            const CircleAvatar(radius: 26, backgroundColor: Colors.white, child: Icon(LucideIcons.shieldCheck, color: brand, size: 27)),
            const SizedBox(height: 10),
            Text(existing == null ? 'Verify to build trust' : 'KYC status: ${existing!.status}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (existing != null) ...[const SizedBox(height: 6), Text('${existing!.maskedPan}  ·  ${existing!.maskedAadhaar}', style: const TextStyle(color: muted, fontSize: 12))],
          ]),
        ),
        if (existing == null || existing!.status == 'rejected') ...[
          const SizedBox(height: 18), const FieldLabel('PAN Number'),
          TextField(controller: pan, textCapitalization: TextCapitalization.characters, inputFormatters: [LengthLimitingTextInputFormatter(10)], decoration: const InputDecoration(hintText: 'ABCDE1234F')),
          const SizedBox(height: 14), const FieldLabel('Upload PAN card'),
          UploadTile(panDoc == null ? 'Tap to upload\nJPG / PNG · max 4MB' : panDoc!.path.split(Platform.pathSeparator).last, LucideIcons.upload, dashed: true, onTap: () => _pick(true)),
          const SizedBox(height: 14), const FieldLabel('Aadhaar Number'),
          TextField(controller: aadhaar, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)], decoration: const InputDecoration(hintText: '1234 5678 9012')),
          const SizedBox(height: 14), const FieldLabel('Upload Aadhaar'),
          UploadTile(aadhaarDoc == null ? 'Tap to upload\nJPG / PNG · max 4MB' : aadhaarDoc!.path.split(Platform.pathSeparator).last, LucideIcons.upload, dashed: true, onTap: () => _pick(false)),
          const SizedBox(height: 16),
          PrimaryButton(submitting ? 'Submitting...' : 'Submit for Verification', onPressed: submitting ? null : _submit),
        ],
      ],
    ),
  );
}

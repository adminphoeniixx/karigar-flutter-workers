part of '../../main.dart';

class KycPage extends StatelessWidget {
  const KycPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('KYC Verification', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.brandTint,
            border: Border.all(color: const Color(0xFFFFC5B0)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Icon(LucideIcons.shieldCheck, color: brand, size: 27),
              ),
              SizedBox(height: 10),
              Text(
                'Verify to build trust',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                'Employers contact KYC-verified workers first.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const FieldLabel('PAN Number'),
        const TextField(decoration: InputDecoration(hintText: 'ABCDE1234F')),
        const SizedBox(height: 14),
        const FieldLabel('Upload PAN card'),
        const UploadTile(
          'Tap to upload\nJPG / PNG / PDF · max 5MB',
          LucideIcons.upload,
          dashed: true,
        ),
        const SizedBox(height: 14),
        const FieldLabel('Aadhaar Number'),
        const TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1234 5678 9012'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Upload Aadhaar'),
        const UploadTile(
          'Tap to upload\nJPG / PNG / PDF · max 5MB',
          LucideIcons.upload,
          dashed: true,
        ),
        const SizedBox(height: 10),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.shield, color: Color(0xFF047857), size: 17),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Your documents are encrypted and used only for verification.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          'Submit for Verification',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

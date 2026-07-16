part of '../../main.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool available = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Color(0xFFFFE3D8),
                    child: Text(
                      'RK',
                      style: TextStyle(
                        color: Color(0xFFC93A06),
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: brand,
                      child: Icon(
                        LucideIcons.camera,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Tap to change photo',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const FieldLabel('Full name'),
        const TextField(
          controller: null,
          decoration: InputDecoration(hintText: 'Rakesh Kumar'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Mobile number'),
        TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: '+91 98765 43210',
            fillColor: context.subduedColor,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Verified via OTP · can't be changed",
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Skills'),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Tag('Plumbing ×'),
              Tag('Pipe Fitting ×'),
              Tag('Tiling ×'),
              SizedBox(
                width: 90,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '+ Add skill',
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Type and press Enter. e.g. Waterproofing, Welding',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Experience'),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '6',
                      suffixText: 'years',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Available'),
                  Container(
                    height: 49,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      border: Border.all(color: context.borderColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'For work',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: available,
                          activeTrackColor: brand,
                          onChanged: (v) => setState(() => available = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Languages you speak'),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Tag('Hindi'),
            Tag('Tamil'),
            Tag('English'),
            Tag('Telugu'),
            Tag('+ Add'),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Helps match you with employers who speak your language.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Education'),
        DropdownButtonFormField<String>(
          initialValue: '12th Pass',
          items: [
            'Below 10th',
            '10th Pass',
            '12th Pass',
            'ITI / Diploma',
            'Graduate',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('Bio'),
        const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText:
                '6 years of experience. Bathroom & kitchen plumbing, leak repair and tiling specialist. On-time and clean work.',
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Expected wage'),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '900',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Per'),
                  DropdownButtonFormField<String>(
                    initialValue: 'day',
                    items: ['day', 'hour', 'month', 'contract']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ],
        ),
        const SectionTitle('Location'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: 'Tamil Nadu',
                items: ['Tamil Nadu', 'Kerala', 'Karnataka']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: 'Chennai',
                items: ['Chennai', 'Coimbatore', 'Madurai']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Pin your location'),
        const MapBox(),
        const SizedBox(height: 6),
        const Text(
          'Tap the map to set your exact location (nearby jobs are matched to this)',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SectionTitle('Payout'),
        const FieldLabel('UPI ID'),
        const TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(LucideIcons.indianRupee, size: 18),
            hintText: 'rakesh@okhdfcbank',
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Job payments will be sent directly to this UPI.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 20),
        PrimaryButton('Save Profile', onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

part of '../../main.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  int step = 0;
  String? gender;
  String education = '10th Pass';
  final selected = <String>{'Tamil', 'Hindi'};
  static const skills = [
    'Plumbing',
    'Pipe Fitting',
    'Waterproofing',
    'Tiling',
    'Electrical Wiring',
    'Carpentry',
    'Painting',
    'Masonry',
    'AC Repair',
    'Welding',
    'Driving',
    'Helper',
  ];
  static const languages = [
    'Hindi',
    'English',
    'Tamil',
    'Telugu',
    'Kannada',
    'Malayalam',
    'Marathi',
    'Bengali',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () {
          if (step > 0) {
            setState(() => step--);
          } else {
            Navigator.maybePop(context);
          }
        },
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const Text('Set up your profile', style: TextStyle(fontSize: 16)),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Text(
              '${step + 1}/6',
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        LinearProgressIndicator(
          value: (step + 1) / 6,
          minHeight: 4,
          backgroundColor: const Color(0xFFF0F1F4),
          color: brand,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: _stepContent(),
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            if (step == 5) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _finish,
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: step == 5 ? 2 : 1,
              child: PrimaryButton(
                step == 5 ? 'Finish setup' : 'Continue',
                onPressed: () {
                  if (step < 5) {
                    setState(() => step++);
                  } else {
                    _finish();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _finish() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const MainShell()),
    (_) => false,
  );

  List<Widget> _stepContent() {
    final heads = [
      "What's your name?",
      'Where do you want to work?',
      'Which languages do you speak?',
      'How much have you studied?',
      'What work do you do?',
      'Verify your ID',
    ];
    final subs = [
      'Employers will see this on your profile.',
      "We'll show you jobs near this location first.",
      'Employers prefer workers who speak their language. Choose all that apply.',
      'Some jobs need a minimum education. This helps us match you.',
      'Pick your main category and add your skills — jobs are matched to these.',
      'Add Aadhaar & PAN to get a Verified badge — verified workers get 2x more responses. You can skip and do this later.',
    ];
    final out = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              heads[step],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
          ),
          if (step == 5) const StatusPill('Optional', Color(0xFFF0F1F4), muted),
        ],
      ),
      const SizedBox(height: 6),
      Text(subs[step], style: const TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 22),
    ];
    if (step == 0) {
      out.addAll([
        const FieldLabel('Full name'),
        const TextField(
          decoration: InputDecoration(hintText: 'e.g. Rakesh Kumar'),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Gender'),
        Wrap(
          spacing: 8,
          children: ['Male', 'Female', 'Other']
              .map(
                (e) => ChoiceChip(
                  label: Text(e),
                  selected: gender == e,
                  onSelected: (_) => setState(() => gender = e),
                ),
              )
              .toList(),
        ),
      ]);
    }
    if (step == 1) {
      out.addAll([
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: brand,
            backgroundColor: context.brandTint,
            side: BorderSide.none,
          ),
          onPressed: () {},
          icon: const Icon(LucideIcons.locateFixed),
          label: const Text('Use my current location'),
        ),
        const SizedBox(height: 16),
        const FieldLabel('State'),
        DropdownButtonFormField<String>(
          initialValue: null,
          hint: const Text('Select state'),
          items: [
            'Tamil Nadu',
            'Kerala',
            'Karnataka',
            'Maharashtra',
            'Delhi',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('City / District'),
        DropdownButtonFormField<String>(
          initialValue: null,
          hint: const Text('Select city'),
          items: [
            'Chennai',
            'Coimbatore',
            'Madurai',
            'Salem',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('How far can you travel?'),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [Tag('Within 5 km'), Tag('Within 15 km'), Tag('Anywhere')],
        ),
      ]);
    }
    if (step == 2) {
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: languages
              .map(
                (e) => FilterChip(
                  label: Text(e),
                  selected: selected.contains(e),
                  onSelected: (v) =>
                      setState(() => v ? selected.add(e) : selected.remove(e)),
                ),
              )
              .toList(),
        ),
      );
    }
    if (step == 3) {
      out.addAll(
        [
          'Below 10th',
          '10th Pass',
          '12th Pass',
          'ITI / Diploma',
          'Graduate',
          'Post Graduate',
        ].map((e) {
          final active = education == e;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => education = e),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: active
                      ? (context.isDark
                            ? const Color(0xFF30221D)
                            : const Color(0xFFFFF3EE))
                      : context.surfaceColor,
                  border: Border.all(
                    color: active ? brand : context.borderColor,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? brand : context.borderColor,
                          width: 2,
                        ),
                      ),
                      child: active
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                color: brand,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      e,
                      style: TextStyle(
                        color: active
                            ? (context.isDark
                                  ? const Color(0xFFFF8A62)
                                  : const Color(0xFFC93A06))
                            : context.foregroundColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      );
    }
    if (step == 4) {
      out.addAll([
        const FieldLabel('Main job category'),
        DropdownButtonFormField<String>(
          initialValue: null,
          hint: const Text('Select category'),
          items: [
            'Plumbing',
            'Electrical',
            'Carpentry',
            'Painting',
            'Masonry',
            'AC Repair',
            'Driving',
            'Housekeeping',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('Your skills'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skills
              .map(
                (e) => FilterChip(
                  label: Text(e),
                  selected: selected.contains(e),
                  onSelected: (v) =>
                      setState(() => v ? selected.add(e) : selected.remove(e)),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap to select. You can add more later in your profile.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Experience'),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'years',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Expected wage'),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '800',
                      suffixText: '/day',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ]);
    }
    if (step == 5) {
      out.addAll([
        const FieldLabel('Aadhaar number'),
        const TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1234 5678 9012'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('PAN number'),
        const TextField(decoration: InputDecoration(hintText: 'ABCDE1234F')),
        const SizedBox(height: 14),
        const UploadTile(
          'Upload Aadhaar & PAN photo\nJPG / PNG / PDF · max 5MB each',
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
                'Documents are encrypted and used only for verification.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ]);
    }
    return out;
  }
}

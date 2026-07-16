part of '../../main.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profile'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: context.surfaceColor,
              side: BorderSide(color: context.borderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _open(context, const SettingsPage()),
            icon: const Icon(LucideIcons.settings, size: 21),
          ),
        ),
      ],
    ),
    body: ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brand, Color(0xFFC93A06)],
            ),
          ),
          child: const Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFFFFE3D8),
                    child: Text(
                      'RK',
                      style: TextStyle(
                        color: Color(0xFFC93A06),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.white,
                      child: Icon(LucideIcons.camera, color: brand, size: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rakesh Kumar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Plumber · 6 yrs exp',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(LucideIcons.mapPin, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Chennai, TN',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        SizedBox(width: 12),
                        Text(
                          '★ 4.8 (23)',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC93A06),
              backgroundColor: context.brandTint,
              side: const BorderSide(color: Color(0xFFFFC5B0)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _open(context, const EditProfilePage()),
            icon: const Icon(LucideIcons.pencil, size: 19),
            label: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: SectionTitle('My skills'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag('Plumbing'),
              Tag('Pipe Fitting'),
              Tag('Waterproofing'),
              Tag('Tiling'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: context.borderColor),
        MenuRow(
          LucideIcons.shieldCheck,
          'KYC Verification',
          'Verify your PAN & Aadhaar',
          () => _open(context, const KycPage()),
          trailing: const StatusPill(
            'Not submitted',
            Color(0xFFFFF7ED),
            Color(0xFFB45309),
          ),
        ),
        MenuRow(
          LucideIcons.bookmark,
          'Saved Jobs',
          '3 saved jobs',
          () => _open(context, const SavedPage()),
        ),
        MenuRow(
          LucideIcons.star,
          'Reviews & Ratings',
          '4.8 from 23 reviews',
          () => _open(context, const ReviewsPage()),
        ),
        MenuRow(
          LucideIcons.settings,
          'Settings',
          'Language, alerts & security',
          () => _open(context, const SettingsPage()),
        ),
      ],
    ),
  );
}

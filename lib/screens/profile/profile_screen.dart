part of '../../main.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic> profile = {};
  Map<String, dynamic> stats = {};
  bool loading = true;
  bool uploadingAvatar = false;

  String get name => profile['name']?.toString() ?? 'Worker';
  List<String> get skills =>
      (profile['skills'] as List? ?? []).map((e) => e.toString()).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = WorkerApiService();
      final results = await Future.wait([
        service.profile(),
        service.dashboard(),
      ]);
      if (!mounted) return;
      final worker = results[0] as WorkerProfileModel;
      final dashboard = results[1] as Map<String, dynamic>;
      setState(() {
        profile = worker.data;
        profileAvatarUrl.value = worker.data['avatar_url']?.toString();
        stats = Map<String, dynamic>.from(dashboard['stats'] as Map? ?? {});
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _changeAvatar() async {
    if (uploadingAvatar) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (await file.length() > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar image must be 2 MB or smaller.'),
            ),
          );
        }
        return;
      }
      setState(() => uploadingAvatar = true);
      final url = await WorkerApiService().uploadAvatar(file);
      if (!mounted) return;
      setState(() => profile['avatar_url'] = url);
      profileAvatarUrl.value = url;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Stop the app and run it again to initialize photo picker.',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Unable to open photo picker.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Profile')),
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
            onPressed: () => _open(const SettingsPage()),
            icon: const Icon(LucideIcons.settings, size: 21),
          ),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [brand, Color(0xFFC93A06)],
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: uploadingAvatar ? null : _changeAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: const Color(0xFFFFE3D8),
                              backgroundImage:
                                  profile['avatar_url']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? NetworkImage(
                                      profile['avatar_url'].toString(),
                                    )
                                  : null,
                              child: uploadingAvatar
                                  ? const CircularProgressIndicator()
                                  : profile['avatar_url']
                                            ?.toString()
                                            .isNotEmpty !=
                                        true
                                  ? Text(
                                      name
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .take(2)
                                          .map((e) => e.isEmpty ? '' : e[0])
                                          .join()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFC93A06),
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const Positioned(
                              bottom: -2,
                              right: -2,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  LucideIcons.camera,
                                  color: brand,
                                  size: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${skills.isEmpty ? 'Worker' : skills.first} · ${profile['experience_years'] ?? 0} yrs exp',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.mapPin,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${profile['city'] ?? ''}, ${profile['state'] ?? ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
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
                    onPressed: () => _open(const EditProfilePage()),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map(Tag.new).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: context.borderColor),
                MenuRow(
                  LucideIcons.shieldCheck,
                  'KYC Verification',
                  'Verify your PAN & Aadhaar',
                  () => _open(const KycPage()),
                  trailing: StatusPill(
                    stats['kyc_status_label']?.toString() ?? 'Not submitted',
                    const Color(0xFFFFF7ED),
                    const Color(0xFFB45309),
                  ),
                ),
                MenuRow(
                  LucideIcons.fileText,
                  'My Resume',
                  'Improve your application match score',
                  () => _open(const ResumePage()),
                ),
                MenuRow(
                  LucideIcons.messageCircle,
                  'Messages',
                  'Chat with employers you applied to',
                  () => _open(const ConversationsPage()),
                ),
                MenuRow(
                  LucideIcons.bookmark,
                  'Saved Jobs',
                  '${stats['saved_jobs'] ?? 0} saved jobs',
                  () => _open(const SavedPage()),
                ),
                MenuRow(
                  LucideIcons.star,
                  'Reviews & Ratings',
                  'Ratings employers gave you',
                  () => _open(const ReviewsPage()),
                ),
                MenuRow(
                  LucideIcons.settings,
                  'Settings',
                  'Language, alerts & security',
                  () => _open(const SettingsPage()),
                ),
              ],
            ),
          ),
  );
}

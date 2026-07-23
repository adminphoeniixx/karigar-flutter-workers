part of '../../main.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final experience = TextEditingController();
  final bio = TextEditingController();
  final wage = TextEditingController();
  final upi = TextEditingController();
  List<String> skills = [], languages = [], states = [], cities = [];
  String? education, wageType, state, city;
  bool available = true, loading = true, saving = false;
  bool uploadingAvatar = false;
  bool locating = false;
  String? avatarUrl;
  double? latitude, longitude;
  int travelRadiusKm = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = WorkerApiService();
      final worker = await service.profile();
      final reference = await service.reference();
      final data = worker.data;
      final selectedState = data['state']?.toString();
      final loadedCities = selectedState == null
          ? <String>[]
          : await service.cities(selectedState);
      if (!mounted) return;
      setState(() {
        name.text = data['name']?.toString() ?? '';
        email.text = data['email']?.toString() ?? '';
        phone.text = data['phone']?.toString() ?? '';
        experience.text = data['experience_years']?.toString() ?? '';
        bio.text = data['bio']?.toString() ?? '';
        wage.text = data['expected_wage']?.toString() ?? '';
        upi.text = data['payout_upi']?.toString() ?? '';
        avatarUrl = data['avatar_url']?.toString();
        latitude = (data['latitude'] as num?)?.toDouble();
        longitude = (data['longitude'] as num?)?.toDouble();
        travelRadiusKm = (data['travel_radius_km'] as num?)?.toInt() ?? 15;
        skills = (data['skills'] as List? ?? []).map((e) => e.toString()).toList();
        languages = (data['spoken_languages'] as List? ?? []).map((e) => e.toString()).toList();
        available = data['available'] == true;
        education = data['education']?.toString();
        wageType = data['wage_type']?.toString();
        state = selectedState;
        city = data['city']?.toString();
        states = reference.states;
        cities = loadedCities;
      });
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectState(String value) async {
    setState(() { state = value; city = null; cities = []; });
    try {
      final result = await WorkerApiService().cities(value);
      if (mounted && state == value) setState(() => cities = result);
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    }
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final values = <String, dynamic>{
        'name': name.text.trim(),
        if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
        'skills': skills,
        'experience_years': int.tryParse(experience.text) ?? 0,
        'education': education,
        'spoken_languages': languages,
        'bio': bio.text.trim(),
        'expected_wage': num.tryParse(wage.text),
        'wage_type': wageType,
        'state': state,
        'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'travel_radius_km': travelRadiusKm,
        'available': available,
        'payout_upi': upi.text.trim(),
      }..removeWhere((key, value) => value == null);
      await WorkerApiService().updateProfile(values);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickAvatar() async {
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
        _error('Avatar image must be 2 MB or smaller.');
        return;
      }
      setState(() => uploadingAvatar = true);
      final uploadedUrl = await WorkerApiService().uploadAvatar(file);
      if (!mounted) return;
      setState(() => avatarUrl = uploadedUrl);
      profileAvatarUrl.value = uploadedUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } on MissingPluginException catch (error) {
      debugPrint('[AVATAR PICKER] Missing plugin: $error');
      if (mounted) {
        _error('Photo picker is not initialized. Stop the app and run it again.');
      }
    } on PlatformException catch (error) {
      debugPrint('[AVATAR PICKER] ${error.code}: ${error.message}');
      if (mounted) {
        final denied = error.code.toLowerCase().contains('permission') ||
            (error.message?.toLowerCase().contains('permission') ?? false);
        _error(
          denied
              ? 'Photo permission is required. Enable it in app settings.'
              : error.message ?? 'Unable to open the photo picker.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[AVATAR PICKER] $error\n$stackTrace');
      if (mounted) _error('Unable to select profile photo: $error');
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> _pinCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _error('Please turn on device location.');
        await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _error('Location permission is required to pin your location.');
        if (permission == LocationPermission.deniedForever) await Geolocator.openAppSettings();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location pinned successfully. Save profile to update it.')),
      );
    } catch (_) {
      if (mounted) _error('Unable to get your current location. Please try again.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    for (final item in [name, email, phone, experience, bio, wage, upi]) { item.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(LucideIcons.arrowLeft)),
      title: const Text('Edit Profile', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(52),
                  onTap: uploadingAvatar ? null : _pickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFFFFE3D8),
                        backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: uploadingAvatar
                            ? const CircularProgressIndicator()
                            : avatarUrl == null || avatarUrl!.isEmpty
                                ? Text(
                                    name.text.trim().isEmpty
                                        ? 'W'
                                        : name.text.trim().split(RegExp(r'\s+')).take(2).map((e) => e[0]).join().toUpperCase(),
                                    style: const TextStyle(color: Color(0xFFC93A06), fontSize: 30, fontWeight: FontWeight.w700),
                                  )
                                : null,
                      ),
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: brand,
                          child: Icon(LucideIcons.camera, color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Tap to change photo', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 20),
              const FieldLabel('Full name'),
              TextField(controller: name),
              const SizedBox(height: 14),
              const FieldLabel('Email'),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'you@example.com')),
              const SizedBox(height: 14),
              const FieldLabel('Mobile number'),
              TextField(controller: phone, enabled: false),
              const SizedBox(height: 14),
              const FieldLabel('Skills'),
              Wrap(spacing: 8, runSpacing: 8, children: skills.map(Tag.new).toList()),
              const SizedBox(height: 14),
              const FieldLabel('Experience'),
              TextField(controller: experience, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: 'years')),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for work'),
                value: available,
                activeTrackColor: brand,
                onChanged: (value) => setState(() => available = value),
              ),
              const FieldLabel('Languages you speak'),
              Wrap(spacing: 8, runSpacing: 8, children: languages.map(Tag.new).toList()),
              const SizedBox(height: 14),
              const FieldLabel('Education'),
              DropdownButtonFormField<String>(
                initialValue: education,
                items: ['Below 10th', '10th Pass', '12th Pass', 'ITI / Diploma', 'Graduate', 'Post Graduate'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => education = value),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Bio'),
              TextField(controller: bio, maxLines: 4),
              const SizedBox(height: 14),
              const FieldLabel('Expected wage'),
              TextField(controller: wage, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ')),
              const SizedBox(height: 14),
              const FieldLabel('Wage type'),
              DropdownButtonFormField<String>(
                initialValue: wageType,
                items: ['hourly', 'daily', 'monthly'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => wageType = value),
              ),
              const SectionTitle('Location'),
              DropdownButtonFormField<String>(
                initialValue: state,
                hint: const Text('Select state'),
                items: states.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) { if (value != null) _selectState(value); },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(state),
                initialValue: city,
                hint: const Text('Select city'),
                items: cities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) => setState(() => city = value),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Pin your location'),
              MapBox(
                onTap: locating ? null : _pinCurrentLocation,
                label: locating
                    ? 'Detecting location...'
                    : latitude == null || longitude == null
                        ? 'Tap to use current location'
                        : '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 6),
              Text(
                latitude == null ? 'Tap the map to pin your exact location.' : 'Pinned coordinates will be used to match nearby jobs.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Travel radius'),
              Wrap(
                spacing: 8,
                children: [(5, '5 km'), (15, '15 km'), (30, '30 km'), (100, 'Anywhere')]
                    .map((item) => ChoiceChip(
                          label: Text(item.$2),
                          selected: travelRadiusKm == item.$1,
                          onSelected: (_) => setState(() => travelRadiusKm = item.$1),
                        ))
                    .toList(),
              ),
              const SectionTitle('Payout'),
              const FieldLabel('UPI ID'),
              TextField(controller: upi, decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.indianRupee, size: 18))),
              const SizedBox(height: 20),
              PrimaryButton(saving ? 'Saving...' : 'Save Profile', onPressed: saving ? null : _save),
            ],
          ),
  );
}

part of '../../main.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.api});
  final WorkerApiService? api;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final service = widget.api ?? WorkerApiService();
  List<String> educationOptions = [
    'Below 10th',
    '10th Pass',
    '12th Pass',
    'ITI / Diploma',
    'Graduate',
    'Post Graduate',
  ];

  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final experience = TextEditingController();
  final bio = TextEditingController();
  final wage = TextEditingController();
  final upi = TextEditingController();
  final address = TextEditingController();
  List<String> skillOptions = [], languageOptions = [];
  String? loadError;
  List<String> skills = [], languages = [], states = [], cities = [];
  String? education, state, city;
  bool available = true, loading = true, saving = false;
  bool uploadingAvatar = false;
  bool locating = false;
  bool loadingCities = false;
  int cityRequest = 0;
  String? avatarUrl;
  double? latitude, longitude;
  int travelRadiusKm = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final worker = await service.profile();
      final reference = await service.reference();
      final data = worker.data;
      final stateOptions = ProfileDropdownOptions(
        reference.states,
        data['state']?.toString(),
      );
      final selectedState = stateOptions.selected;
      final loadedCities = selectedState == null
          ? <String>[]
          : await service.cities(selectedState);
      if (!mounted) return;
      setState(() {
        address.text = data['address']?.toString() ?? '';
        name.text = data['name']?.toString() ?? '';
        email.text = data['email']?.toString() ?? '';
        phone.text = data['phone']?.toString() ?? '';
        experience.text = data['experience_years']?.toString() ?? '';
        bio.text = data['bio']?.toString() ?? '';
        wage.text = monthlyProfileWage(
          data['expected_wage'],
          data['wage_type'],
        );
        upi.text = data['payout_upi']?.toString() ?? '';
        avatarUrl = data['avatar_url']?.toString();
        latitude = (data['latitude'] as num?)?.toDouble();
        longitude = (data['longitude'] as num?)?.toDouble();
        travelRadiusKm = (data['travel_radius_km'] as num?)?.toInt() ?? 15;
        skills = (data['skills'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        languages = (data['spoken_languages'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        skillOptions = ProfileDropdownOptions([
          ...reference.skills,
          ...reference.jobCategories,
          ...skills,
        ], null).items;
        languageOptions = ProfileDropdownOptions([
          ...reference.spokenLanguages,
          ...languages,
        ], null).items;
        skills = skills
            .map(
              (value) => ProfileDropdownOptions(skillOptions, value).selected!,
            )
            .toSet()
            .toList();
        languages = languages
            .map(
              (value) =>
                  ProfileDropdownOptions(languageOptions, value).selected!,
            )
            .toSet()
            .toList();
        available = data['available'] == true;
        final educationChoices = ProfileDropdownOptions(
          reference.educationLevels.isEmpty
              ? educationOptions
              : reference.educationLevels,
          data['education']?.toString(),
        );
        final cityChoices = ProfileDropdownOptions(
          loadedCities,
          data['city']?.toString(),
        );
        educationOptions = educationChoices.items;
        education = educationChoices.selected;
        state = selectedState;
        states = stateOptions.items;
        city = cityChoices.selected;
        cities = cityChoices.items;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => loadError = error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editOptions(bool isSkills) async {
    final result = await showProfileOptionsPicker(
      context,
      title: isSkills ? 'Skills' : 'Languages you speak',
      options: isSkills ? skillOptions : languageOptions,
      selected: isSkills ? skills : languages,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isSkills) {
        skills = result;
      } else {
        languages = result;
      }
    });
  }

  Future<void> _selectState(String value) async {
    final request = ++cityRequest;
    setState(() {
      state = value;
      city = null;
      cities = [];
      loadingCities = true;
      latitude = null;
      longitude = null;
    });
    try {
      final result = await service.cities(value);
      if (mounted && request == cityRequest) {
        setState(() => cities = ProfileDropdownOptions(result, null).items);
      }
    } on ApiException catch (error) {
      if (mounted && request == cityRequest) _error(error.message);
    } finally {
      if (mounted && request == cityRequest)
        setState(() => loadingCities = false);
    }
  }

  Future<void> _save() async {
    if (saving || loadingCities || loading || loadError != null) return;
    setState(() => saving = true);
    try {
      final values = <String, dynamic>{
        'address': address.text.trim(),
        'name': name.text.trim(),
        if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
        'skills': skills,
        'experience_years': int.tryParse(experience.text) ?? 0,
        'education': education,
        'spoken_languages': languages,
        'bio': bio.text.trim(),
        'expected_wage': num.tryParse(wage.text),
        'wage_type': 'monthly',
        'state': state,
        'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'travel_radius_km': travelRadiusKm,
        'available': available,
        'payout_upi': upi.text.trim(),
      }..removeWhere((key, value) => value == null);
      await service.updateProfile(values);
      unawaited(MetaEventsService.instance.profileUpdated());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Profile updated successfully.')),
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
      final picked = await pickAppImage(
        context,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;
      final file = File(picked.path);
      if (await file.length() > 2 * 1024 * 1024) {
        _error('Avatar image must be 2 MB or smaller.');
        return;
      }
      setState(() => uploadingAvatar = true);
      final uploadedUrl = await service.uploadAvatar(file);
      if (!mounted) return;
      setState(() => avatarUrl = uploadedUrl);
      profileAvatarUrl.value = uploadedUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Profile photo updated.')),
      );
    } on ApiException catch (error) {
      if (mounted) _error(error.message);
    } on MissingPluginException catch (error) {
      debugPrint('[AVATAR PICKER] Missing plugin: $error');
      if (mounted) {
        _error(
          'Photo picker is not initialized. Stop the app and run it again.',
        );
      }
    } on PlatformException catch (error) {
      debugPrint('[AVATAR PICKER] ${error.code}: ${error.message}');
      if (mounted) {
        final denied =
            error.code.toLowerCase().contains('permission') ||
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
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _error('Location permission is required to pin your location.');
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (places.isNotEmpty) {
        final place = places.first;
        final detectedState = ProfileDropdownOptions(
          states,
          place.administrativeArea,
        );
        final detectedCity =
            (place.locality?.trim().isNotEmpty == true
                    ? place.locality
                    : place.subAdministrativeArea)
                ?.trim();
        if (detectedState.selected != null) {
          await _selectState(detectedState.selected!);
          if (!mounted) return;
          states = detectedState.items;
        }
        if (detectedCity?.isNotEmpty == true) {
          cities = ProfileDropdownOptions(cities, detectedCity).items;
          city = ProfileDropdownOptions(cities, detectedCity).selected;
        }
        address.text = [place.street, place.subLocality, place.postalCode]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .join(', ');
      }
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Location pinned successfully. Save profile to update it.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _error('Unable to get your current location. Please try again.');
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: AppText(message)));

  @override
  void dispose() {
    for (final item in [
      name,
      email,
      phone,
      experience,
      bio,
      wage,
      upi,
      address,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(LucideIcons.arrowLeft),
      ),
      title: const AppText('Edit Profile', style: TextStyle(fontSize: 16)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : loadError != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText(loadError!),
                TextButton(onPressed: _load, child: const AppText('Try again')),
              ],
            ),
          )
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
                        backgroundImage:
                            avatarUrl != null && avatarUrl!.isNotEmpty
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: uploadingAvatar
                            ? const CircularProgressIndicator()
                            : avatarUrl == null || avatarUrl!.isEmpty
                            ? AppText(
                                name.text.trim().isEmpty
                                    ? 'W'
                                    : name.text
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .take(2)
                                          .map((e) => e[0])
                                          .join()
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFC93A06),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      const Positioned(
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
                ),
              ),
              const SizedBox(height: 8),
              const AppText(
                'Tap to change photo',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              const FieldLabel('Full name'),
              TextField(controller: name),
              const SizedBox(height: 14),
              const FieldLabel('Email'),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.tr('you@example.com'),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Mobile number'),
              TextField(controller: phone, enabled: false),
              const SizedBox(height: 14),
              const FieldLabel('Skills'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map(
                      (value) => InputChip(
                        label: AppText(value),
                        onDeleted: () => setState(() => skills.remove(value)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('edit-skills'),
                onPressed: () => _editOptions(true),
                icon: const Icon(LucideIcons.pencil),
                label: const AppText('Edit skills'),
              ),
              const FieldLabel('Experience'),
              TextField(
                controller: experience,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(suffixText: context.tr('years')),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const AppText('Available for work'),
                value: available,
                activeTrackColor: brand,
                onChanged: (value) => setState(() => available = value),
              ),
              const FieldLabel('Languages you speak'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: languages
                    .map(
                      (value) => InputChip(
                        label: AppText(value),
                        onDeleted: () =>
                            setState(() => languages.remove(value)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const ValueKey('edit-languages'),
                onPressed: () => _editOptions(false),
                icon: const Icon(LucideIcons.pencil),
                label: const AppText('Edit languages'),
              ),
              const FieldLabel('Education'),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: education,
                items: educationOptions
                    .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
                    .toList(),
                onChanged: (value) => setState(() => education = value),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Bio'),
              TextField(controller: bio, maxLines: 4),
              const SizedBox(height: 14),
              const FieldLabel('Expected salary per month'),
              TextField(
                controller: wage,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  suffixText: context.tr('/month'),
                ),
              ),
              const SizedBox(height: 14),
              const SectionTitle('Location'),
              const FieldLabel('Full address'),
              TextField(
                key: const ValueKey('profile-address'),
                controller: address,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.streetAddress,
                decoration: InputDecoration(
                  hintText: context.tr(
                    'House, street, area, landmark and PIN code',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('State'),
              SizedBox(
                key: const ValueKey('edit-state'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(state),
                  isExpanded: true,
                  menuMaxHeight: 420,
                  initialValue: state,
                  hint: const AppText('Select state'),
                  items: states
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: locating
                      ? null
                      : (value) {
                          if (value != null && value != state) {
                            _selectState(value);
                          }
                        },
                ),
              ),
              const SizedBox(height: 12),
              const FieldLabel('City / District'),
              SizedBox(
                key: const ValueKey('edit-city'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey((state, city)),
                  isExpanded: true,
                  menuMaxHeight: 420,
                  initialValue: city,
                  hint: AppText(
                    state == null
                        ? 'Select state first'
                        : loadingCities
                        ? 'Loading cities...'
                        : 'Select city',
                  ),
                  items: cities
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: state == null || loadingCities || locating
                      ? null
                      : (value) {
                          setState(() {
                            city = value;
                            latitude = null;
                            longitude = null;
                          });
                        },
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://github.com/dr5hn/countries-states-cities-database',
                    ),
                  ),
                  child: const Text(
                    'City data: CSC · ODbL',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Pin your location'),
              MapBox(
                onTap: locating ? null : _pinCurrentLocation,
                latitude: latitude,
                longitude: longitude,
                address: [address.text, city, state]
                    .whereType<String>()
                    .where((value) => value.trim().isNotEmpty)
                    .join(', '),
                onLocationChanged: (position) => setState(() {
                  latitude = position.latitude;
                  longitude = position.longitude;
                }),
                label: locating
                    ? 'Detecting location...'
                    : latitude == null || longitude == null
                    ? 'Tap to use current location'
                    : '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 6),
              AppText(
                latitude == null
                    ? 'Tap the map to pin your exact location.'
                    : 'Pinned coordinates will be used to match nearby jobs.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Travel radius'),
              Wrap(
                spacing: 8,
                children:
                    [
                          (5, '5 km'),
                          (15, '15 km'),
                          (20, '20 km'),
                          (25, '25 km'),
                          (30, '30 km'),
                          (35, '35 km'),
                          (40, '40 km'),
                          (100, 'Anywhere'),
                        ]
                        .map(
                          (item) => ChoiceChip(
                            label: AppText(item.$2),
                            selected: travelRadiusKm == item.$1,
                            onSelected: (_) =>
                                setState(() => travelRadiusKm = item.$1),
                          ),
                        )
                        .toList(),
              ),
              // const SectionTitle('Payout'),
              // const FieldLabel('UPI ID'),
              // TextField(
              //   controller: upi,
              //   decoration: InputDecoration(
              //     prefixIcon: Icon(LucideIcons.indianRupee, size: 18),
              //   ),
              // ),
              const SizedBox(height: 20),
              PrimaryButton(
                'Save Profile',
                isLoading: saving,
                onPressed: _save,
              ),
            ],
          ),
  );
}

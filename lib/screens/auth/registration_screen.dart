part of '../../main.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  int step = 0;
  String? gender;
  String? selectedState;
  String? selectedCity;
  List<String> states = [];
  List<String> cities = [];
  bool loadingStates = false;
  bool loadingCities = false;
  bool locating = false;
  double? latitude;
  double? longitude;
  final workerApi = WorkerApiService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final experienceController = TextEditingController();
  final wageController = TextEditingController();
  final panController = TextEditingController();
  final aadhaarController = TextEditingController();
  File? panDoc, aadhaarDoc;
  int travelRadiusKm = 15;
  bool submitting = false;
  String education = '10th Pass';
  final selectedLanguages = <String>{'Tamil', 'Hindi'};
  final selectedSkills = <String>{};
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
  void initState() {
    super.initState();
    _loadStates();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    experienceController.dispose();
    wageController.dispose();
    panController.dispose();
    aadhaarController.dispose();
    super.dispose();
  }

  Future<void> _pickKycDocument(bool isPan) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final file = File(picked.path);
    if (await file.length() > 4 * 1024 * 1024) {
      _showError('Document must be 4 MB or smaller.');
      return;
    }
    if (mounted) setState(() => isPan ? panDoc = file : aadhaarDoc = file);
  }

  Future<void> _loadStates() async {
    setState(() => loadingStates = true);
    try {
      final reference = await workerApi.reference();
      if (mounted) setState(() => states = reference.states);
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => loadingStates = false);
    }
  }

  Future<void> _loadCities(String state) async {
    setState(() {
      selectedState = state;
      selectedCity = null;
      cities = [];
      loadingCities = true;
    });
    try {
      final result = await workerApi.cities(state);
      if (mounted && selectedState == state) {
        setState(() => cities = result);
      }
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted && selectedState == state) {
        setState(() => loadingCities = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showError('Please turn on device location.');
        await Geolocator.openLocationSettings();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission is required to detect your city.');
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
      if (places.isEmpty) throw Exception('Address not found');
      final place = places.first;
      final detectedState = place.administrativeArea?.trim();
      final detectedCity = (place.locality?.trim().isNotEmpty == true
              ? place.locality
              : place.subAdministrativeArea)
          ?.trim();
      final matchingState = states.cast<String?>().firstWhere(
        (item) => item!.toLowerCase() == detectedState?.toLowerCase(),
        orElse: () => null,
      );
      if (matchingState == null) {
        _showError('Could not match your detected state. Please select it manually.');
        return;
      }
      final allCities = await workerApi.cities(matchingState);
      final matchingCity = allCities.cast<String?>().firstWhere(
        (item) => item!.toLowerCase() == detectedCity?.toLowerCase(),
        orElse: () => null,
      );
      if (!mounted) return;
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        selectedState = matchingState;
        cities = allCities;
        selectedCity = matchingCity;
      });
      if (matchingCity == null) {
        _showError('State detected. Please select the nearest city.');
      }
    } catch (_) {
      if (mounted) _showError('Unable to detect location. Please try again.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
                  onPressed: submitting ? null : _finish,
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: step == 5 ? 2 : 1,
              child: PrimaryButton(
                step == 5 ? 'Finish setup' : 'Continue',
                isLoading: step == 5 && submitting,
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

  Future<void> _finish() async {
    if (submitting) return;
    final missing = <String>[
      if (nameController.text.trim().isEmpty) 'name',
      if (gender == null) 'gender',
      if (selectedState == null) 'state',
      if (selectedCity == null) 'city',
      if (selectedLanguages.isEmpty) 'language',
      if (selectedSkills.isEmpty) 'skill/category',
    ];
    if (missing.isNotEmpty) {
      _showError('Please select: ${missing.join(', ')}.');
      return;
    }
    setState(() => submitting = true);
    try {
      await workerApi.updateProfile({
        'name': nameController.text.trim(),
        if (emailController.text.trim().isNotEmpty)
          'email': emailController.text.trim(),
        'gender': gender!.toLowerCase(),
        'state': selectedState,
        'city': selectedCity,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'travel_radius_km': travelRadiusKm,
        'spoken_languages': selectedLanguages.toList(),
        'education': education,
        'skills': selectedSkills.toList(),
        'experience_years': int.tryParse(experienceController.text) ?? 0,
        if (num.tryParse(wageController.text) != null)
          'expected_wage': num.parse(wageController.text),
        'wage_type': 'daily',
        'available': true,
      });
      final pan = panController.text.trim().toUpperCase();
      final aadhaar = aadhaarController.text.replaceAll(RegExp(r'\D'), '');
      final hasAnyKyc = pan.isNotEmpty || aadhaar.isNotEmpty || panDoc != null || aadhaarDoc != null;
      if (hasAnyKyc) {
        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan) ||
            aadhaar.length != 12 || panDoc == null || aadhaarDoc == null) {
          throw ApiException('Complete all KYC fields or use Skip for now.', statusCode: 422);
        }
        await workerApi.submitKyc(pan: pan, aadhaar: aadhaar, panDoc: panDoc!, aadhaarDoc: aadhaarDoc!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile created successfully. You can submit KYC from your profile.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on ApiException catch (error) {
      if (mounted) _showError(error.message);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

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
        TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: 'e.g. Rakesh Kumar'),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Email (optional)'),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'you@example.com', helperText: 'Get job & application updates by email.'),
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
          onPressed: locating ? null : _useCurrentLocation,
          icon: const Icon(LucideIcons.locateFixed),
          label: Text(locating ? 'Detecting location...' : 'Use my current location'),
        ),
        const SizedBox(height: 16),
        const FieldLabel('State'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          menuMaxHeight: 420,
          initialValue: selectedState,
          hint: Text(loadingStates ? 'Loading states...' : 'Select state'),
          items: states
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: loadingStates
              ? null
              : (value) {
                  if (value != null) _loadCities(value);
                },
        ),
        const SizedBox(height: 14),
        const FieldLabel('City / District'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          menuMaxHeight: 420,
          key: ValueKey(selectedState),
          initialValue: selectedCity,
          hint: Text(
            selectedState == null
                ? 'Select state first'
                : loadingCities
                ? 'Loading cities...'
                : 'Select city',
          ),
          items: cities
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: selectedState == null || loadingCities
              ? null
              : (value) => setState(() => selectedCity = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('How far can you travel?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [(5, 'Within 5 km'), (15, 'Within 15 km'), (100, 'Anywhere')]
              .map((item) => ChoiceChip(
                    label: Text(item.$2),
                    selected: travelRadiusKm == item.$1,
                    onSelected: (_) => setState(() => travelRadiusKm = item.$1),
                  ))
              .toList(),
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
                  selected: selectedLanguages.contains(e),
                  onSelected: (v) =>
                      setState(() => v ? selectedLanguages.add(e) : selectedLanguages.remove(e)),
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
          onChanged: (value) {
            if (value != null) {
              setState(() => selectedSkills.add(value));
            }
          },
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
                  selected: selectedSkills.contains(e),
                  onSelected: (v) =>
                      setState(() => v ? selectedSkills.add(e) : selectedSkills.remove(e)),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Experience'),
                  TextField(
                    controller: experienceController,
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
                    controller: wageController,
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
        TextField(
          controller: aadhaarController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          decoration: InputDecoration(hintText: '1234 5678 9012'),
        ),
        const SizedBox(height: 14),
        const FieldLabel('PAN number'),
        TextField(
          controller: panController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(10)],
          decoration: const InputDecoration(hintText: 'ABCDE1234F'),
        ),
        const SizedBox(height: 14),
        UploadTile(
          'Upload Aadhaar & PAN photo\nJPG / PNG / PDF · max 5MB each',
          LucideIcons.upload,
          dashed: true,
          onTap: () => _pickKycDocument(false),
        ),
        const SizedBox(height: 10),
        UploadTile(
          panDoc == null
              ? 'Upload PAN photo\nJPG / PNG · max 4MB'
              : panDoc!.path.split(Platform.pathSeparator).last,
          LucideIcons.upload,
          dashed: true,
          onTap: () => _pickKycDocument(true),
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

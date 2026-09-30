part of '../../main.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, this.api});
  final WorkerApiService? api;
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
  late final workerApi = widget.api ?? WorkerApiService();
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
  List<String> skills = [];
  List<String> categories = [];
  List<String> languages = [];
  String? selectedCategory;
  String? referenceError;
  String? citiesError;
  int cityRequest = 0;

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
    final picked = await pickAppImage(context, imageQuality: 90);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (await file.length() > 4 * 1024 * 1024) {
      _showError('Document must be 4 MB or smaller.');
      return;
    }
    if (mounted) setState(() => isPan ? panDoc = file : aadhaarDoc = file);
  }

  Future<void> _loadStates() async {
    setState(() {
      loadingStates = true;
      referenceError = null;
    });
    try {
      final reference = await workerApi.reference();
      if (mounted) {
        setState(() {
          states = reference.states.toSet().toList();
          skills = reference.skills.toSet().toList();
          categories = reference.jobCategories.toSet().toList();
          languages = reference.spokenLanguages.toSet().toList();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => referenceError = error.message);
    } finally {
      if (mounted) setState(() => loadingStates = false);
    }
  }

  Future<void> _loadCities(String state) async {
    final request = ++cityRequest;
    setState(() {
      selectedState = state;
      selectedCity = null;
      cities = [];
      loadingCities = true;
      citiesError = null;
      latitude = null;
      longitude = null;
    });
    try {
      final result = await workerApi.cities(state);
      if (mounted && request == cityRequest) {
        setState(() => cities = result.toSet().toList());
      }
    } on ApiException catch (error) {
      if (mounted && request == cityRequest) {
        setState(() => citiesError = error.message);
      }
    } finally {
      if (mounted && request == cityRequest) {
        setState(() => loadingCities = false);
      }
    }
  }

  Future<void> _enterCity() async {
    final state = selectedState;
    var enteredCity = '';
    final city = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(
          context.trArgs('City in {state}', {'state': state ?? ''}),
        ),
        content: TextField(
          onChanged: (value) => enteredCity = value,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.tr('City / District')),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (enteredCity.trim().isNotEmpty) {
                Navigator.pop(context, enteredCity.trim());
              }
            },
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    if (!mounted || city == null || selectedState != state) return;
    setState(() {
      if (!cities.contains(city)) cities = [...cities, city];
      selectedCity = city;
    });
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
      final detectedCity =
          (place.locality?.trim().isNotEmpty == true
                  ? place.locality
                  : place.subAdministrativeArea)
              ?.trim();
      final matchingState = states.cast<String?>().firstWhere(
        (item) => item!.toLowerCase() == detectedState?.toLowerCase(),
        orElse: () => null,
      );
      if (matchingState == null) {
        _showError(
          'Could not match your detected state. Please select it manually.',
        );
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
        cityRequest++;
        loadingCities = false;
        citiesError = null;
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
      ..showSnackBar(SnackBar(content: AppText(message)));
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
      title: const AppText(
        'Set up your profile',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: AppText(
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
                  onPressed: submitting ? null : () => _finish(skipKyc: true),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const AppText('Skip for now'),
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

  Future<void> _finish({bool skipKyc = false}) async {
    if (submitting) return;
    final missing = <String>[
      if (nameController.text.trim().isEmpty) 'name',
      if (gender == null) 'gender',
      if (selectedState == null) 'state',
      if (selectedCity == null) 'city',
      if (selectedLanguages.isEmpty) 'language',
      if (selectedSkills.isEmpty && selectedCategory == null) 'skill/category',
    ];
    if (missing.isNotEmpty) {
      _showError(
        context.trArgs('Please select: {fields}.', {
          'fields': missing.map(context.tr).join(', '),
        }),
      );
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
        'skills': {...selectedSkills, ?selectedCategory}.toList(),
        'experience_years': int.tryParse(experienceController.text) ?? 0,
        if (num.tryParse(wageController.text) != null)
          'expected_wage': num.parse(wageController.text),
        'wage_type': 'monthly',
        'available': true,
      });
      final pan = panController.text.trim().toUpperCase();
      final aadhaar = aadhaarController.text.replaceAll(RegExp(r'\D'), '');
      final hasAnyKyc =
          pan.isNotEmpty ||
          aadhaar.isNotEmpty ||
          panDoc != null ||
          aadhaarDoc != null;
      if (hasAnyKyc && !skipKyc) {
        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan) ||
            aadhaar.length != 12 ||
            panDoc == null ||
            aadhaarDoc == null) {
          throw ApiException(
            'Complete all KYC fields or use Skip for now.',
            statusCode: 422,
          );
        }
        await workerApi.submitKyc(
          pan: pan,
          aadhaar: aadhaar,
          panDoc: panDoc!,
          aadhaarDoc: aadhaarDoc!,
        );
      }
      unawaited(MetaEventsService.instance.registrationCompleted());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Profile created successfully. You can submit KYC from your profile.',
          ),
        ),
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
            child: AppText(
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
      AppText(subs[step], style: const TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 22),
    ];
    if (step == 0) {
      out.addAll([
        const FieldLabel('Full name'),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: context.tr('e.g. Rakesh Kumar'),
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Email (optional)'),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: context.tr('you@example.com'),
            helperText: context.tr('Get job & application updates by email.'),
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Gender'),
        Wrap(
          spacing: 8,
          children: ['Male', 'Female', 'Other']
              .map(
                (e) => ChoiceChip(
                  label: AppText(e),
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
          label: AppText(
            locating ? 'Detecting location...' : 'Use my current location',
          ),
        ),
        const SizedBox(height: 16),
        if (referenceError != null)
          TextButton(
            onPressed: _loadStates,
            child: const AppText('Could not load options. Tap to retry'),
          ),
        const FieldLabel('State'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          menuMaxHeight: 420,
          key: ValueKey(selectedState),
          initialValue: selectedState,
          hint: AppText(loadingStates ? 'Loading states...' : 'Select state'),
          items: states
              .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
              .toList(),
          onChanged: loadingStates || locating
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
          key: ValueKey((selectedState, selectedCity)),
          initialValue: cities.contains(selectedCity) ? selectedCity : null,
          hint: AppText(
            selectedState == null
                ? 'Select state first'
                : loadingCities
                ? 'Loading cities...'
                : selectedCity ?? 'Select city',
          ),
          items: cities
              .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
              .toList(),
          onChanged: selectedState == null || loadingCities || locating
              ? null
              : (value) => setState(() => selectedCity = value),
        ),
        const SizedBox(height: 14),
        if (citiesError != null)
          TextButton(
            onPressed: () => _loadCities(selectedState!),
            child: const AppText('Could not load cities. Tap to retry'),
          ),
        TextButton(
          onPressed: selectedState == null || loadingCities || locating
              ? null
              : _enterCity,
          child: const AppText('City not listed? Enter your city'),
        ),
        const FieldLabel('Pin your exact location'),
        MapBox(
          onTap: locating ? null : _useCurrentLocation,
          latitude: latitude,
          longitude: longitude,
          address: [selectedCity, selectedState].whereType<String>().join(', '),
          onLocationChanged: (position) => setState(() {
            latitude = position.latitude;
            longitude = position.longitude;
          }),
          label: latitude == null
              ? 'Tap map or use current location'
              : '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
        ),
        const SizedBox(height: 14),
        const FieldLabel('How far can you travel?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              [(5, 'Within 5 km'), (15, 'Within 15 km'), (100, 'Anywhere')]
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
                  label: AppText(e),
                  selected: selectedLanguages.contains(e),
                  onSelected: (v) => setState(
                    () => v
                        ? selectedLanguages.add(e)
                        : selectedLanguages.remove(e),
                  ),
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
                    AppText(
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
        if (loadingStates) const LinearProgressIndicator(),
        if (referenceError != null || (!loadingStates && skills.isEmpty))
          TextButton(
            onPressed: _loadStates,
            child: const AppText('Reload skills and categories'),
          ),
        const FieldLabel('Main job category'),
        DropdownButtonFormField<String>(
          isExpanded: true,
          menuMaxHeight: 420,
          initialValue: selectedCategory,
          hint: const AppText('Select category'),
          items: categories
              .map((e) => DropdownMenuItem(value: e, child: AppText(e)))
              .toList(),
          onChanged: loadingStates
              ? null
              : (value) => setState(() => selectedCategory = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Your skills'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: skills
              .map(
                (e) => FilterChip(
                  label: AppText(e),
                  selected: selectedSkills.contains(e),
                  onSelected: (v) => setState(
                    () => v ? selectedSkills.add(e) : selectedSkills.remove(e),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        const AppText(
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
                      hintText: context.tr('0'),
                      suffixText: context.tr('years'),
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
                  FieldLabel('Expected salary per month'),
                  TextField(
                    controller: wageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      hintText: '18000',
                      suffixText: context.tr('/month'),
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
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(hintText: context.tr('1234 5678 9012')),
        ),
        const SizedBox(height: 14),
        const FieldLabel('PAN number'),
        TextField(
          controller: panController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(hintText: context.tr('ABCDE1234F')),
        ),
        const SizedBox(height: 14),
        UploadTile(
          aadhaarDoc == null
              ? 'Upload Aadhaar photo\nJPG / PNG · max 4MB'
              : aadhaarDoc!.path.split(Platform.pathSeparator).last,
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
              child: AppText(
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

part of '../main.dart';

/// "923" for far jobs, "2.5" under 10 km: "923.0 km" read like a typo.
String formatKm(double km) {
  if (km < 10) {
    final short = km.toStringAsFixed(1);
    return short.endsWith('.0') ? short.substring(0, short.length - 2) : short;
  }
  final whole = km.round().toString();
  return whole.length > 3
      ? '${whole.substring(0, whole.length - 3)},${whole.substring(whole.length - 3)}'
      : whole;
}

class SimpleFormPage extends StatelessWidget {
  const SimpleFormPage({
    super.key,
    required this.title,
    required this.children,
    required this.button,
  });
  final String title, button;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: AppText(title, style: const TextStyle(fontSize: 16))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...children,
        const SizedBox(height: 24),
        PrimaryButton(button, onPressed: () => Navigator.pop(context)),
      ],
    ),
  );
}

/// A compact selector whose search box lives inside the opened options list.
class SearchableOptionField extends StatefulWidget {
  const SearchableOptionField({
    super.key,
    required this.title,
    required this.options,
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  State<SearchableOptionField> createState() => _SearchableOptionFieldState();
}

class _SearchableOptionFieldState extends State<SearchableOptionField> {
  String query = '';
  OverlayEntry? _overlay;

  void _closeMenu() {
    _overlay?.remove();
    _overlay = null;
  }

  void _openMenu(BuildContext context) {
    if (_overlay != null) {
      _closeMenu();
      return;
    }
    final box = context.findRenderObject()! as RenderBox;
    final top = box.localToGlobal(Offset.zero).dy;
    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final keyboardInset = MediaQuery.viewInsetsOf(overlayContext).bottom;
        // A field low on the screen (State, City at the bottom of the
        // filter sheet) left room for one row, or none: start the list no
        // lower than 40% down, so most of the screen shows options.
        final highestStart = MediaQuery.sizeOf(overlayContext).height * 0.4;
        final listTop = keyboardInset > 0
            ? MediaQuery.paddingOf(overlayContext).top + 8
            : (top > highestStart ? highestStart : top);
        final results = widget.options
            .where((value) => value.toLowerCase().contains(query.toLowerCase()))
            .toList();
        return Stack(
          children: [
            ModalBarrier(
              color: Colors.black54,
              dismissible: true,
              onDismiss: _closeMenu,
            ),
            Positioned(
              left: 0,
              right: 0,
              top: listTop,
              bottom: keyboardInset,
              child: Material(
                color: overlayContext.surfaceColor,
                elevation: 8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          prefixIcon: Icon(LucideIcons.search, size: 19),
                        ),
                        onChanged: (value) {
                          query = value.trim();
                          _overlay?.markNeedsBuild();
                        },
                      ),
                    ),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: AppText('No matching options'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: results.length,
                              itemBuilder: (_, index) {
                                final value = results[index];
                                return InkWell(
                                  onTap: () {
                                    widget.onChanged(value);
                                    _closeMenu();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 34,
                                      vertical: 17,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AppText(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (value == widget.value)
                                          const Icon(Icons.check, color: brand),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openMenu(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: AppText(
          widget.value ?? widget.hint,
          style: TextStyle(color: widget.value == null ? muted : null),
        ),
      ),
    );
  }
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Filter jobs',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Category'),
        DropdownButtonFormField<String>(
          initialValue: 'All categories',
          items: [
            'All categories',
            'Plumbing',
            'Electrical',
            'Carpentry',
            'Painting',
            'Masonry',
          ].map((e) => DropdownMenuItem(value: e, child: AppText(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('Skill'),
        TextField(
          decoration: InputDecoration(
            hintText: context.tr('e.g. Waterproofing'),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('State'),
                  DropdownButtonFormField<String>(
                    initialValue: 'Tamil Nadu',
                    items: ['Tamil Nadu', 'Kerala', 'Karnataka']
                        .map(
                          (e) => DropdownMenuItem(value: e, child: AppText(e)),
                        )
                        .toList(),
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('City'),
                  DropdownButtonFormField<String>(
                    initialValue: 'Chennai',
                    items: ['Chennai', 'Coimbatore']
                        .map(
                          (e) => DropdownMenuItem(value: e, child: AppText(e)),
                        )
                        .toList(),
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Reset'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const AppText('Apply'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ApplySheet extends StatefulWidget {
  const ApplySheet({
    super.key,
    required this.onApply,
    this.initialWage = '',
    this.initialNote = '',
    this.jobTitle,
    this.onDraftChanged,
  });
  final Future<void> Function(String? coverNote, num? expectedWage) onApply;
  final String initialWage, initialNote;
  final String? jobTitle;
  final void Function(String wage, String note)? onDraftChanged;
  @override
  State<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<ApplySheet> {
  late final wage = TextEditingController(text: widget.initialWage);
  late final note = TextEditingController(text: widget.initialNote);
  bool submitting = false;

  /// The karigar's resume, if any: the link said "Add a resume" even to
  /// karigars who had one.
  ResumeModel? _resume;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    try {
      final resume = await WorkerApiService().fetchResume();
      if (mounted) setState(() => _resume = resume);
    } catch (_) {
      // The link still works; it just keeps its "Add" wording.
    }
  }

  void _saveDraft() => widget.onDraftChanged?.call(wage.text, note.text);

  @override
  void dispose() {
    wage.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (submitting) return;
    setState(() => submitting = true);
    await widget.onApply(
      note.text.trim().isEmpty ? null : note.text.trim(),
      num.tryParse(wage.text.trim()),
    );
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 30,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          widget.jobTitle?.trim().isNotEmpty == true
              ? 'Apply for ${widget.jobTitle}'
              : 'Apply for this job',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const AppText(
          'The employer will see your profile, skills and rating.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Expected salary per month (optional)'),
        TextField(
          controller: wage,
          onChanged: (_) => _saveDraft(),
          keyboardType: TextInputType.number,
          // Digits only: pasted text used to land here ("00Test…").
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(7),
          ],
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '18000',
            suffixText: context.tr('/month'),
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Message to employer (optional)'),
        TextField(
          controller: note,
          onChanged: (_) => _saveDraft(),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.tr("I'm available from tomorrow…"),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: submitting
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ResumePage()),
                  );
                  _loadResume();
                },
          icon: Icon(
            _resume == null ? LucideIcons.fileUp : LucideIcons.fileCheck,
            size: 18,
          ),
          label: AppText(
            _resume == null
                ? 'Add a resume to improve your match'
                : 'Your resume is attached · Change',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                color: Color(0xFFB45309),
                size: 18,
              ),
              SizedBox(width: 9),
              Expanded(
                child: AppText(
                  'Super Karigar never charges you to work. Report any employer who asks for an advance fee.',
                  style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          'Submit Application',
          isLoading: submitting,
          onPressed: _submit,
        ),
      ],
    ),
  );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: context.surfaceColor,
      border: Border.all(color: context.borderColor),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D101828),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.text, {
    super.key,
    required this.onPressed,
    this.height = 50,
    this.isLoading = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final double height;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    onPressed: isLoading ? null : onPressed,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: isLoading
          ? const AppText('Please wait…', key: ValueKey('loader'))
          : AppText(
              text,
              key: const ValueKey('label'),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: AppText(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: context.isDark ? const Color(0xFF30221D) : const Color(0xFFFFF3EE),
      border: Border.all(
        color: context.isDark
            ? const Color(0xFF68402F)
            : const Color(0xFFFFE3D8),
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      text,
      style: TextStyle(
        color: context.isDark
            ? const Color(0xFFFF8A62)
            : const Color(0xFFC93A06),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, this.background, this.foreground, {super.key});
  final String text;
  final Color background, foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: context.isDark
          ? Color.alphaBlend(
              background.withValues(alpha: .18),
              context.surfaceColor,
            )
          : background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: AppText(
      text,
      style: TextStyle(
        color: context.isDark
            ? Color.lerp(foreground, Colors.white, .38)!
            : foreground,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class Meta extends StatelessWidget {
  const Meta(this.icon, this.text, {super.key, this.bold = false});
  final IconData icon;
  final String text;
  final bool bold;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: muted),
      const SizedBox(width: 4),
      Flexible(
        child: AppText(
          text,
          softWrap: true,
          style: TextStyle(
            color: bold ? context.foregroundColor : muted,
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ],
  );
}

class StatCard extends StatelessWidget {
  const StatCard(
    this.value,
    this.label,
    this.icon,
    this.bgColor,
    this.color, {
    super.key,
    this.compact = false,
    this.onTap,
  });
  final String value, label;
  final IconData icon;
  final Color bgColor, color;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.isDark
                  ? Color.alphaBlend(
                      bgColor.withValues(alpha: .16),
                      context.surfaceColor,
                    )
                  : bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          // Narrow tiles (three in a row, large system font) used to break
          // words in the middle: "Verifie/d", "Application/s".
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: AppText(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 19 : 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _WholeWordsText(
            context.tr(label),
            style: const TextStyle(
              color: muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// Wraps between words only: when the longest word is wider than the space,
/// the font shrinks until it fits instead of breaking the word.
class _WholeWordsText extends StatelessWidget {
  const _WholeWordsText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      // Measure in the font the Text will really use (the theme's Outfit).
      final base = DefaultTextStyle.of(context).style.merge(style);
      var widest = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: base),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
      var fitted = style;
      if (box.maxWidth.isFinite && widest > box.maxWidth && widest > 0) {
        fitted = style.copyWith(
          fontSize: (style.fontSize ?? 14) * box.maxWidth / widest * .98,
        );
      }
      // Always reserve two lines so tiles in a row come out the same height.
      final full = base.merge(fitted);
      final lines = TextPainter(
        text: TextSpan(text: text, style: full),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 3,
      )..layout(maxWidth: box.maxWidth.isFinite ? box.maxWidth : 1e6);
      final two = TextPainter(
        text: TextSpan(text: 'A\nA', style: full),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final height = lines.height > two.height ? lines.height : two.height;
      lines.dispose();
      two.dispose();
      return SizedBox(
        height: height,
        child: Text(text, maxLines: 3, style: fitted),
      );
    },
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.action, this.onTap});
  final String text;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: AppText(
          text,
          style: const TextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
      ),
      if (action != null) TextButton(onPressed: onTap, child: AppText(action!)),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: AppText(
      text.toUpperCase(),
      style: const TextStyle(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
  );
}

class MiniStat extends StatelessWidget {
  const MiniStat(this.label, this.value, {super.key, this.maxLines = 3});
  final String label, value;
  final int maxLines;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        AppText(
          value,
          maxLines: maxLines,
          softWrap: true,
          style: const TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class MapBox extends StatefulWidget {
  const MapBox({
    super.key,
    this.onTap,
    this.label,
    this.latitude,
    this.longitude,
    this.address,
    this.onLocationChanged,
  });
  final VoidCallback? onTap;
  final String? label;
  final double? latitude, longitude;
  final String? address;
  final ValueChanged<LatLng>? onLocationChanged;

  @override
  State<MapBox> createState() => _MapBoxState();
}

class _MapBoxState extends State<MapBox> {
  static const _india = LatLng(20.5937, 78.9629);
  late LatLng _position;
  final MapController _controller = MapController();
  double _zoom = 14;
  // Drags are ignored until the map is tapped once: a page scroll that
  // started on the map used to move the karigar's pin.
  bool _unlocked = false;
  Timer? _dragReport;

  @override
  void dispose() {
    _dragReport?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _position = _coordinates ?? _india;
    if (_coordinates == null && (widget.address?.trim().isNotEmpty ?? false)) {
      _geocodeAddress();
    }
  }

  @override
  void didUpdateWidget(covariant MapBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final coordinates = _coordinates;
    if (coordinates != null &&
        (coordinates.latitude != _position.latitude ||
            coordinates.longitude != _position.longitude)) {
      _position = coordinates;
      _controller.move(coordinates, 15);
    } else if (coordinates == null && oldWidget.address != widget.address) {
      _geocodeAddress();
    }
  }

  LatLng? get _coordinates =>
      widget.latitude == null || widget.longitude == null
      ? null
      : LatLng(widget.latitude!, widget.longitude!);

  Future<void> _geocodeAddress() async {
    try {
      final matches = await locationFromAddress(widget.address!);
      if (matches.isNotEmpty && mounted) {
        final position = LatLng(
          matches.first.latitude,
          matches.first.longitude,
        );
        setState(() {
          _position = position;
        });
        _controller.move(position, 13);
      }
    } catch (_) {
      // Keep the India overview when an address cannot be resolved.
    }
  }

  void _select(LatLng position) {
    if (widget.onLocationChanged == null) return;
    _dragReport?.cancel();
    setState(() {
      _position = position;
      _unlocked = true;
    });
    _controller.move(position, _zoom);
    widget.onLocationChanged!(position);
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      height: 150,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _position,
              initialZoom: _coordinates == null && widget.address == null
                  ? 4.2
                  : 14,
              minZoom: 3,
              maxZoom: 18,
              interactionOptions: InteractionOptions(
                flags: _unlocked || widget.onLocationChanged == null
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              onPositionChanged: (camera, hasGesture) {
                _zoom = camera.zoom;
                if (hasGesture &&
                    _unlocked &&
                    widget.onLocationChanged != null) {
                  _position = camera.center;
                  setState(() {});
                  // Report once the drag settles, not on every frame.
                  _dragReport?.cancel();
                  final center = camera.center;
                  _dragReport = Timer(
                    const Duration(milliseconds: 500),
                    () => widget.onLocationChanged?.call(center),
                  );
                }
              },
              onTap: (_, point) => _select(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.karigar_app',
                maxNativeZoom: 19,
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          const Center(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: 42),
                child: Icon(
                  Icons.location_pin,
                  size: 52,
                  color: brand,
                  shadows: [Shadow(color: Colors.white, blurRadius: 6)],
                ),
              ),
            ),
          ),
          if (widget.onTap != null)
            Positioned(
              right: 8,
              top: 8,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: widget.onTap,
                backgroundColor: context.surfaceColor,
                foregroundColor: brand,
                child: const Icon(LucideIcons.locateFixed),
              ),
            ),
          if (widget.label != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceColor.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText(
                  // Say how to move the pin while drags are switched off.
                  widget.onLocationChanged != null && !_unlocked
                      ? '${widget.label!} · ${context.tr('Tap the map to move the pin')}'
                      : widget.label!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class UploadTile extends StatelessWidget {
  const UploadTile(
    this.text,
    this.icon, {
    super.key,
    this.dashed = false,
    this.onTap,
  });
  final String text;
  final IconData icon;
  final bool dashed;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border.all(color: context.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: dashed
          ? Column(
              children: [
                Icon(icon, color: brand),
                const SizedBox(height: 6),
                AppText(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(icon, color: brand),
                const SizedBox(width: 12),
                Expanded(
                  child: AppText(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: muted),
              ],
            ),
    ),
  );
}

class ApplicationCard extends StatelessWidget {
  const ApplicationCard(
    this.title,
    this.employer,
    this.status,
    this.bgColor,
    this.color, {
    super.key,
  });
  final String title, employer, status;
  final Color bgColor, color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(status, bgColor, color),
            ],
          ),
          const SizedBox(height: 3),
          AppText(employer, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            children: [
              Meta(LucideIcons.mapPin, 'Chennai'),
              Meta(LucideIcons.indianRupee, '₹23,400/month', bold: true),
              Meta(LucideIcons.calendarDays, '10 Jul 2026'),
            ],
          ),
        ],
      ),
    ),
  );
}

class MenuRow extends StatelessWidget {
  const MenuRow(
    this.icon,
    this.title,
    this.subtitle,
    this.onTap, {
    super.key,
    this.trailing,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(bottom: BorderSide(color: context.borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.isDark
                  ? const Color(0xFF30221D)
                  : const Color(0xFFFFF3EE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFFC93A06), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  AppText(
                    subtitle,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          trailing ?? const Icon(LucideIcons.chevronRight, color: muted),
        ],
      ),
    ),
  );
}

class Review extends StatelessWidget {
  const Review(
    this.employer,
    this.text,
    this.date, {
    this.rating = 0,
    this.jobTitle,
    super.key,
  });
  final String employer, text, date;
  final int rating;
  final String? jobTitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  employer,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Semantics(
                label: '$rating out of 5 stars',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating.clamp(0, 5)
                          ? Icons.star
                          : Icons.star_border,
                      color: const Color(0xFFFBBF24),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (jobTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(jobTitle!, style: const TextStyle(color: muted, fontSize: 12)),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(height: 1.5, color: muted)),
          ],
          const SizedBox(height: 8),
          Text(date, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

class VerifiedEmployerBadge extends StatelessWidget {
  const VerifiedEmployerBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: context.isDark ? const Color(0xFF153A2C) : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.badgeCheck, size: 14, color: Color(0xFF059669)),
        const SizedBox(width: 4),
        Flexible(
          child: AppText(
            'Verified',
            style: TextStyle(
              fontSize: 11,
              color: context.isDark
                  ? const Color(0xFF6EE7B7)
                  : const Color(0xFF047857),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The last row of a paged list: shows a small spinner and asks for the next
/// page as soon as it is built (the worker has scrolled to the end).
class PageEndLoader extends StatefulWidget {
  const PageEndLoader({super.key, required this.onReached});
  final VoidCallback onReached;
  @override
  State<PageEndLoader> createState() => _PageEndLoaderState();
}

class _PageEndLoaderState extends State<PageEndLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReached();
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

/// Rupees the Indian way: ₹15,000, ₹1,50,000, ₹15,000.50.
String formatRupees(num amount) {
  final negative = amount < 0;
  final fixed = amount.abs().toStringAsFixed(2);
  var whole = fixed.split('.').first;
  final paise = fixed.split('.').last;
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  return '${negative ? '-' : ''}₹$whole${paise == '00' ? '' : '.$paise'}';
}

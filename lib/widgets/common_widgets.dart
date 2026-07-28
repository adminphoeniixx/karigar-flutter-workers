part of '../main.dart';

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
    appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 16))),
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

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (_) {},
        ),
        const SizedBox(height: 14),
        const FieldLabel('Skill'),
        const TextField(
          decoration: InputDecoration(hintText: 'e.g. Waterproofing'),
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
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
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
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class ApplySheet extends StatefulWidget {
  const ApplySheet({super.key, required this.onApply});
  final Future<void> Function(String? coverNote, num? expectedWage) onApply;
  @override
  State<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends State<ApplySheet> {
  final wage = TextEditingController();
  final note = TextEditingController();
  bool submitting = false;

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
  Widget build(BuildContext context) => Padding(
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
        const Text(
          'Apply for this job',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'The employer will see your profile, skills and rating.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Your expected wage (optional)'),
        TextField(
          controller: wage,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '₹ ',
            hintText: '900',
            suffixText: '/ day',
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Message to employer (optional)'),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: InputDecoration(hintText: "I'm available from tomorrow…"),
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
                child: Text(
                  'Karigar never charges you to work. Report any employer who asks for an advance fee.',
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
          ? const Text('Please wait…', key: ValueKey('loader'))
          : Text(text, key: const ValueKey('label')),
    ),
  );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
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
    child: Text(
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
    child: Text(
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
      Text(
        text,
        style: TextStyle(
          color: bold ? context.foregroundColor : muted,
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
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
  });
  final String value, label;
  final IconData icon;
  final Color bgColor, color;
  final bool compact;
  @override
  Widget build(BuildContext context) => AppCard(
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
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 19 : 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
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
        child: Text(
          text,
          style: const TextStyle(
            color: muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
      ),
      if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(
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
  const MiniStat(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    setState(() => _position = position);
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
              onPositionChanged: (camera, hasGesture) {
                _zoom = camera.zoom;
                if (hasGesture && widget.onLocationChanged != null) {
                  _position = camera.center;
                  widget.onLocationChanged!(camera.center);
                  setState(() {});
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
                child: Text(
                  widget.label!,
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
                Text(
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
                  child: Text(
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
                child: Text(
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
          Text(employer, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            children: [
              Meta(LucideIcons.mapPin, 'Chennai'),
              Meta(LucideIcons.indianRupee, '₹900/day', bold: true),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Text(
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
  const Review(this.employer, this.text, this.date, {super.key});
  final String employer, text, date;
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
              const Text('★★★★★', style: TextStyle(color: Color(0xFFFBBF24))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(height: 1.5, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 8),
          Text(date, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    ),
  );
}

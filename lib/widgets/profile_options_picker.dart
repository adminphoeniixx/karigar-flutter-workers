part of '../main.dart';

Future<List<String>?> showProfileOptionsPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  required List<String> selected,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) =>
      _ProfileOptionsPicker(title: title, options: options, selected: selected),
);

class _ProfileOptionsPicker extends StatefulWidget {
  const _ProfileOptionsPicker({
    required this.title,
    required this.options,
    required this.selected,
  });
  final String title;
  final List<String> options, selected;
  @override
  State<_ProfileOptionsPicker> createState() => _ProfileOptionsPickerState();
}

class _ProfileOptionsPickerState extends State<_ProfileOptionsPicker> {
  late final selected = widget.selected.toSet();
  String search = '';
  @override
  Widget build(BuildContext context) {
    final options = widget.options
        .where(
          (value) =>
              value.toLowerCase().contains(search) ||
              context.tr(value).toLowerCase().contains(search),
        )
        .toList();
    return AlertDialog(
      title: AppText(widget.title),
      content: SizedBox(
        width: 360,
        height: MediaQuery.sizeOf(context).height * .5,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: context.tr('Search')),
              onChanged: (value) =>
                  setState(() => search = value.trim().toLowerCase()),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (_, index) {
                  final value = options[index];
                  return CheckboxListTile(
                    title: AppText(value),
                    value: selected.contains(value),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? selected.add(value)
                          : selected.remove(value);
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const AppText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected.toList()),
          child: const AppText('Save'),
        ),
      ],
    );
  }
}

part of '../main.dart';

Future<ImageSource?> showImageSourceChooser(BuildContext context) =>
    showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const AppText('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const AppText('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              title: const AppText('Cancel'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );

Future<XFile?> pickAppImage(
  BuildContext context, {
  required int imageQuality,
  double? maxWidth,
}) async {
  final source = await showImageSourceChooser(context);
  if (source == null || !context.mounted) return null;
  try {
    return await ImagePicker().pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
    );
  } on PlatformException catch (error) {
    if (!context.mounted) return null;
    final denied =
        error.code.toLowerCase().contains('access') ||
        error.code.toLowerCase().contains('denied');
    final message = denied
        ? 'Allow camera or photo access in app settings to add a photo.'
        : 'Unable to open camera or gallery. Please try again.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message)));
    return null;
  } on MissingPluginException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Stop the app and run it again to initialize photo picker.',
          ),
        ),
      );
    }
    return null;
  }
}

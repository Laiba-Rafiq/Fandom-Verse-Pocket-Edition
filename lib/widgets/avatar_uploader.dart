import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/ui_helpers.dart';
import '../services/cloudinary_service.dart';
import 'user_avatar.dart';

class AvatarUploader extends StatefulWidget {
  const AvatarUploader({
    super.key,
    required this.initials,
    required this.onUploaded,
    this.imageUrl,
    this.radius = 52,
  });

  final String initials;
  final String? imageUrl;
  final double radius;
  final ValueChanged<String> onUploaded;

  @override
  State<AvatarUploader> createState() => _AvatarUploaderState();
}

class _AvatarUploaderState extends State<AvatarUploader> {
  bool _uploading = false;

  Future<void> _chooseAndUpload() async {
    final source = await _askSource();
    if (source == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final result = await CloudinaryService.instance.pickAndUpload(
        folder: CloudinaryFolders.avatars,
        source: source,
      );
      if (result != null) {
        widget.onUploaded(result.secureUrl);
      }
    } on CloudinaryException catch (e) {
      if (mounted) UiHelpers.showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not open the photo picker.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<ImageSource?> _askSource() {
    if (kIsWeb) return Future.value(ImageSource.gallery);

    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _uploading ? null : _chooseAndUpload,
      child: Stack(
        alignment: Alignment.center,
        children: [
          UserAvatar(
            initials: widget.initials,
            imageUrl: widget.imageUrl,
            radius: widget.radius,
          ),
          if (_uploading)
            SizedBox(
              width: widget.radius * 2,
              height: widget.radius * 2,
              child: const CircularProgressIndicator(strokeWidth: 3),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              child: Icon(Icons.camera_alt, size: 18, color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

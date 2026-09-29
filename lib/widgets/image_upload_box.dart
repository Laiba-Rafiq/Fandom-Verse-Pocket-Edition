import 'package:flutter/material.dart';

import '../core/utils/ui_helpers.dart';
import '../services/cloudinary_service.dart';

class ImageUploadBox extends StatefulWidget {
  const ImageUploadBox({
    super.key,
    required this.folder,
    required this.onChanged,
    this.imageUrl,
    this.label = 'Image',
    this.height = 180,
    this.enabled = true,
  });

  final String folder;
  final String? imageUrl;
  final ValueChanged<String?> onChanged;
  final String label;
  final double height;
  final bool enabled;

  @override
  State<ImageUploadBox> createState() => _ImageUploadBoxState();
}

class _ImageUploadBoxState extends State<ImageUploadBox> {
  bool _uploading = false;

  bool get _hasImage => widget.imageUrl != null && widget.imageUrl!.isNotEmpty;

  Future<void> _pickAndUpload() async {
    if (_uploading || !widget.enabled) return;
    setState(() => _uploading = true);
    try {
      final result = await CloudinaryService.instance.pickAndUpload(
        folder: widget.folder,
      );
      if (result != null) {
        widget.onChanged(result.secureUrl);
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);

    Widget content;
    if (_uploading) {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Uploading image...'),
          ],
        ),
      );
    } else if (_hasImage) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            CloudinaryService.optimizedUrl(widget.imageUrl!, width: 800),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stack) => Center(
              child: Icon(Icons.broken_image_outlined,
                  size: 48, color: colors.outline),
            ),
          ),
          if (widget.enabled)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _CircleAction(
                    icon: Icons.edit,
                    tooltip: 'Change image',
                    onTap: _pickAndUpload,
                  ),
                  const SizedBox(width: 8),
                  _CircleAction(
                    icon: Icons.close,
                    tooltip: 'Remove image',
                    onTap: () => widget.onChanged(null),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 44, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              'Tap to add ${widget.label.toLowerCase()}',
              style: TextStyle(color: colors.primary),
            ),
            const SizedBox(height: 2),
            Text(
              'JPG, PNG or WEBP',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Material(
          color: colors.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.outlineVariant, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _hasImage ? null : _pickAndUpload,
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: content,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 18),
        onPressed: onTap,
      ),
    );
  }
}

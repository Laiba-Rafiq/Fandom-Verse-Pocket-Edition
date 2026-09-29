import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/utils/ui_helpers.dart';
import '../services/cloudinary_service.dart';

class MultiImageUploadBox extends StatefulWidget {
  const MultiImageUploadBox({
    super.key,
    required this.images,
    required this.folder,
    required this.onChanged,
    this.maxImages = 5,
    this.label = 'Images',
    this.enabled = true,
    this.errorText,
  });

  final List<String> images;
  final String folder;
  final ValueChanged<List<String>> onChanged;
  final int maxImages;
  final String label;
  final bool enabled;
  final String? errorText;

  @override
  State<MultiImageUploadBox> createState() => _MultiImageUploadBoxState();
}

class _MultiImageUploadBoxState extends State<MultiImageUploadBox> {
  static const double _tileSize = 100;

  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  int get _remaining => widget.maxImages - widget.images.length;

  Future<void> _addImages() async {
    if (_uploading || !widget.enabled || _remaining <= 0) return;

    final List<XFile> files;
    try {
      files = await CloudinaryService.instance.pickMultipleImages(
        maxImages: _remaining,
      );
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not open the photo picker.',
          isError: true,
        );
      }
      return;
    }
    if (files.isEmpty || !mounted) return;

    final updated = List<String>.from(widget.images);
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = files.length;
    });

    try {
      for (final file in files) {
        final result = await CloudinaryService.instance.uploadImage(
          file,
          folder: widget.folder,
        );
        updated.add(result.secureUrl);
        widget.onChanged(List<String>.from(updated));
        if (mounted) setState(() => _uploadDone++);
      }
    } on CloudinaryException catch (e) {
      if (mounted) UiHelpers.showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Some images could not be uploaded. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int index) {
    final updated = List<String>.from(widget.images)..removeAt(index);
    widget.onChanged(updated);
  }

  void _makeCover(int index) {
    if (index == 0) return;
    final updated = List<String>.from(widget.images);
    final url = updated.removeAt(index);
    updated.insert(0, url);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showAddTile = _uploading || (_remaining > 0 && widget.enabled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${widget.images.length}/${widget.maxImages}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _tileSize,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (showAddTile)
                _AddTile(
                  size: _tileSize,
                  uploading: _uploading,
                  progressText: '$_uploadDone/$_uploadTotal',
                  onTap: _addImages,
                ),
              for (var i = 0; i < widget.images.length; i++)
                _ImageThumb(
                  size: _tileSize,
                  url: widget.images[i],
                  isCover: i == 0,
                  enabled: widget.enabled && !_uploading,
                  onRemove: () => _remove(i),
                  onTap: () => _makeCover(i),
                ),
            ],
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 6),
          Text(
            'Tap an image to make it the cover.',
            style: textTheme.bodySmall,
          ),
        ],
        if (widget.errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.errorText!,
            style: textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.uploading,
    required this.progressText,
    required this.onTap,
  });

  final double size;
  final bool uploading;
  final String progressText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: uploading ? null : onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: uploading
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading $progressText',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add Image',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({
    required this.size,
    required this.url,
    required this.isCover,
    required this.enabled,
    required this.onRemove,
    required this.onTap,
  });

  final double size;
  final String url;
  final bool isCover;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCover ? colors.primary : colors.outlineVariant,
              width: isCover ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  CloudinaryService.optimizedUrl(url, width: 300),
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                  errorBuilder: (context, error, stack) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.outline,
                    ),
                  ),
                ),
                if (isCover)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        'Cover',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (enabled)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onRemove,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

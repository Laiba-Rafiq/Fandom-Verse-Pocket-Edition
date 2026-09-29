import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_post.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_button.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final FandomPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final Stream<bool> _bookmarked =
      BookmarkService.instance.watchIsBookmarked(widget.post.id);
  int _page = 0;
  bool _savingBookmark = false;

  Future<void> _toggleBookmark(bool isBookmarked) async {
    if (_savingBookmark) return;
    setState(() => _savingBookmark = true);
    try {
      await BookmarkService.instance.toggle(
        widget.post,
        isBookmarked: isBookmarked,
      );
      if (mounted) {
        UiHelpers.showSnack(
          context,
          isBookmarked
              ? 'Removed from bookmarks.'
              : 'Saved for offline reading.',
        );
      }
    } on BookmarkException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update your bookmarks. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _savingBookmark = false);
    }
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImageViewerScreen(
          images: widget.post.images,
          initialIndex: index,
        ),
      ),
    );
  }

  String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isGlossary = post.type.isGlossary;
    final isGallery = post.type == ContentType.gallery;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: post.hasImages ? 280 : 200,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.purple,
            actions: [
              StreamBuilder<bool>(
                stream: _bookmarked,
                builder: (context, snapshot) {
                  final saved = snapshot.data ?? false;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: Colors.black26,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: saved ? 'Remove bookmark' : 'Bookmark',
                        onPressed: _savingBookmark
                            ? null
                            : () => _toggleBookmark(saved),
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: post.hasImages
                  ? _Carousel(
                      images: post.images,
                      page: _page,
                      onPageChanged: (index) => setState(() => _page = index),
                      onTap: _openViewer,
                    )
                  : _IconBanner(type: post.type),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            text: post.type.label,
                            icon: post.type.icon,
                            background: AppColors.lavender,
                            foreground: AppColors.purple,
                          ),
                          _Pill(
                            text: post.fandom,
                            background: AppColors.softPink,
                            foreground: AppColors.pink,
                          ),
                          if (post.isFeatured)
                            const _Pill(
                              text: 'Trending',
                              icon: Icons.star_rounded,
                              background: Color(0x22F5A524),
                              foreground: Color(0xFFB7791F),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        post.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: colors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(post.dateLabel, style: textTheme.bodySmall),
                          if (!isGlossary && post.body.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: colors.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.readMinutes} min read',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (isGlossary)
                        _MeaningCard(meaning: post.summary)
                      else if (post.summary.isNotEmpty)
                        _SummaryCard(summary: post.summary),
                      if (post.body.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        if (isGlossary)
                          Text(
                            'Example',
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        if (isGlossary) const SizedBox(height: 6),
                        SelectableText(
                          post.body,
                          style: textTheme.bodyLarge?.copyWith(height: 1.65),
                        ),
                      ],
                      if (post.hasMedia) ...[
                        const SizedBox(height: 24),
                        AppButton(
                          label: post.type.mediaLabel,
                          icon: post.type == ContentType.podcast
                              ? Icons.headphones_rounded
                              : Icons.play_arrow_rounded,
                          onPressed: () =>
                              LinkLauncher.openWebsite(context, post.mediaUrl!),
                        ),
                      ],
                      if (isGallery && post.images.length > 1) ...[
                        const SizedBox(height: 24),
                        Text(
                          'All photos (${post.images.length})',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: post.images.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _openViewer(index),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                CloudinaryService.optimizedUrl(
                                  post.images[index],
                                  width: 300,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const ColoredBox(color: AppColors.lavender),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (post.hasSource) ...[
                        const SizedBox(height: 20),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => LinkLauncher.openWebsite(
                              context, post.sourceUrl!),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link_rounded,
                                  size: 18,
                                  color: AppColors.purple,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Source: ${_hostOf(post.sourceUrl!)}',
                                    style: const TextStyle(
                                      color: AppColors.purple,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (post.tags.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in post.tags)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: colors.outlineVariant),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    color: AppColors.pink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.images,
    required this.page,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<String> images;
  final int page;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => onTap(index),
            child: Image.network(
              CloudinaryService.optimizedUrl(images[index], width: 1200),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.softGradient),
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x44000000)
                ],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == page ? AppColors.pink : Colors.white70,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _IconBanner extends StatelessWidget {
  const _IconBanner({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.buttonGradient),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white24,
                child: Icon(type.icon, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                type.section.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: AppColors.pink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard({required this.meaning});

  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x33A23CF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MEANING',
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meaning,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  const _ImageViewerScreen({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              CloudinaryService.optimizedUrl(widget.images[index], width: 1600),
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
              errorBuilder: (context, error, stack) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

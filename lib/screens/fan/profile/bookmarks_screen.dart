import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_post.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/bookmark_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/state_views.dart';
import '../content/post_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key, this.offlineView = false});

  final bool offlineView;

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  late Stream<SavedPostsSnapshot> _stream =
      BookmarkService.instance.watchBookmarks();
  final _searchController = TextEditingController();
  String _query = '';
  ContentSection? _section;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = BookmarkService.instance.watchBookmarks());
  }

  String _savedLabel(DateTime? date) {
    if (date == null) return 'Saved just now';
    return 'Saved ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  void _open(FandomPost post) {
    AppNavigator.push(context, PostDetailScreen(post: post));
  }

  Future<void> _remove(FandomPost post) async {
    try {
      await BookmarkService.instance.remove(post.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Removed from bookmarks.'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.softPink,
            onPressed: () => BookmarkService.instance.add(post),
          ),
        ),
      );
    } on BookmarkException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not remove the bookmark. Please try again.',
          isError: true,
        );
      }
    }
  }

  List<SavedPost> _apply(List<SavedPost> items) {
    return items.where((item) {
      if (_section != null && item.post.section != _section) return false;
      return item.post.matches(_query);
    }).toList();
  }

  Widget _page({
    required String title,
    required Widget body,
    int? total,
    int? showing,
    bool? offline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BookmarksHeader(
          title: title,
          subtitle: widget.offlineView
              ? 'Read your saved posts without internet'
              : 'Posts you saved to read again later',
          total: total,
          showing: showing,
          offline: offline,
        ),
        Expanded(child: body),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.offlineView ? 'Offline content' : 'Saved bookmarks';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: StreamBuilder<SavedPostsSnapshot>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _page(
                title: title,
                body: ErrorView(
                  message: 'Could not load your bookmarks.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _page(
                title: title,
                body: const LoadingView(message: 'Loading your bookmarks...'),
              );
            }

            final data = snapshot.data!;
            if (data.items.isEmpty) {
              return _page(
                title: title,
                total: 0,
                offline: data.fromCache,
                body: EmptyStateView(
                  icon: Icons.bookmark_border_rounded,
                  title: widget.offlineView
                      ? 'Nothing saved for offline yet'
                      : 'No bookmarks yet',
                  message:
                      'Open any article, story, profile or glossary term and '
                      'tap the bookmark icon to save it. Saved posts can be '
                      'read without internet.',
                  actionLabel: 'Go back',
                  onAction: () => Navigator.of(context).pop(),
                ),
              );
            }

            final visible = _apply(data.items);

            return _page(
              title: title,
              total: data.items.length,
              showing: visible.length,
              offline: data.fromCache,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      _StatusCard(
                        count: data.items.length,
                        offline: data.fromCache,
                        offlineView: widget.offlineView,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        controller: _searchController,
                        hasQuery: _query.isNotEmpty,
                        onChanged: (value) => setState(() => _query = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _Pill(
                              label: 'All',
                              selected: _section == null,
                              onTap: () => setState(() => _section = null),
                            ),
                            for (final section in ContentSection.values) ...[
                              const SizedBox(width: 8),
                              _Pill(
                                label: section.label,
                                icon: section.icon,
                                selected: _section == section,
                                onTap: () => setState(() => _section = section),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        text: '${visible.length} saved '
                            '${visible.length == 1 ? 'post' : 'posts'}',
                      ),
                      const SizedBox(height: 12),
                      if (visible.isEmpty)
                        const _NoMatches()
                      else
                        for (final item in visible) ...[
                          _SavedCard(
                            post: item.post,
                            savedLabel: _savedLabel(item.savedAt),
                            onTap: () => _open(item.post),
                            onRemove: () => _remove(item.post),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BookmarksHeader extends StatelessWidget {
  const _BookmarksHeader({
    required this.title,
    required this.subtitle,
    this.total,
    this.showing,
    this.offline,
  });

  final String title;
  final String subtitle;
  final int? total;
  final int? showing;
  final bool? offline;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final canPop = Navigator.of(context).canPop();
    final count = total;
    final visibleCount = showing;
    final isOffline = offline;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
                        Material(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: CircleBorder(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/categories/cat_bookmarks.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) => const Icon(
                              Icons.bookmark_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (count != null && count > 0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            value: '$count',
                            label: 'Saved',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            value: '${visibleCount ?? count}',
                            label: 'Showing',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            value: isOffline == true ? 'Offline' : 'Online',
                            label: 'Status',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search your saved posts',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.purple,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0x26A23CF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: AppColors.pink,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No saved posts match your filters.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.count,
    required this.offline,
    required this.offlineView,
  });

  final int count;
  final bool offline;
  final bool offlineView;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String message;
    final IconData icon;
    final Color color;

    if (offline) {
      title = 'You\'re offline';
      message = 'Showing your saved copies. You can still read them all.';
      icon = Icons.cloud_off_rounded;
      color = AppColors.warning;
    } else {
      title = '$count ${count == 1 ? 'post' : 'posts'} saved on this phone';
      message = offlineView
          ? 'These stay available even without internet. Images may need '
              'a connection.'
          : 'Bookmarked posts are also available offline.';
      icon = Icons.offline_pin_rounded;
      color = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : colors.surface,
          borderRadius: BorderRadius.circular(40),
          border: selected ? null : Border.all(color: colors.outlineVariant),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x33A23CF0),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  else if (icon != null)
                    Icon(icon, size: 16, color: AppColors.purple),
                  if (selected || icon != null) const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.post,
    required this.savedLabel,
    required this.onTap,
    required this.onRemove,
  });

  final FandomPost post;
  final String savedLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cover = post.coverImage;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: cover != null
                        ? Image.network(
                            CloudinaryService.optimizedUrl(cover, width: 260),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _TypeBox(type: post.type),
                          )
                        : _TypeBox(type: post.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _TypeChip(type: post.type),
                          if (post.fandom.isNotEmpty)
                            _FandomChip(text: post.fandom),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (post.summary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          post.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.offline_pin_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              savedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: AppColors.softPink,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Remove bookmark',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.bookmark_remove_rounded,
                      color: AppColors.pink,
                      size: 20,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FandomChip extends StatelessWidget {
  const _FandomChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TypeBox extends StatelessWidget {
  const _TypeBox({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: Center(
        child: Icon(type.icon, color: AppColors.purple, size: 30),
      ),
    );
  }
}

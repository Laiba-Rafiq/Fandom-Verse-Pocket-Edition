import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/fandom_post.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/state_views.dart';
import 'post_detail_screen.dart';

class ContentSectionScreen extends StatefulWidget {
  const ContentSectionScreen({super.key, required this.section});

  final ContentSection section;

  @override
  State<ContentSectionScreen> createState() => _ContentSectionScreenState();
}

class _ContentSectionScreenState extends State<ContentSectionScreen> {
  late Stream<List<FandomPost>> _stream = PostService.instance.watchPosts();

  void _retry() {
    setState(() => _stream = PostService.instance.watchPosts());
  }

  Widget _stateBody(Widget hero, Widget child) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        hero,
        SizedBox(height: 280, child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: StreamBuilder<List<FandomPost>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _stateBody(
                _SectionHero(section: widget.section),
                ErrorView(
                  message: 'Could not load content.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _stateBody(
                _SectionHero(section: widget.section),
                const LoadingView(message: 'Loading content...'),
              );
            }
            final posts = snapshot.data!
                .where((post) => post.section == widget.section)
                .toList();
            final fandoms = {for (final post in posts) post.fandom};
            return ContentFeed(
              section: widget.section,
              posts: posts,
              header: _SectionHero(
                section: widget.section,
                itemCount: posts.length,
                fandomCount: fandoms.length,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHero extends StatelessWidget {
  const _SectionHero({
    required this.section,
    this.itemCount,
    this.fandomCount,
  });

  final ContentSection section;
  final int? itemCount;
  final int? fandomCount;

  static const String _artFolder = 'assets/images/categories/';

  String get _art {
    switch (section) {
      case ContentSection.beginner:
        return '${_artFolder}cat_beginner_hub.png';
      case ContentSection.deepDive:
        return '${_artFolder}cat_deep_dive.png';
      case ContentSection.resources:
        return '${_artFolder}cat_resources.png';
    }
  }

  String get _tagline {
    switch (section) {
      case ContentSection.beginner:
        return 'New to a fandom? Start here';
      case ContentSection.deepDive:
        return 'For true fans';
      case ContentSection.resources:
        return 'Stay in the loop';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 104.0 : 124.0;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            Positioned(
              bottom: -50,
              left: -40,
              child: _Bubble(size: 150, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          Material(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(section.icon, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _tagline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                section.description,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (itemCount != null) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeroStat(
                                      icon: Icons.article_rounded,
                                      label: '$itemCount '
                                          '${itemCount == 1 ? 'item' : 'items'}',
                                    ),
                                    if ((fandomCount ?? 0) > 0)
                                      _HeroStat(
                                        icon: Icons.auto_awesome_rounded,
                                        label: '$fandomCount '
                                            '${fandomCount == 1 ? 'fandom' : 'fandoms'}',
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: artSize,
                          height: artSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                _art,
                                width: artSize,
                                height: artSize,
                                fit: BoxFit.contain,
                                semanticLabel: section.label,
                                errorBuilder: (context, error, stack) =>
                                    CircleAvatar(
                                  radius: artSize / 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    section.icon,
                                    color: Colors.white,
                                    size: artSize / 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class ContentFeed extends StatefulWidget {
  const ContentFeed({
    super.key,
    required this.section,
    required this.posts,
    this.showIntro = false,
    this.header,
  });

  final ContentSection section;
  final List<FandomPost> posts;
  final bool showIntro;
  final Widget? header;

  @override
  State<ContentFeed> createState() => _ContentFeedState();
}

class _ContentFeedState extends State<ContentFeed> {
  final _searchController = TextEditingController();
  String _query = '';
  ContentType? _type;
  String? _fandom;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(FandomPost post) {
    AppNavigator.push(context, PostDetailScreen(post: post));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _type = null;
      _fandom = null;
    });
  }

  List<String> _fandoms() {
    final set = <String>{
      for (final post in widget.posts) post.fandom,
      if (_fandom != null) _fandom!,
    };
    return set.toList()..sort();
  }

  List<FandomPost> _visible() {
    final list = widget.posts.where((post) {
      if (_type != null && post.type != _type) return false;
      if (_fandom != null && post.fandom != _fandom) return false;
      return post.matches(_query);
    }).toList();
    if (_type == ContentType.glossary) {
      list.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visible = _visible();
    final hasFilters =
        _query.trim().isNotEmpty || _type != null || _fandom != null;

    final body = <Widget>[
      if (widget.showIntro) ...[
        _IntroCard(section: widget.section),
        const SizedBox(height: 16),
      ],
      _SearchBox(
        controller: _searchController,
        query: _query,
        hint: 'Search ${widget.section.label.toLowerCase()}',
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
              selected: _type == null,
              onTap: () => setState(() => _type = null),
            ),
            for (final type in widget.section.types) ...[
              const SizedBox(width: 8),
              _Pill(
                label: type.label,
                icon: type.icon,
                selected: _type == type,
                onTap: () => setState(() => _type = type),
              ),
            ],
          ],
        ),
      ),
      if (_fandoms().length > 1) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _SmallPill(
                label: 'All fandoms',
                selected: _fandom == null,
                onTap: () => setState(() => _fandom = null),
              ),
              for (final fandom in _fandoms()) ...[
                const SizedBox(width: 6),
                _SmallPill(
                  label: fandom,
                  selected: _fandom == fandom,
                  onTap: () => setState(() => _fandom = fandom),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hasFilters
                ? '${visible.length} of ${widget.posts.length} '
                    '${widget.posts.length == 1 ? 'item' : 'items'}'
                : '${visible.length} '
                    '${visible.length == 1 ? 'item' : 'items'}',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (widget.posts.isEmpty)
        _SoftNote(
          icon: widget.section.icon,
          text: 'Nothing here yet. New ${widget.section.label} '
              'content will appear soon!',
        )
      else if (visible.isEmpty)
        _SoftNote(
          icon: Icons.search_off_rounded,
          text: 'Nothing matches your filters.',
          actionLabel: hasFilters ? 'Clear filters' : null,
          onAction: hasFilters ? _clearFilters : null,
        )
      else
        for (final post in visible) ...[
          if (post.type.isGlossary)
            _GlossaryCard(post: post, onTap: () => _open(post))
          else
            FandomPostCard(post: post, onTap: () => _open(post)),
          const SizedBox(height: 12),
        ],
    ];

    final header = widget.header;
    if (header == null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: body,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        header,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FandomPostCard extends StatelessWidget {
  const FandomPostCard({super.key, required this.post, required this.onTap});

  final FandomPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cover = post.coverImage;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
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
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover != null)
                          Image.network(
                            CloudinaryService.optimizedUrl(cover, width: 300),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _TypeBox(type: post.type),
                          )
                        else
                          _TypeBox(type: post.type),
                        if (post.type.needsMediaLink)
                          Center(
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.black45,
                              child: Icon(
                                post.type == ContentType.podcast
                                    ? Icons.headphones_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _TypeTag(type: post.type),
                          const Spacer(),
                          if (post.isFeatured)
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: AppColors.warning,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
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
                      const SizedBox(height: 6),
                      Text(
                        '${post.fandom} • ${post.dateLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: AppColors.pink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _GlossaryCard extends StatelessWidget {
  const _GlossaryCard({required this.post, required this.onTap});

  final FandomPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final letter = post.title.isEmpty ? '?' : post.title[0].toUpperCase();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33A23CF0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      post.fandom,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.pink,
            child: Icon(section.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.description,
                  style: const TextStyle(color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.query,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A6C4DFF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.purple),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0x33A23CF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
          ),
        ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
          ),
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : colors.surface,
          shadows: selected
              ? const [
                  BoxShadow(
                    color: Color(0x40F0357A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
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
                      fontWeight: FontWeight.w700,
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.purple : AppColors.lavender,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.purple,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type});

  final ContentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: AppColors.purple),
          const SizedBox(width: 3),
          Text(
            type.label,
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
        child: Icon(type.icon, color: AppColors.purple, size: 34),
      ),
    );
  }
}

class _SoftNote extends StatelessWidget {
  const _SoftNote({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AppColors.purple),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.pink),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
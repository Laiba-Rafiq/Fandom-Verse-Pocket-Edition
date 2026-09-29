import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/fandom_post.dart';
import '../../../services/post_service.dart';
import '../../../widgets/state_views.dart';
import 'content_feed.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Stream<List<FandomPost>> _stream = PostService.instance.watchPosts();

  static const String _artFolder = 'assets/images/categories/';

  static const List<_ExploreTab> _tabs = [
    _ExploreTab(
      section: ContentSection.resources,
      label: 'Resources',
      icon: Icons.perm_media_rounded,
      art: '${_artFolder}cat_resources.png',
      tagline: 'Stay in the loop',
    ),
    _ExploreTab(
      section: ContentSection.beginner,
      label: 'Beginner Hub',
      icon: Icons.school_rounded,
      art: '${_artFolder}cat_beginner_hub.png',
      tagline: 'New to a fandom? Start here',
    ),
    _ExploreTab(
      section: ContentSection.deepDive,
      label: 'Deep Dive',
      icon: Icons.psychology_alt_rounded,
      art: '${_artFolder}cat_deep_dive.png',
      tagline: 'For true fans',
    ),
  ];

  void _retry() {
    setState(() => _stream = PostService.instance.watchPosts());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: DefaultTabController(
        length: _tabs.length,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ExploreHeader(tabs: _tabs),
              Expanded(
                child: StreamBuilder<List<FandomPost>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load content.\n${snapshot.error}',
                        onRetry: _retry,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LoadingView(message: 'Loading content...');
                    }
                    final all = snapshot.data!;
                    return TabBarView(
                      children: [
                        for (final tab in _tabs)
                          _buildFeed(
                            tab,
                            all
                                .where((post) => post.section == tab.section)
                                .toList(),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(_ExploreTab tab, List<FandomPost> posts) {
    final fandoms = {for (final post in posts) post.fandom};
    return ContentFeed(
      key: PageStorageKey<String>(tab.section.name),
      section: tab.section,
      posts: posts,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 788),
            child: _SectionIntro(
              tab: tab,
              itemCount: posts.length,
              fandomCount: fandoms.length,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreTab {
  const _ExploreTab({
    required this.section,
    required this.label,
    required this.icon,
    required this.art,
    required this.tagline,
  });

  final ContentSection section;
  final String label;
  final IconData icon;
  final String art;
  final String tagline;
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({required this.tabs});

  final List<_ExploreTab> tabs;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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
              right: -40,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            Positioned(
              bottom: -60,
              left: -30,
              child: _Bubble(size: 140, opacity: 0.07),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Explore',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'News, guides, trivia and more from '
                              'every fandom',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: TabBar(
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      labelColor: AppColors.pink,
                      unselectedLabelColor: Colors.white.withValues(alpha: 0.9),
                      labelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      splashBorderRadius: BorderRadius.circular(16),
                      overlayColor: WidgetStatePropertyAll(
                        Colors.white.withValues(alpha: 0.12),
                      ),
                      tabs: [
                        for (final tab in tabs)
                          Tab(
                            height: 56,
                            iconMargin: const EdgeInsets.only(bottom: 2),
                            icon: Icon(tab.icon, size: 21),
                            child: Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.tab,
    required this.itemCount,
    required this.fandomCount,
  });

  final _ExploreTab tab;
  final int itemCount;
  final int fandomCount;

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.of(context).size.width < 360 ? 84.0 : 96.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x26A23CF0)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tab.tagline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tab.section.label,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.section.description,
                  style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MiniStat(
                      icon: Icons.article_rounded,
                      label: '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    ),
                    if (fandomCount > 0)
                      _MiniStat(
                        icon: Icons.auto_awesome_rounded,
                        label: '$fandomCount '
                            '${fandomCount == 1 ? 'fandom' : 'fandoms'}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            tab.art,
            width: artSize,
            height: artSize,
            fit: BoxFit.contain,
            semanticLabel: tab.section.label,
            errorBuilder: (context, error, stack) => CircleAvatar(
              radius: artSize / 3,
              backgroundColor: AppColors.pink,
              child: Icon(tab.icon, color: Colors.white, size: artSize / 3),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.pink),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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

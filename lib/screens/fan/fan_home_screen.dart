import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/fandom_post.dart';
import '../../models/wishlist_item.dart';
import '../../routes/app_navigator.dart';
import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/user_avatar.dart';
import 'ai/ai_helper_screen.dart';
import 'content/content_feed.dart';
import 'content/post_detail_screen.dart';
import 'info/about_us_screen.dart';
import 'info/contact_us_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/bookmarks_screen.dart';
import 'store/wishlist_screen.dart';

class FanTabs {
  FanTabs._();
  static const int home = 0;
  static const int explore = 1;
  static const int events = 2;
  static const int store = 3;
  static const int profile = 4;

  static final ValueNotifier<int?> requested = ValueNotifier<int?>(null);

  static void open(int tab) {
    requested.value = null;
    requested.value = tab;
  }
}

class FanHomeScreen extends StatefulWidget {
  const FanHomeScreen({
    super.key,
    required this.user,
    required this.onSelectTab,
  });

  final AppUser user;
  final ValueChanged<int> onSelectTab;

  @override
  State<FanHomeScreen> createState() => _FanHomeScreenState();
}

class _FanHomeScreenState extends State<FanHomeScreen> {
  static const String _categoryArt = 'assets/images/categories/';

  late final Stream<List<WishlistEntry>> _priceDrops =
      WishlistService.instance.watchPriceDrops();

  late final Stream<int> _unreadCount = _buildUnreadStream();

  Stream<int> _buildUnreadStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream<int>.value(0);
    return NotificationService.instance.watchUnreadCount(uid);
  }

  void _openNotifications() {
    AppNavigator.push(context, const NotificationsScreen());
  }

  void _openWishlist() {
    AppNavigator.push(context, const WishlistScreen());
  }

  void _openContact() {
    AppNavigator.push(context, ContactUsScreen(user: widget.user));
  }

  void _openAbout() {
    AppNavigator.push(context, AboutUsScreen(user: widget.user));
  }

  void _openSection(ContentSection section) {
    AppNavigator.push(context, ContentSectionScreen(section: section));
  }

  void _openBookmarks() {
    AppNavigator.push(context, const BookmarksScreen());
  }

  void _openAiHelper() {
    AppNavigator.push(context, AiHelperScreen(userName: widget.user.name));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
    final onSelectTab = widget.onSelectTab;

    final tiles = <_FeatureTile>[
      _FeatureTile(
        image: '${_categoryArt}cat_beginner_hub.png',
        icon: Icons.school_rounded,
        title: 'Beginner Fan Hub',
        subtitle: 'Profiles, stories & glossary',
        color: AppColors.secondary,
        onTap: () => _openSection(ContentSection.beginner),
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_resources.png',
        icon: Icons.perm_media_rounded,
        title: 'Resources',
        subtitle: 'News, galleries, videos, podcasts',
        color: AppColors.primary,
        onTap: () => onSelectTab(FanTabs.explore),
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_deep_dive.png',
        icon: Icons.psychology_alt_rounded,
        title: 'Deep Dive',
        subtitle: 'Hidden trivia & advanced lore',
        color: const Color(0xFF8E44AD),
        onTap: () => _openSection(ContentSection.deepDive),
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_events.png',
        icon: Icons.event_rounded,
        title: 'Events',
        subtitle: 'Conventions & meetups near you',
        color: AppColors.warning,
        onTap: () => onSelectTab(FanTabs.events),
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_merch_store.png',
        icon: Icons.storefront_rounded,
        title: 'Merch Store',
        subtitle: 'Official merchandise',
        color: AppColors.accent,
        onTap: () => onSelectTab(FanTabs.store),
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_wishlist.png',
        icon: Icons.favorite_rounded,
        title: 'My Wishlist',
        subtitle: 'Saved items & price drops',
        color: AppColors.pink,
        onTap: _openWishlist,
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_ai_helper.png',
        icon: Icons.smart_toy_rounded,
        title: 'AI Fan Helper',
        subtitle: 'Ask fandom questions',
        color: AppColors.success,
        onTap: _openAiHelper,
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_bookmarks.png',
        icon: Icons.bookmarks_rounded,
        title: 'Bookmarks',
        subtitle: 'Saved for offline reading',
        color: const Color(0xFF3867D6),
        onTap: _openBookmarks,
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_contact_us.png',
        icon: Icons.support_agent_rounded,
        title: 'Contact Us',
        subtitle: 'Send us an enquiry',
        color: const Color(0xFF20BF6B),
        onTap: _openContact,
      ),
      _FeatureTile(
        image: '${_categoryArt}cat_about_us.png',
        icon: Icons.groups_rounded,
        title: 'About Us',
        subtitle: 'The team behind the app',
        color: const Color(0xFF4B6584),
        onTap: _openAbout,
      ),
    ];

    return Scaffold(
      body: StreamBuilder<List<WishlistEntry>>(
        stream: _priceDrops,
        builder: (context, snapshot) {
          final drops = snapshot.data ?? const <WishlistEntry>[];
          return SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<int>(
                  stream: _unreadCount,
                  builder: (context, unreadSnapshot) => _Header(
                    user: widget.user,
                    unreadCount: unreadSnapshot.data ?? 0,
                    onBellTap: _openNotifications,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (drops.isNotEmpty) ...[
                        _PriceDropCard(
                          count: drops.length,
                          onTap: _openWishlist,
                        ),
                        const SizedBox(height: 20),
                      ],
                      const _TrendingSection(),
                      Text(
                        'Explore Fandom Verse',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                        children: tiles,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrendingFandom {
  _TrendingFandom(this.name);

  final String name;
  final List<FandomPost> posts = [];
  int featured = 0;

  int get score => posts.length + featured * 2;

  String? get cover {
    for (final post in posts) {
      if (post.isFeatured && post.coverImage != null) return post.coverImage;
    }
    for (final post in posts) {
      if (post.coverImage != null) return post.coverImage;
    }
    return null;
  }
}

class _TrendingSection extends StatefulWidget {
  const _TrendingSection();

  @override
  State<_TrendingSection> createState() => _TrendingSectionState();
}

class _TrendingSectionState extends State<_TrendingSection> {
  late final Stream<List<FandomPost>> _stream =
      PostService.instance.watchPosts();
  final PageController _controller = PageController(viewportFraction: 0.86);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_TrendingFandom> _trending(List<FandomPost> posts) {
    final recent = posts.where((post) => post.isRecent()).toList();
    final source = recent.isEmpty ? posts : recent;
    final groups = <String, _TrendingFandom>{};
    for (final post in source) {
      final group =
          groups.putIfAbsent(post.fandom, () => _TrendingFandom(post.fandom));
      group.posts.add(post);
      if (post.isFeatured) group.featured++;
    }
    var list = groups.values.toList();
    if (list.length > 1) {
      list = list.where((group) => group.name != 'General').toList();
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list.take(6).toList();
  }

  void _openFandom(String fandom, List<FandomPost> all) {
    final posts = all.where((post) => post.fandom == fandom).toList();
    AppNavigator.push(
        context, _FandomPostsScreen(fandom: fandom, posts: posts));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FandomPost>>(
      stream: _stream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <FandomPost>[];
        final trending = _trending(all);
        if (trending.isEmpty) return const SizedBox.shrink();
        final page = _page >= trending.length ? 0 : _page;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Trending Fandoms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                itemCount: trending.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final group = trending[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TrendingCard(
                      rank: index + 1,
                      group: group,
                      onTap: () => _openFandom(group.name, all),
                    ),
                  );
                },
              ),
            ),
            if (trending.length > 1) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < trending.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == page
                            ? AppColors.pink
                            : const Color(0x33A23CF0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
          ],
        );
      },
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({
    required this.rank,
    required this.group,
    required this.onTap,
  });

  final int rank;
  final _TrendingFandom group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = group.cover;
    final latest = group.posts.isEmpty ? null : group.posts.first;

    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: const Color(0x406C4DFF),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null)
              Image.network(
                CloudinaryService.optimizedUrl(cover, width: 700),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.buttonGradient),
                ),
              )
            else
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.buttonGradient),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x11000000), Color(0xAA1F1147)],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#$rank Trending',
                  style: const TextStyle(
                    color: AppColors.pink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.posts.length} '
                    '${group.posts.length == 1 ? 'post' : 'posts'}'
                    '${latest == null ? '' : ' • ${latest.title}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
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

class _FandomPostsScreen extends StatelessWidget {
  const _FandomPostsScreen({required this.fandom, required this.posts});

  final String fandom;
  final List<FandomPost> posts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fandom)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              return FandomPostCard(
                post: post,
                onTap: () => AppNavigator.push(
                  context,
                  PostDetailScreen(post: post),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.unreadCount,
    required this.onBellTap,
  });

  final AppUser user;
  final int unreadCount;
  final VoidCallback onBellTap;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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
              top: -60,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: UserAvatar(
                          initials: user.initials,
                          imageUrl: user.avatarUrl,
                          radius: 26,
                          onDark: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _greeting(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: IconButton(
                          tooltip: unreadCount > 0
                              ? '$unreadCount unread notification'
                                  '${unreadCount == 1 ? '' : 's'}'
                              : 'Notifications',
                          onPressed: onBellTap,
                          icon: Badge(
                            isLabelVisible: unreadCount > 0,
                            backgroundColor: AppColors.pink,
                            label: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                            ),
                            child: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Your fandoms',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${user.selectedFandoms.length} following',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (user.selectedFandoms.isEmpty)
                          Text(
                            'Pick your fandoms from your profile to get '
                            'personalised updates.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final fandom in user.selectedFandoms)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1A1F1147),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    fandom,
                                    style: const TextStyle(
                                      color: AppColors.purple,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
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

class _PriceDropCard extends StatelessWidget {
  const _PriceDropCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x33F0357A)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.pink,
                child: Icon(
                  Icons.trending_down_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price drop alert!',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1
                          ? '1 wishlist item is cheaper now.'
                          : '$count wishlist items are cheaper now.',
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.image,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String image;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x126C4DFF),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.16),
                          const Color(0xFFA23CF0).withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: title,
                      errorBuilder: (context, error, stack) => Center(
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: color,
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_post.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';
import 'post_form_screen.dart';

class PostManagementScreen extends StatefulWidget {
  const PostManagementScreen({super.key});

  @override
  State<PostManagementScreen> createState() => _PostManagementScreenState();
}

class _PostManagementScreenState extends State<PostManagementScreen> {
  late Stream<List<FandomPost>> _stream = PostService.instance.watchPosts();
  final _searchController = TextEditingController();
  String _query = '';
  ContentSection? _section;
  bool _addingSamples = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = PostService.instance.watchPosts());
  }

  void _openForm([FandomPost? post]) {
    AppNavigator.push(
      context,
      PostFormScreen(post: post, initialType: _section?.types.first),
    );
  }

  Future<void> _addSamples() async {
    final confirmed = await UiHelpers.confirm(
      context,
      title: 'Add sample content?',
      message: 'This adds 11 example posts (news, video, podcast, profile, '
          'story, glossary, trivia, lore and interview). You can edit or '
          'delete them later.',
      confirmText: 'Add samples',
    );
    if (!confirmed) return;
    setState(() => _addingSamples = true);
    try {
      final count = await PostService.instance.addSamplePosts();
      if (mounted) UiHelpers.showSnack(context, '$count sample posts added.');
    } on PostException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not add sample posts. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _addingSamples = false);
    }
  }

  Future<void> _toggleFeatured(FandomPost post) async {
    final featured = !post.isFeatured;
    try {
      await PostService.instance.setFeatured(post.id, featured);
      if (mounted) {
        UiHelpers.showSnack(
          context,
          featured ? 'Added to Trending.' : 'Removed from Trending.',
        );
      }
    } on PostException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update the post. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _delete(FandomPost post) async {
    final confirmed = await UiHelpers.confirm(
      context,
      title: 'Delete post?',
      message: '"${post.title}" will be removed for all fans. '
          'This cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed) return;
    try {
      await PostService.instance.deletePost(post.id);
      if (mounted) UiHelpers.showSnack(context, 'Post deleted.');
    } on PostException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not delete the post. Please try again.',
          isError: true,
        );
      }
    }
  }

  List<FandomPost> _apply(List<FandomPost> posts) {
    return posts.where((post) {
      if (_section != null && post.section != _section) return false;
      return post.matches(_query);
    }).toList();
  }

  Widget _header({int? total, int featured = 0}) {
    return AdminPageHeader(
      title: 'Fandom Content',
      subtitle: 'Publish news, profiles, stories, trivia and more for fans.',
      icon: Icons.article_rounded,
      actions: [
        AdminGlassFrame(
          child: PopupMenuButton<String>(
            tooltip: 'More options',
            enabled: !_addingSamples,
            icon: _addingSamples
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (value) {
              if (value == 'samples') _addSamples();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'samples',
                child: ListTile(
                  leading: Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.purple,
                  ),
                  title: Text('Add sample content'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
      chips: [
        if (total != null) ...[
          AdminHeaderChip(
            icon: Icons.article_rounded,
            label: '$total ${total == 1 ? 'post' : 'posts'}',
            color: AppColors.primary,
          ),
          AdminHeaderChip(
            icon: Icons.local_fire_department_rounded,
            label: '$featured trending',
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FandomPost>>(
      stream: _stream,
      builder: (context, snapshot) {
        final fab = AdminGradientFab(
          label: 'Add post',
          icon: Icons.add_rounded,
          onPressed: () => _openForm(),
        );

        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: ErrorView(
              message: 'Could not load content.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: const LoadingView(message: 'Loading content...'),
          );
        }

        final all = snapshot.data!;
        if (all.isEmpty) {
          return AdminPageScaffold(
            header: _header(total: 0),
            floatingActionButton: fab,
            body: _EmptyContent(
              addingSamples: _addingSamples,
              onAdd: () => _openForm(),
              onSamples: _addSamples,
            ),
          );
        }

        final featured = all.where((post) => post.isFeatured).length;
        final fandoms = all.map((post) => post.fandom).toSet().length;
        final visible = _apply(all);

        return AdminPageScaffold(
          header: _header(total: all.length, featured: featured),
          floatingActionButton: fab,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminStatBox(
                          label: 'Posts',
                          value: '${all.length}',
                          icon: Icons.article_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Featured',
                          value: '$featured',
                          icon: Icons.star_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Fandoms',
                          value: '$fandoms',
                          icon: Icons.category_rounded,
                          color: AppColors.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminSearchField(
                    controller: _searchController,
                    hint: 'Search title, fandom, type or tag',
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        AdminFilterPill(
                          label: 'All',
                          selected: _section == null,
                          onTap: () => setState(() => _section = null),
                        ),
                        for (final section in ContentSection.values) ...[
                          const SizedBox(width: 8),
                          AdminFilterPill(
                            label: section.label,
                            selected: _section == section,
                            onTap: () => setState(() => _section = section),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: _section == null ? 'All posts' : _section!.label,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visible.length} '
                        '${visible.length == 1 ? 'post' : 'posts'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    AdminEmptyNote(
                      icon: _query.isEmpty
                          ? Icons.inbox_rounded
                          : Icons.search_off_rounded,
                      text: _query.isEmpty
                          ? 'No posts in this section yet.'
                          : 'No posts match "$_query".',
                    )
                  else
                    for (final post in visible) ...[
                      _AdminPostCard(
                        post: post,
                        onEdit: () => _openForm(post),
                        onDelete: () => _delete(post),
                        onToggleFeatured: () => _toggleFeatured(post),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent({
    required this.addingSamples,
    required this.onAdd,
    required this.onSamples,
  });

  final bool addingSamples;
  final VoidCallback onAdd;
  final VoidCallback onSamples;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 110),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: AppColors.softGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No content yet',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add news, profiles, stories, glossary terms and more. '
                'Or start with sample content to see how it looks.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 22),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: FilledButton.icon(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add first post',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: addingSamples ? null : onSamples,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: const BorderSide(color: AppColors.purple),
                  minimumSize: const Size(double.infinity, 50),
                  shape: const StadiumBorder(),
                ),
                icon: addingSamples
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'Add sample content',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({
    required this.post,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFeatured,
  });

  final FandomPost post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFeatured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cover = post.coverImage;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: post.isFeatured
              ? AppColors.warning.withValues(alpha: 0.55)
              : const Color(0x26A23CF0),
          width: post.isFeatured ? 1.4 : 1,
        ),
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
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 84,
                            height: 84,
                            child: cover != null
                                ? Image.network(
                                    CloudinaryService.optimizedUrl(
                                      cover,
                                      width: 240,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        _TypeBox(type: post.type),
                                  )
                                : _TypeBox(type: post.type),
                          ),
                        ),
                        if (post.isFeatured)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Tag(
                                text: post.type.label,
                                icon: post.type.icon,
                                background: AppColors.lavender,
                                foreground: AppColors.purple,
                              ),
                              _Tag(
                                text: post.fandom,
                                background: AppColors.softPink,
                                foreground: AppColors.pink,
                              ),
                              if (post.images.length > 1)
                                _Tag(
                                  text: '${post.images.length} images',
                                  icon: Icons.photo_library_outlined,
                                  background: const Color(0x2200B8D9),
                                  foreground: const Color(0xFF0086A0),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: colors.outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${post.section.label} • ${post.dateLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: colors.outlineVariant),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _CardAction(
                        icon: post.isFeatured
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        label: post.isFeatured ? 'Trending' : 'Feature',
                        tooltip: post.isFeatured
                            ? 'Remove from Trending'
                            : 'Feature in Trending',
                        color: post.isFeatured
                            ? AppColors.warning
                            : colors.outline,
                        onTap: onToggleFeatured,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tooltip: 'Edit post',
                        color: AppColors.primary,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        tooltip: 'Delete post',
                        color: AppColors.error,
                        onTap: onDelete,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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

class _Tag extends StatelessWidget {
  const _Tag({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

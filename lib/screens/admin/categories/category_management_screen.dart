import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_category.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';
import 'category_form_screen.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late Stream<List<FandomCategory>> _stream =
      CategoryService.instance.watchCategories();
  bool _seeding = false;

  void _retry() {
    setState(() => _stream = CategoryService.instance.watchCategories());
  }

  void _openForm([FandomCategory? category]) {
    AppNavigator.push(context, CategoryFormScreen(category: category));
  }

  Future<void> _delete(FandomCategory category) async {
    final ok = await UiHelpers.confirm(
      context,
      title: 'Delete category?',
      message: '"${category.name}" will be removed. Fans will no longer see '
          'it when choosing their interests.',
      confirmText: 'Delete',
    );
    if (!ok) return;

    try {
      await CategoryService.instance.deleteCategory(category.id);
      if (mounted) UiHelpers.showSnack(context, 'Category deleted.');
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not delete the category. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _addDefaults() async {
    setState(() => _seeding = true);
    try {
      for (final name in AppConstants.defaultFandomCategories) {
        await CategoryService.instance.addCategory(name: name);
      }
      if (mounted) UiHelpers.showSnack(context, 'Example categories added!');
    } on CategoryException catch (e) {
      if (mounted) UiHelpers.showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not add the categories. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Widget _header({int? total}) {
    return AdminPageHeader(
      title: 'Categories',
      subtitle: 'Fandom categories fans pick as their interests.',
      icon: Icons.category_rounded,
      chips: [
        if (total != null)
          AdminHeaderChip(
            icon: Icons.category_rounded,
            label: '$total ${total == 1 ? 'category' : 'categories'}',
            color: AppColors.success,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FandomCategory>>(
      stream: _stream,
      builder: (context, snapshot) {
        final fab = AdminGradientFab(
          label: 'Add category',
          icon: Icons.add_rounded,
          onPressed: () => _openForm(),
        );

        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: ErrorView(
              message: 'Could not load categories.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: const LoadingView(message: 'Loading categories...'),
          );
        }

        final categories = snapshot.data!;
        if (categories.isEmpty) {
          return AdminPageScaffold(
            header: _header(total: 0),
            floatingActionButton: fab,
            body: _seeding
                ? const LoadingView(message: 'Adding categories...')
                : EmptyStateView(
                    icon: Icons.category_outlined,
                    title: 'No categories yet',
                    message: 'Add your first category with the button below, '
                        'or start with the SRS examples (Anime, Gaming, '
                        'Sci-Fi, Comics...).',
                    actionLabel: 'Add SRS example categories',
                    onAction: _addDefaults,
                  ),
          );
        }

        final withImage = categories
            .where((category) =>
                category.imageUrl != null && category.imageUrl!.isNotEmpty)
            .length;

        return AdminPageScaffold(
          header: _header(total: categories.length),
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
                          label: 'Categories',
                          value: '${categories.length}',
                          icon: Icons.category_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'With image',
                          value: '$withImage',
                          icon: Icons.image_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'No image',
                          value: '${categories.length - withImage}',
                          icon: Icons.hide_image_outlined,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: 'All categories',
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
                        '${categories.length} '
                        '${categories.length == 1 ? 'category' : 'categories'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 700 ? 3 : (width >= 320 ? 2 : 1);
                      const gap = 12.0;
                      final itemWidth = (width - gap * (columns - 1)) / columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final category in categories)
                            SizedBox(
                              width: itemWidth,
                              child: _CategoryTile(
                                category: category,
                                onEdit: () => _openForm(category),
                                onDelete: () => _delete(category),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final FandomCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasImage = category.imageUrl != null && category.imageUrl!.isNotEmpty;

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
          onTap: onEdit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: hasImage
                    ? Image.network(
                        CloudinaryService.optimizedUrl(
                          category.imageUrl!,
                          width: 400,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const _ArtFallback(
                          icon: Icons.broken_image_outlined,
                        ),
                      )
                    : const _ArtFallback(icon: Icons.category_rounded),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _IconAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        color: AppColors.primary,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _IconAction(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        color: AppColors.error,
                        onTap: onDelete,
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

class _ArtFallback extends StatelessWidget {
  const _ArtFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: Center(
        child: Icon(icon, size: 36, color: AppColors.purple),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
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
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    tooltip,
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

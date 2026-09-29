import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/product.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/product_service.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';
import 'product_form_screen.dart';

class MerchandiseManagementScreen extends StatefulWidget {
  const MerchandiseManagementScreen({super.key});

  @override
  State<MerchandiseManagementScreen> createState() =>
      _MerchandiseManagementScreenState();
}

class _MerchandiseManagementScreenState
    extends State<MerchandiseManagementScreen> {
  late Stream<List<Product>> _stream = ProductService.instance.watchProducts();

  void _retry() {
    setState(() => _stream = ProductService.instance.watchProducts());
  }

  void _openForm([Product? product]) {
    AppNavigator.push(context, ProductFormScreen(product: product));
  }

  Future<void> _delete(Product product) async {
    final ok = await UiHelpers.confirm(
      context,
      title: 'Delete product?',
      message: '"${product.name}" will be removed from the store.',
      confirmText: 'Delete',
    );
    if (!ok) return;

    try {
      await ProductService.instance.deleteProduct(product.id);
      if (mounted) UiHelpers.showSnack(context, 'Product deleted.');
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not delete the product. Please try again.',
          isError: true,
        );
      }
    }
  }

  Widget _header({int? total, int drops = 0}) {
    return AdminPageHeader(
      title: 'Merchandise',
      subtitle: 'Add apparel, collectibles and digital assets for the store.',
      icon: Icons.storefront_rounded,
      chips: [
        if (total != null) ...[
          AdminHeaderChip(
            icon: Icons.shopping_bag_rounded,
            label: '$total ${total == 1 ? 'product' : 'products'}',
            color: AppColors.primary,
          ),
          if (drops > 0)
            AdminHeaderChip(
              icon: Icons.trending_down_rounded,
              label: '$drops on sale',
              color: AppColors.success,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _stream,
      builder: (context, snapshot) {
        final fab = AdminGradientFab(
          label: 'Add product',
          icon: Icons.add_rounded,
          onPressed: () => _openForm(),
        );

        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: ErrorView(
              message: 'Could not load products.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: const LoadingView(message: 'Loading products...'),
          );
        }

        final products = snapshot.data!;
        if (products.isEmpty) {
          return AdminPageScaffold(
            header: _header(total: 0),
            floatingActionButton: fab,
            body: EmptyStateView(
              icon: Icons.storefront_outlined,
              title: 'No products yet',
              message: 'Add official apparel, collectibles and digital '
                  'assets for fans to browse in the Merch Store.',
              actionLabel: 'Add first product',
              onAction: () => _openForm(),
            ),
          );
        }

        final drops = products.where((product) => product.hasPriceDrop).length;
        final categories =
            products.map((product) => product.category).toSet().length;

        return AdminPageScaffold(
          header: _header(total: products.length, drops: drops),
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
                          label: 'Products',
                          value: '${products.length}',
                          icon: Icons.shopping_bag_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'On sale',
                          value: '$drops',
                          icon: Icons.trending_down_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Categories',
                          value: '$categories',
                          icon: Icons.category_rounded,
                          color: AppColors.pink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: 'All products',
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
                        '${products.length} '
                        '${products.length == 1 ? 'product' : 'products'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final product in products) ...[
                    _ProductTile(
                      product: product,
                      onEdit: () => _openForm(product),
                      onDelete: () => _delete(product),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasImage = product.imageUrl != null && product.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: product.hasPriceDrop
              ? AppColors.success.withValues(alpha: 0.45)
              : const Color(0x26A23CF0),
          width: product.hasPriceDrop ? 1.4 : 1,
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
                            child: hasImage
                                ? Image.network(
                                    CloudinaryService.optimizedUrl(
                                      product.imageUrl!,
                                      width: 200,
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) =>
                                        _placeholder(),
                                  )
                                : _placeholder(),
                          ),
                        ),
                        if (product.hasPriceDrop)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
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
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                product.formattedPrice,
                                style: textTheme.titleSmall?.copyWith(
                                  color: product.hasPriceDrop
                                      ? AppColors.success
                                      : AppColors.pink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (product.hasPriceDrop)
                                Text(
                                  Product.formatPrice(product.previousPrice!),
                                  style: textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Tag(
                                text: product.category,
                                background: AppColors.lavender,
                                foreground: AppColors.purple,
                              ),
                              if (product.fandom != null)
                                _Tag(
                                  text: product.fandom!,
                                  background: AppColors.softPink,
                                  foreground: AppColors.pink,
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
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        tooltip: 'Edit',
                        color: AppColors.primary,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        tooltip: 'Delete',
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

  Widget _placeholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.softGradient),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.purple,
          size: 30,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: foreground,
          fontWeight: FontWeight.w700,
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
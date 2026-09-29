import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cart_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/state_views.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Stream<List<CartItem>> _stream = CartService.instance.watchCart();

  void _retry() {
    setState(() => _stream = CartService.instance.watchCart());
  }

  Future<void> _changeQuantity(CartItem item, int quantity) async {
    if (quantity <= 0) {
      await _remove(item);
      return;
    }
    try {
      await CartService.instance.updateQuantity(item.id, quantity);
    } on CartException catch (e) {
      if (mounted) UiHelpers.showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update the quantity.',
          isError: true,
        );
      }
    }
  }

  Future<void> _remove(CartItem item) async {
    final ok = await UiHelpers.confirm(
      context,
      title: 'Remove item?',
      message: '"${item.name}" will be removed from your cart.',
      confirmText: 'Remove',
    );
    if (!ok) return;
    try {
      await CartService.instance.removeItem(item.id);
      if (mounted) UiHelpers.showSnack(context, 'Item removed from cart.');
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(context, 'Could not remove the item.',
            isError: true);
      }
    }
  }

  void _checkout(List<CartItem> items) {
    AppNavigator.push(context, CheckoutScreen(items: items));
  }

  Widget _page({required Widget body, int? itemCount, Widget? bottom}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CartHeader(itemCount: itemCount),
        Expanded(child: body),
        if (bottom != null) bottom,
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
        body: StreamBuilder<List<CartItem>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _page(
                body: ErrorView(
                  message: 'Could not load your cart.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _page(
                body: const LoadingView(message: 'Loading your cart...'),
              );
            }

            final items = snapshot.data!;
            if (items.isEmpty) {
              return _page(
                itemCount: 0,
                body: EmptyStateView(
                  icon: Icons.shopping_cart_outlined,
                  title: 'Your cart is empty',
                  message: 'Browse the Merch Store and add something you love.',
                  actionLabel: 'Continue shopping',
                  onAction: () => Navigator.of(context).pop(),
                ),
              );
            }

            final totalItems =
                items.fold<int>(0, (sum, item) => sum + item.quantity);
            final totalAmount =
                items.fold<double>(0, (sum, item) => sum + item.total);

            return _page(
              itemCount: totalItems,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _CartTile(
                        item: item,
                        onMinus: () => _changeQuantity(item, item.quantity - 1),
                        onPlus: () => _changeQuantity(item, item.quantity + 1),
                        onRemove: () => _remove(item),
                      );
                    },
                  ),
                ),
              ),
              bottom: _Summary(
                totalItems: totalItems,
                totalAmount: totalAmount,
                onCheckout: () => _checkout(items),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({this.itemCount});

  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final count = itemCount;
    final subtitle = count == null
        ? 'Your picks from the Merch Store'
        : count == 0
            ? 'Nothing added yet'
            : '$count ${count == 1 ? 'item' : 'items'} ready for checkout';

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
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 20),
              child: Row(
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Badge(
                      isLabelVisible: (count ?? 0) > 0,
                      backgroundColor: Colors.white,
                      textColor: AppColors.pink,
                      alignment: const AlignmentDirectional(0.55, -0.6),
                      label: Text(
                        '${count ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
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

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 86,
              height: 86,
              child: hasImage
                  ? Image.network(
                      CloudinaryService.optimizedUrl(item.imageUrl!,
                          width: 240),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onRemove,
                      child: Tooltip(
                        message: 'Remove',
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MiniTag(text: item.category),
                    if (item.selectedSize != null)
                      _MiniTag(text: 'Size ${item.selectedSize}'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedPrice} each',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoundIcon(
                              icon: Icons.remove_rounded, onTap: onMinus),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          _RoundIcon(
                            icon: Icons.add_rounded,
                            onTap: item.quantity < CartService.maxQuantity
                                ? onPlus
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _GradientText(
                      text: item.formattedTotal,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.purple),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.buttonGradient.createShader(bounds),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: enabled ? AppColors.buttonGradient : null,
        color: enabled ? null : Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? Colors.white
                  : AppColors.purple.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.totalItems,
    required this.totalAmount,
    required this.onCheckout,
  });

  final int totalItems;
  final double totalAmount;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F6C4DFF),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Items',
                    style: textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '$totalItems',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Total',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  _GradientText(
                    text: Product.formatPrice(totalAmount),
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Checkout',
                icon: Icons.receipt_long_rounded,
                onPressed: onCheckout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

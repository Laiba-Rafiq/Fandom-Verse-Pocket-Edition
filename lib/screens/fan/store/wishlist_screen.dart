import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/product.dart';
import '../../../models/wishlist_item.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/wishlist_service.dart';
import '../../../widgets/state_views.dart';
import '../fan_home_screen.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  late Stream<List<WishlistEntry>> _stream =
      WishlistService.instance.watchEntries();
  bool _marking = false;

  void _retry() {
    setState(() => _stream = WishlistService.instance.watchEntries());
  }

  void _markSeen(List<WishlistEntry> entries) {
    if (_marking) return;
    if (!entries.any((entry) => entry.hasNewAlert)) return;
    _marking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await WishlistService.instance.markAlertsSeen(entries);
      } catch (_) {
      } finally {
        _marking = false;
      }
    });
  }

  Future<void> _remove(WishlistEntry entry) async {
    try {
      await WishlistService.instance.removeFromWishlist(entry.item.productId);
      if (mounted) UiHelpers.showSnack(context, 'Removed from wishlist.');
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not remove the item. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _open(WishlistEntry entry) {
    final product = entry.product;
    if (product == null) {
      UiHelpers.showSnack(context, 'This product is no longer available.');
      return;
    }
    AppNavigator.push(context, ProductDetailScreen(product: product));
  }

  void _browseStore() {
    AppNavigator.backToRoot(context);
    FanTabs.open(FanTabs.store);
  }

  Widget _page({
    required Widget body,
    int? count,
    int drops = 0,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WishlistHeader(count: count, drops: drops),
        Expanded(child: body),
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
        body: StreamBuilder<List<WishlistEntry>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _page(
                body: ErrorView(
                  message: 'Could not load your wishlist.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _page(
                body: const LoadingView(message: 'Loading your wishlist...'),
              );
            }

            final entries = snapshot.data!;
            _markSeen(entries);

            if (entries.isEmpty) {
              return _page(
                count: 0,
                body: EmptyStateView(
                  icon: Icons.favorite_border_rounded,
                  title: 'Your wishlist is empty',
                  message: 'Tap the heart on any product to save it here. '
                      'We\'ll let you know when its price drops.',
                  actionLabel: 'Browse the store',
                  onAction: _browseStore,
                ),
              );
            }

            final drops = entries.where((entry) => entry.hasPriceDrop).length;

            return _page(
              count: entries.length,
              drops: drops,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      if (drops > 0) ...[
                        _PriceDropBanner(count: drops),
                        const SizedBox(height: 16),
                      ],
                      Row(
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
                          Text(
                            '${entries.length} saved '
                            '${entries.length == 1 ? 'item' : 'items'}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final entry in entries) ...[
                        _WishlistCard(
                          entry: entry,
                          onTap: () => _open(entry),
                          onRemove: () => _remove(entry),
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

class _WishlistHeader extends StatelessWidget {
  const _WishlistHeader({this.count, this.drops = 0});

  final int? count;
  final int drops;

  static const String _art = 'assets/images/categories/cat_wishlist.png';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 92.0 : 108.0;
    final saved = count;

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
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Wishlist',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Items you love. We alert you when prices drop.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (saved != null && saved > 0) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeaderChip(
                                      icon: Icons.favorite_rounded,
                                      label: '$saved saved',
                                    ),
                                    if (drops > 0)
                                      _HeaderChip(
                                        icon: Icons.trending_down_rounded,
                                        label: '$drops cheaper',
                                        color: AppColors.success,
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
                                semanticLabel: 'My Wishlist',
                                errorBuilder: (context, error, stack) => Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.white,
                                  size: artSize / 2.5,
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

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.color = AppColors.pink,
  });

  final IconData icon;
  final String label;
  final Color color;

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
          Icon(icon, size: 14, color: color),
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

class _PriceDropBanner extends StatelessWidget {
  const _PriceDropBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33F0357A)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40F0357A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
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
                      ? '1 item in your wishlist is cheaper now.'
                      : '$count items in your wishlist are cheaper now.',
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

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.entry,
    required this.onTap,
    required this.onRemove,
  });

  final WishlistEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final image = entry.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: entry.hasPriceDrop
              ? AppColors.success.withValues(alpha: 0.45)
              : const Color(0x26A23CF0),
          width: entry.hasPriceDrop ? 1.4 : 1,
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: image != null && image.isNotEmpty
                        ? Image.network(
                            CloudinaryService.optimizedUrl(image, width: 240),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lavender,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.item.category,
                          style: const TextStyle(
                            color: AppColors.purple,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!entry.isAvailable)
                        _Label(
                          text: 'No longer available',
                          background: colors.surfaceContainerHighest,
                          foreground: colors.outline,
                        )
                      else ...[
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              Product.formatPrice(entry.currentPrice),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: entry.hasPriceDrop
                                    ? AppColors.success
                                    : AppColors.pink,
                              ),
                            ),
                            if (entry.hasPriceDrop)
                              Text(
                                Product.formatPrice(entry.item.savedPrice),
                                style: textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        if (entry.hasPriceDrop) ...[
                          const SizedBox(height: 6),
                          _Label(
                            text:
                                '↓ ${Product.formatPrice(entry.dropAmount)} cheaper',
                            background: const Color(0x221FA971),
                            foreground: AppColors.success,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Material(
                  color: AppColors.softPink,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Remove from wishlist',
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.pink,
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

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: const Icon(Icons.shopping_bag_outlined, color: AppColors.purple),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

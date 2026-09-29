import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/product.dart';
import '../../../services/cart_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/wishlist_service.dart';
import '../../../widgets/app_button.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final Stream<bool> _wishlistStream =
      WishlistService.instance.watchIsWishlisted(widget.product.id);

  String? _selectedSize;
  String? _sizeError;
  int _quantity = 1;
  bool _adding = false;
  bool _wishlistBusy = false;

  Product get _product => widget.product;

  bool get _unavailable => _product.isApparel && _product.sizes.isEmpty;

  Future<void> _toggleWishlist(bool isWishlisted) async {
    if (_wishlistBusy) return;
    setState(() => _wishlistBusy = true);
    try {
      final added = await WishlistService.instance.toggle(
        _product,
        isWishlisted: isWishlisted,
      );
      if (!mounted) return;
      UiHelpers.showSnack(
        context,
        added
            ? 'Added to wishlist ❤️ We\'ll alert you if the price drops.'
            : 'Removed from wishlist.',
      );
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update your wishlist. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _wishlistBusy = false);
    }
  }

  Future<void> _addToCart() async {
    if (_product.isApparel && _selectedSize == null) {
      setState(() => _sizeError = 'Please select a size first.');
      UiHelpers.showSnack(context, 'Please select a size first.',
          isError: true);
      return;
    }

    setState(() => _adding = true);
    try {
      await CartService.instance.addToCart(
        _product,
        size: _selectedSize,
        quantity: _quantity,
      );
      if (!mounted) return;
      final sizeText = _selectedSize == null ? '' : ' (Size $_selectedSize)';
      UiHelpers.showSnack(context, 'Added to cart$sizeText!');
    } on CartException catch (e) {
      if (mounted) UiHelpers.showSnack(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not add to cart. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;
    final previous = _product.previousPrice;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    children: [
                      _ImageCarousel(images: _product.images),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x661F1147),
                                  Color(0x001F1147),
                                  Color(0x001F1147),
                                  Color(0x331F1147),
                                ],
                                stops: [0.0, 0.25, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: topInset + 8,
                        left: 12,
                        child: _GlassCircle(
                          tooltip: 'Back',
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        top: topInset + 8,
                        right: 12,
                        child: StreamBuilder<bool>(
                          stream: _wishlistStream,
                          builder: (context, snapshot) {
                            final isWishlisted = snapshot.data ?? false;
                            return _GlassCircle(
                              tooltip: isWishlisted
                                  ? 'Remove from wishlist'
                                  : 'Add to wishlist',
                              onTap: _wishlistBusy || !snapshot.hasData
                                  ? null
                                  : () => _toggleWishlist(isWishlisted),
                              filled: isWishlisted,
                              child: Icon(
                                isWishlisted
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isWishlisted
                                    ? AppColors.pink
                                    : Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -26),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0x33A23CF0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Tag(
                                text: _product.category,
                                icon: Icons.category_rounded,
                              ),
                              if (_product.fandom != null)
                                _Tag(
                                  text: _product.fandom!,
                                  icon: Icons.auto_awesome_rounded,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _product.name,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    (_product.hasPriceDrop
                                            ? const LinearGradient(
                                                colors: [
                                                  AppColors.success,
                                                  Color(0xFF12B886),
                                                ],
                                              )
                                            : AppColors.buttonGradient)
                                        .createShader(bounds),
                                child: Text(
                                  _product.formattedPrice,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (_product.hasPriceDrop &&
                                  previous != null) ...[
                                Text(
                                  Product.formatPrice(previous),
                                  style: textTheme.titleSmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.trending_down_rounded,
                                        size: 15,
                                        color: AppColors.success,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Price dropped',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          ..._categorySection(),
                          if (_product.description.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _SoftCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _SectionLabel(
                                    text: 'Description',
                                    icon: Icons.notes_rounded,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _product.description,
                                    style: textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F6C4DFF),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _QuantityStepper(
                    quantity: _quantity,
                    enabled: !_adding && !_unavailable,
                    onChanged: (value) => setState(() => _quantity = value),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: _unavailable
                          ? 'Currently unavailable'
                          : 'Add to Cart',
                      icon: Icons.add_shopping_cart_rounded,
                      isLoading: _adding,
                      onPressed: _unavailable ? null : _addToCart,
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

  List<Widget> _categorySection() {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    if (_product.isApparel) {
      return [
        const _SectionLabel(
          text: 'Select Size *',
          icon: Icons.straighten_rounded,
        ),
        const SizedBox(height: 12),
        if (_product.sizes.isEmpty)
          Text(
            'Sizes are not available for this product right now.',
            style: textTheme.bodyMedium,
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final size in _product.sizes)
                _SizeChip(
                  label: size,
                  selected: _selectedSize == size,
                  onTap: _adding
                      ? null
                      : () => setState(() {
                            _selectedSize = _selectedSize == size ? null : size;
                            if (_selectedSize != null) _sizeError = null;
                          }),
                ),
            ],
          ),
        if (_sizeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _sizeError!,
            style: textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ];
    }

    if (_product.isCollectible) {
      return [
        _SoftCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.toys_outlined,
                label: 'Collectible type',
                value: _product.collectibleType ?? 'Not specified',
              ),
              if (_product.edition != null) ...[
                const Divider(height: 22),
                _InfoRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Edition',
                  value: _product.edition!,
                ),
              ],
            ],
          ),
        ),
      ];
    }

    if (_product.isDigitalAsset) {
      return [
        _SoftCard(
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.image_outlined,
                label: 'Asset type',
                value: _product.digitalAssetType ?? 'Not specified',
              ),
              if (_product.characterSubject != null) ...[
                const Divider(height: 22),
                _InfoRow(
                  icon: Icons.face_outlined,
                  label: 'Character / Subject',
                  value: _product.characterSubject!,
                ),
              ],
            ],
          ),
        ),
      ];
    }

    return const [];
  }
}

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final images = widget.images;

    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.softGradient),
          child: const Icon(
            Icons.shopping_bag_outlined,
            size: 72,
            color: AppColors.purple,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => Image.network(
              CloudinaryService.optimizedUrl(images[index], width: 900),
              fit: BoxFit.cover,
              width: double.infinity,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: AppColors.lavender,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.pink),
                      ),
                    ),
              errorBuilder: (context, error, stack) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 56,
                  color: colors.outline,
                ),
              ),
            ),
          ),
          if (images.length > 1) ...[
            Positioned(
              right: 16,
              bottom: 36,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1}/${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.pink : Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minWidth: 56),
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.ink,
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

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease',
            icon: const Icon(Icons.remove, color: AppColors.purple),
            onPressed:
                enabled && quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          IconButton(
            tooltip: 'Increase',
            icon: const Icon(Icons.add, color: AppColors.purple),
            onPressed: enabled && quantity < CartService.maxQuantity
                ? () => onChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x126C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.purple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pink),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.icon});

  final String text;
  final IconData icon;

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
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
        ),
      ],
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({
    required this.tooltip,
    required this.onTap,
    required this.child,
    this.filled = false,
  });

  final String tooltip;
  final VoidCallback? onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.black.withValues(alpha: 0.28),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: child,
      ),
    );
  }
}

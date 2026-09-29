import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cart_service.dart';
import '../../../services/product_service.dart';
import '../../../widgets/product_card.dart';
import '../../../widgets/state_views.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';
import 'wishlist_screen.dart';

enum _SortOption { newest, priceLow, priceHigh }

class MerchStoreScreen extends StatefulWidget {
  const MerchStoreScreen({super.key});

  @override
  State<MerchStoreScreen> createState() => _MerchStoreScreenState();
}

class _MerchStoreScreenState extends State<MerchStoreScreen> {
  late Stream<List<Product>> _productsStream =
      ProductService.instance.watchProducts();

  final _searchController = TextEditingController();
  String _query = '';
  String? _category;
  String? _fandom;
  _SortOption _sort = _SortOption.newest;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _productsStream = ProductService.instance.watchProducts());
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = null;
      _fandom = null;
      _sort = _SortOption.newest;
    });
  }

  bool _matchesSearch(Product product) {
    if (_query.isEmpty) return true;
    final text = [
      product.name,
      product.description,
      product.category,
      product.fandom ?? '',
      product.collectibleType ?? '',
      product.digitalAssetType ?? '',
      product.characterSubject ?? '',
    ].join(' ').toLowerCase();
    return text.contains(_query.toLowerCase());
  }

  List<Product> _applyFilters(List<Product> products) {
    final result = products.where((product) {
      if (_category != null && product.category != _category) return false;
      if (_fandom != null && product.fandom != _fandom) return false;
      return _matchesSearch(product);
    }).toList();

    switch (_sort) {
      case _SortOption.priceLow:
        result.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHigh:
        result.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.newest:
        break;
    }
    return result;
  }

  String _sortLabel(_SortOption option) {
    switch (option) {
      case _SortOption.newest:
        return 'Newest';
      case _SortOption.priceLow:
        return 'Price: Low to High';
      case _SortOption.priceHigh:
        return 'Price: High to Low';
    }
  }

  void _openWishlist() {
    AppNavigator.push(context, const WishlistScreen());
  }

  void _openCart() {
    AppNavigator.push(context, const CartScreen());
  }

  Widget _stateBody(Widget child) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _StoreHero(onWishlist: _openWishlist, onCart: _openCart),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: SizedBox(height: 320, child: child),
        ),
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
        body: StreamBuilder<List<Product>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _stateBody(
                ErrorView(
                  message: 'Could not load the store.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _stateBody(
                const LoadingView(message: 'Loading merchandise...'),
              );
            }

            final allProducts = snapshot.data!;
            if (allProducts.isEmpty) {
              return _stateBody(
                const EmptyStateView(
                  icon: Icons.storefront_outlined,
                  title: 'The store is empty',
                  message: 'New official merchandise will appear here soon.',
                ),
              );
            }

            final fandoms = allProducts
                .map((product) => product.fandom)
                .whereType<String>()
                .toSet()
                .toList()
              ..sort();
            final products = _applyFilters(allProducts);

            final width = MediaQuery.of(context).size.width;
            final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: _StoreHero(
                    onWishlist: _openWishlist,
                    onCart: _openCart,
                    productCount: allProducts.length,
                    fandomCount: fandoms.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                        child: _SearchBox(
                          controller: _searchController,
                          query: _query,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                          onClear: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                      ),
                      _ChipRow(
                        allLabel: 'All',
                        icon: Icons.category_rounded,
                        options: Product.categories,
                        selected: _category,
                        onSelected: (value) =>
                            setState(() => _category = value),
                      ),
                      if (fandoms.isNotEmpty)
                        _ChipRow(
                          allLabel: 'All fandoms',
                          icon: Icons.auto_awesome_rounded,
                          options: fandoms,
                          selected: _fandom,
                          onSelected: (value) =>
                              setState(() => _fandom = value),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
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
                                '${products.length} '
                                '${products.length == 1 ? 'product' : 'products'}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                              ),
                            ),
                            PopupMenuButton<_SortOption>(
                              tooltip: 'Sort',
                              initialValue: _sort,
                              onSelected: (value) =>
                                  setState(() => _sort = value),
                              itemBuilder: (context) => [
                                for (final option in _SortOption.values)
                                  PopupMenuItem(
                                    value: option,
                                    child: Text(_sortLabel(option)),
                                  ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0x40A23CF0),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x146C4DFF),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.swap_vert_rounded,
                                      size: 18,
                                      color: AppColors.pink,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _sortLabel(_sort),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.purple,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.expand_more_rounded,
                                      size: 18,
                                      color: AppColors.purple,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: SizedBox(
                      height: 300,
                      child: EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No products found',
                        message: 'Try a different search or filter.',
                        actionLabel: 'Clear filters',
                        onAction: _clearFilters,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.56,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => AppNavigator.push(
                            context,
                            ProductDetailScreen(product: product),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.onWishlist,
    required this.onCart,
    this.productCount,
    this.fandomCount,
  });

  final VoidCallback onWishlist;
  final VoidCallback onCart;
  final int? productCount;
  final int? fandomCount;

  static const String _art = 'assets/images/categories/cat_merch_store.png';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 104.0 : 124.0;
    final canPop = Navigator.of(context).canPop();
    final products = productCount;
    final fandoms = fandomCount;

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
            const Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            const Positioned(
              bottom: -50,
              left: -40,
              child: _Bubble(size: 150, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          _GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        const Spacer(),
                        _GlassIconButton(
                          icon: Icons.favorite_border_rounded,
                          tooltip: 'My wishlist',
                          onTap: onWishlist,
                        ),
                        const SizedBox(width: 8),
                        _CartButton(onTap: onCart),
                      ],
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
                                'Merch Store',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Official merchandise for every fandom',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (products != null) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeroStat(
                                      icon: Icons.shopping_bag_rounded,
                                      label: '$products '
                                          '${products == 1 ? 'product' : 'products'}',
                                    ),
                                    if ((fandoms ?? 0) > 0)
                                      _HeroStat(
                                        icon: Icons.auto_awesome_rounded,
                                        label: '$fandoms '
                                            '${fandoms == 1 ? 'fandom' : 'fandoms'}',
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
                                semanticLabel: 'Merch Store',
                                errorBuilder: (context, error, stack) =>
                                    CircleAvatar(
                                  radius: artSize / 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.storefront_rounded,
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

class _CartButton extends StatefulWidget {
  const _CartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<_CartButton> {
  late final Stream<List<CartItem>> _cartStream =
      CartService.instance.watchCart();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CartItem>>(
      stream: _cartStream,
      builder: (context, snapshot) {
        final count = (snapshot.data ?? const <CartItem>[])
            .fold<int>(0, (sum, item) => sum + item.quantity);
        return _GlassIconButton(
          icon: Icons.shopping_cart_outlined,
          tooltip: 'My cart',
          onTap: widget.onTap,
          badge: count,
        );
      },
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: badge > 0,
          backgroundColor: Colors.white,
          textColor: AppColors.pink,
          label: Text(
            '$badge',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: Icon(icon, color: Colors.white),
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

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
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
          hintText: 'Search merchandise...',
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.purple),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0x33A23CF0)),
          ),
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.allLabel,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String allLabel;
  final IconData icon;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _PillChip(
            label: allLabel,
            icon: icon,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final option in options)
            _PillChip(
              label: option,
              selected: selected == option,
              onTap: () => onSelected(selected == option ? null : option),
            ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 15, color: AppColors.purple),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.ink,
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
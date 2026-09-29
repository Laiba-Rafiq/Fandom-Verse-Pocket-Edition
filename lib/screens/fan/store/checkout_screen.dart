import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../models/cart_item.dart';
import '../../../models/product.dart';
import '../../../models/shipping_details.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/order_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import 'bill_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<CartItem> items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.displayName ?? '',
  );
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  bool _placing = false;

  int get _totalItems =>
      widget.items.fold<int>(0, (sum, item) => sum + item.quantity);

  double get _subtotal =>
      widget.items.fold<double>(0, (sum, item) => sum + item.total);

  bool get _needsDelivery =>
      widget.items.any((item) => item.category != Product.digitalAssets);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String _cleanPhone(String value) {
    return value.replaceAll(RegExp(r'[\s\-()]'), '');
  }

  String? _validatePhone(String? value) {
    final phone = _cleanPhone(value ?? '');
    if (phone.isEmpty) return 'Please enter your phone number';
    if (!RegExp(r'^\+?\d{10,13}$').hasMatch(phone)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your address';
    if (text.length < 10) return 'Please enter your full address';
    return null;
  }

  String? _validateCity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your city';
    if (text.length < 2) return 'Please enter a valid city';
    return null;
  }

  Future<void> _placeOrder() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      UiHelpers.showSnack(
        context,
        'Please complete your delivery details.',
        isError: true,
      );
      return;
    }

    final shipping = ShippingDetails(
      fullName: _nameController.text.trim(),
      phone: _cleanPhone(_phoneController.text),
      address: _needsDelivery ? _addressController.text.trim() : null,
      city: _needsDelivery ? _cityController.text.trim() : null,
    );

    setState(() => _placing = true);
    try {
      final order = await OrderService.instance.placeOrder(
        widget.items,
        shipping: shipping,
      );
      if (!mounted) return;
      AppNavigator.replace(
        context,
        BillScreen(order: order, justPlaced: true),
      );
    } on OrderException catch (e) {
      if (mounted) {
        UiHelpers.showSnack(context, e.message, isError: true);
        setState(() => _placing = false);
      }
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not place your order. Please try again.',
          isError: true,
        );
        setState(() => _placing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CheckoutHeader(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            title: 'Order review',
                            icon: Icons.shopping_bag_rounded,
                            trailing: '$_totalItems '
                                '${_totalItems == 1 ? 'item' : 'items'}',
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < widget.items.length;
                                    i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 20,
                                      color: colors.outlineVariant,
                                    ),
                                  _ReviewRow(item: widget.items[i]),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Delivery details',
                            icon: Icons.local_shipping_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  controller: _nameController,
                                  label: 'Full name',
                                  icon: Icons.person_outline,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  validator: Validators.name,
                                  enabled: !_placing,
                                ),
                                const SizedBox(height: 14),
                                AppTextField(
                                  controller: _phoneController,
                                  label: 'Phone number',
                                  hint: 'e.g. 03001234567',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: _needsDelivery
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  validator: _validatePhone,
                                  enabled: !_placing,
                                ),
                                if (_needsDelivery) ...[
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _addressController,
                                    label: 'Address',
                                    hint: 'House no, street, area',
                                    icon: Icons.home_outlined,
                                    maxLines: 2,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: _validateAddress,
                                    enabled: !_placing,
                                  ),
                                  const SizedBox(height: 14),
                                  AppTextField(
                                    controller: _cityController,
                                    label: 'City',
                                    hint: 'e.g. Karachi',
                                    icon: Icons.location_city_outlined,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    validator: _validateCity,
                                    enabled: !_placing,
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  _NoteBox(
                                    icon: Icons.cloud_download_outlined,
                                    text: 'Your cart has only digital items, '
                                        'so no delivery address is needed.',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Payment summary',
                            icon: Icons.receipt_long_rounded,
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: 'Items',
                                  value: '$_totalItems',
                                ),
                                const SizedBox(height: 8),
                                _SummaryRow(
                                  label: 'Subtotal',
                                  value: Product.formatPrice(_subtotal),
                                ),
                                const SizedBox(height: 8),
                                const _SummaryRow(
                                  label: 'Delivery',
                                  value: 'Free',
                                  valueColor: AppColors.success,
                                ),
                                Divider(
                                  height: 26,
                                  color: colors.outlineVariant,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'TOTAL',
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.ink,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (bounds) => AppColors
                                          .buttonGradient
                                          .createShader(bounds),
                                      child: Text(
                                        Product.formatPrice(_subtotal),
                                        style:
                                            textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _NoteBox(
                            icon: Icons.info_outline_rounded,
                            text: 'Simulated checkout: placing this order will '
                                'generate your bill. No real payment or '
                                'delivery will happen.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.surface,
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
              child: AppButton(
                label: 'Place order · ${Product.formatPrice(_subtotal)}',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _placing,
                onPressed: _placeOrder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader();

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
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                              'Checkout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Review your order and add delivery details',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      _Step(
                          label: 'Cart', icon: Icons.check_rounded, done: true),
                      _StepLine(active: true),
                      _Step(
                          label: 'Details',
                          icon: Icons.edit_rounded,
                          current: true),
                      _StepLine(active: false),
                      _Step(label: 'Bill', icon: Icons.receipt_rounded),
                    ],
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

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.icon,
    this.done = false,
    this.current = false,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final highlighted = done || current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highlighted
                ? Colors.white
                : Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: Colors.white.withValues(alpha: highlighted ? 1 : 0.35),
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: highlighted ? AppColors.pink : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: highlighted ? 1 : 0.75),
            fontSize: 11.5,
            fontWeight: current ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.9 : 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final extra = trailing;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
              ),
              if (extra != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    extra,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${item.quantity}×',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  item.category,
                  if (item.selectedSize != null) 'Size ${item.selectedSize}',
                  '${item.quantity} × ${item.formattedPrice}',
                ].join(' · '),
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          item.formattedTotal,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: textTheme.bodyMedium)),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

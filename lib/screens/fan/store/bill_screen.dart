import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import '../../../models/purchase_order.dart';
import '../../../routes/app_navigator.dart';
import '../../../widgets/app_button.dart';

class BillScreen extends StatelessWidget {
  const BillScreen({
    super.key,
    required this.order,
    this.justPlaced = false,
    this.showCustomer = false,
  });

  final PurchaseOrder order;
  final bool justPlaced;
  final bool showCustomer;

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '${date.day} ${months[date.month - 1]} ${date.year}, '
        '$hour12:$minute $period';
  }

  static Color statusColor(String status) {
    switch (status) {
      case PurchaseOrder.statusProcessing:
        return AppColors.warning;
      case PurchaseOrder.statusShipped:
        return const Color(0xFF3867D6);
      case PurchaseOrder.statusDelivered:
        return AppColors.success;
      case PurchaseOrder.statusCancelled:
        return const Color(0xFFE5484D);
      default:
        return AppColors.purple;
    }
  }

  static IconData statusIcon(String status) {
    switch (status) {
      case PurchaseOrder.statusProcessing:
        return Icons.settings_rounded;
      case PurchaseOrder.statusShipped:
        return Icons.local_shipping_rounded;
      case PurchaseOrder.statusDelivered:
        return Icons.check_circle_rounded;
      case PurchaseOrder.statusCancelled:
        return Icons.cancel_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shipping = order.shipping;
    final color = statusColor(order.status);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BillHeader(order: order, justPlaced: justPlaced),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0x26A23CF0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A6C4DFF),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: AppColors.buttonGradient,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'FANDOM VERSE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'BILL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _KeyValue(
                                      label: 'Order No',
                                      value: order.orderNumber,
                                    ),
                                    const SizedBox(height: 8),
                                    _KeyValue(
                                      label: 'Date',
                                      value: formatDate(order.createdAt),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Status',
                                          style: textTheme.bodyMedium,
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                statusIcon(order.status),
                                                size: 14,
                                                color: color,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                order.statusLabel,
                                                style: TextStyle(
                                                  color: color,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (showCustomer) ...[
                                      const SizedBox(height: 8),
                                      _KeyValue(
                                        label: 'Customer',
                                        value: order.customerName ?? 'Unknown',
                                      ),
                                      const SizedBox(height: 8),
                                      _KeyValue(
                                        label: 'Email',
                                        value: order.customerEmail ?? '-',
                                      ),
                                    ],
                                    if (shipping != null) ...[
                                      const SizedBox(height: 16),
                                      const _DashedLine(),
                                      const SizedBox(height: 16),
                                      const _BlockTitle(
                                        text: 'DELIVERY DETAILS',
                                        icon: Icons.local_shipping_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      _KeyValue(
                                        label: 'Name',
                                        value: shipping.fullName,
                                      ),
                                      const SizedBox(height: 8),
                                      _KeyValue(
                                        label: 'Phone',
                                        value: shipping.phone,
                                      ),
                                      if (shipping.address != null) ...[
                                        const SizedBox(height: 8),
                                        _KeyValue(
                                          label: 'Address',
                                          value: shipping.address!,
                                        ),
                                      ],
                                      if (shipping.city != null) ...[
                                        const SizedBox(height: 8),
                                        _KeyValue(
                                          label: 'City',
                                          value: shipping.city!,
                                        ),
                                      ],
                                    ],
                                    const SizedBox(height: 16),
                                    const _DashedLine(),
                                    const SizedBox(height: 16),
                                    const _BlockTitle(
                                      text: 'ITEMS',
                                      icon: Icons.shopping_bag_rounded,
                                    ),
                                    const SizedBox(height: 12),
                                    for (final line in order.items) ...[
                                      _BillLine(line: line),
                                      const SizedBox(height: 12),
                                    ],
                                    const _DashedLine(),
                                    const SizedBox(height: 14),
                                    _KeyValue(
                                      label: 'Items',
                                      value: '${order.totalQuantity}',
                                    ),
                                    const SizedBox(height: 8),
                                    _KeyValue(
                                      label: 'Subtotal',
                                      value: order.formattedSubtotal,
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.softGradient,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'TOTAL',
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.ink,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          ShaderMask(
                                            blendMode: BlendMode.srcIn,
                                            shaderCallback: (bounds) =>
                                                AppColors.buttonGradient
                                                    .createShader(bounds),
                                            child: Text(
                                              order.formattedTotal,
                                              style: textTheme.headlineSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
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
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppColors.softGradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x26A23CF0)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: AppColors.purple,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This is a simulated checkout. No payment '
                                  'was charged and no delivery will be made.',
                                  style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (justPlaced) ...[
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Back to Store',
                            icon: Icons.storefront_rounded,
                            onPressed: () => AppNavigator.backToRoot(context),
                          ),
                        ],
                      ],
                    ),
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

class _BillHeader extends StatelessWidget {
  const _BillHeader({required this.order, required this.justPlaced});

  final PurchaseOrder order;
  final bool justPlaced;

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
            Positioned(
              bottom: -60,
              left: -40,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 24),
              child: justPlaced
                  ? Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.45),
                                blurRadius: 26,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppColors.success,
                            size: 46,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Order placed!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Here is your bill · ${order.orderNumber}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Row(
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
                                'Bill',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.orderNumber,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            Icons.receipt_long_rounded,
                            color: Colors.white,
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

class _BlockTitle extends StatelessWidget {
  const _BlockTitle({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.pink),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: AppColors.purple,
              ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 6.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: dash,
                height: 1.5,
                color: const Color(0x40A23CF0),
              ),
          ],
        );
      },
    );
  }
}

class _BillLine extends StatelessWidget {
  const _BillLine({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final details = [
      line.category,
      if (line.selectedSize != null) 'Size ${line.selectedSize}',
      '${line.quantity} × ${Product.formatPrice(line.price)}',
    ].join(' · ');

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
            '${line.quantity}×',
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
                line.name,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(details, style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          Product.formatPrice(line.total),
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(width: 16),
        Expanded(
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

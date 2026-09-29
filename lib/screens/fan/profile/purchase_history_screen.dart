import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product.dart';
import '../../../models/purchase_order.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/order_service.dart';
import '../../../widgets/state_views.dart';
import '../store/bill_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late Stream<List<PurchaseOrder>> _stream =
      OrderService.instance.watchOrders();

  void _retry() {
    setState(() => _stream = OrderService.instance.watchOrders());
  }

  Widget _page({required Widget body, List<PurchaseOrder>? orders}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryHeader(orders: orders),
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
        body: StreamBuilder<List<PurchaseOrder>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _page(
                body: ErrorView(
                  message: 'Could not load your orders.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _page(
                body: const LoadingView(message: 'Loading your orders...'),
              );
            }

            final orders = snapshot.data!;
            if (orders.isEmpty) {
              return _page(
                orders: orders,
                body: const EmptyStateView(
                  icon: Icons.receipt_long_outlined,
                  title: 'No purchases yet',
                  message:
                      'Bills from your simulated checkouts will appear here.',
                ),
              );
            }

            return _page(
              orders: orders,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _OrderTile(
                        order: order,
                        onTap: () => AppNavigator.push(
                          context,
                          BillScreen(order: order),
                        ),
                      );
                    },
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

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({this.orders});

  final List<PurchaseOrder>? orders;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final list = orders;
    final canPop = Navigator.of(context).canPop();
    final active = list?.where((order) => !order.isCancelled).toList();
    final spent =
        active?.fold<double>(0, (sum, order) => sum + order.total) ?? 0;
    final delivered = list?.where((order) => order.isDelivered).length ?? 0;

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
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (canPop) ...[
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
                      ] else
                        const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Purchase History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your orders, bills and delivery status',
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
                  if (list != null && list.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            value: '${list.length}',
                            label: list.length == 1 ? 'Order' : 'Orders',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatBox(
                            value: '$delivered',
                            label: 'Delivered',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _StatBox(
                            value: Product.formatPrice(spent),
                            label: 'Total spent',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});

  final PurchaseOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = BillScreen.statusColor(order.status);

    final firstName = order.items.isNotEmpty ? order.items.first.name : '';
    final more = order.items.length - 1;
    final summary = more > 0 ? '$firstName + $more more' : firstName;

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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        BillScreen.statusIcon(order.status),
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
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
                                  BillScreen.formatDate(order.createdAt),
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
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) =>
                              AppColors.buttonGradient.createShader(bounds),
                          child: Text(
                            order.formattedTotal,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.statusLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.softGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 16,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${order.totalQuantity} '
                        '${order.totalQuantity == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (order.isCancelled)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5484D).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFFE5484D),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This order was cancelled.',
                            style: TextStyle(
                              color: Color(0xFFE5484D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _OrderTracker(stage: order.stage),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View bill',
                        style: textTheme.labelLarge?.copyWith(
                          color: AppColors.pink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.pink,
                      ),
                    ],
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

class _OrderTracker extends StatelessWidget {
  const _OrderTracker({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = PurchaseOrder.flow;
    final inactive = colors.outlineVariant;

    return Semantics(
      label: 'Order progress: ${PurchaseOrder.labelFor(steps[stage])}',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: i <= stage ? AppColors.buttonGradient : null,
                    color: i <= stage ? null : colors.surface,
                    border: i <= stage
                        ? null
                        : Border.all(color: inactive, width: 2),
                    boxShadow: i == stage
                        ? const [
                            BoxShadow(
                              color: Color(0x55F0357A),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: i < stage
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: i < stage ? AppColors.buttonGradient : null,
                        color: i < stage ? null : inactive,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Text(
                    PurchaseOrder.labelFor(steps[i]),
                    textAlign: i == 0
                        ? TextAlign.left
                        : (i == steps.length - 1
                            ? TextAlign.right
                            : TextAlign.center),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          i == stage ? FontWeight.w900 : FontWeight.w500,
                      color: i <= stage ? AppColors.pink : colors.outline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

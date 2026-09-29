import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/product.dart';
import '../../../models/purchase_order.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/order_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/state_views.dart';
import '../../fan/store/bill_screen.dart';
import '../widgets/admin_ui.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  late Stream<List<PurchaseOrder>> _stream =
      OrderService.instance.watchAllOrders();
  final Map<String, Future<PurchaseOrder>> _resolved = {};
  final Set<String> _updating = <String>{};
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = OrderService.instance.watchAllOrders());
  }

  String _keyOf(PurchaseOrder order) => '${order.userId}_${order.id}';

  Future<PurchaseOrder> _withCustomer(PurchaseOrder order) {
    if (order.hasCustomerInfo || order.userId == null) {
      return Future.value(order);
    }
    final key = _keyOf(order);
    return _resolved.putIfAbsent(key, () async {
      try {
        final user = await UserService.instance.getUser(order.userId!);
        if (user == null) return order;
        return order.copyWithCustomer(name: user.name, email: user.email);
      } catch (_) {
        return order;
      }
    });
  }

  bool _matches(PurchaseOrder order) {
    if (_query.isEmpty) return true;
    final shipping = order.shipping;
    final text = [
      order.orderNumber,
      order.customerName ?? '',
      order.customerEmail ?? '',
      shipping?.fullName ?? '',
      shipping?.phone ?? '',
      shipping?.city ?? '',
      order.statusLabel,
    ].join(' ').toLowerCase();
    return text.contains(_query.toLowerCase());
  }

  Future<void> _changeStatus(PurchaseOrder order, String newStatus) async {
    final cancelling = newStatus == PurchaseOrder.statusCancelled;
    final label = PurchaseOrder.labelFor(newStatus);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          cancelling ? 'Cancel order ${order.orderNumber}?' : 'Mark as $label?',
        ),
        content: Text(
          cancelling
              ? "This can't be undone. The customer will be notified."
              : 'Order ${order.orderNumber} will be marked as $label. '
                  'The customer will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cancelling ? AppColors.warning : null,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(cancelling ? 'Cancel order' : 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final key = _keyOf(order);
    setState(() => _updating.add(key));
    try {
      await OrderService.instance.updateStatus(order, newStatus);
      if (mounted) {
        UiHelpers.showSnack(
          context,
          cancelling
              ? 'Order ${order.orderNumber} cancelled. '
                  'The customer has been notified.'
              : 'Order ${order.orderNumber} marked as $label. '
                  'The customer has been notified.',
        );
      }
    } on OrderException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update the order. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(key));
    }
  }

  Widget _header({int? total, int active = 0}) {
    return AdminPageHeader(
      title: 'Orders',
      subtitle: 'Track fans\' simulated orders and update their status.',
      icon: Icons.receipt_long_rounded,
      chips: [
        if (total != null) ...[
          AdminHeaderChip(
            icon: Icons.receipt_long_rounded,
            label: '$total ${total == 1 ? 'order' : 'orders'}',
            color: AppColors.primary,
          ),
          AdminHeaderChip(
            icon: Icons.pending_actions_rounded,
            label: '$active active',
            color: AppColors.warning,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PurchaseOrder>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            body: ErrorView(
              message: 'Could not load orders.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            body: const LoadingView(message: 'Loading orders...'),
          );
        }

        final allOrders = snapshot.data!;
        if (allOrders.isEmpty) {
          return AdminPageScaffold(
            header: _header(total: 0),
            body: const EmptyStateView(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message:
                  'Orders from fans\' simulated checkouts will appear here.',
            ),
          );
        }

        final orders = allOrders.where(_matches).toList();
        final totalAmount = allOrders.fold<double>(
          0,
          (running, order) => running + order.total,
        );
        final totalItems = allOrders.fold<int>(
          0,
          (running, order) => running + order.totalQuantity,
        );
        final active = allOrders.where((order) => !order.isFinal).length;

        return AdminPageScaffold(
          header: _header(total: allOrders.length, active: active),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminStatBox(
                          label: 'Orders',
                          value: '${allOrders.length}',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Items',
                          value: '$totalItems',
                          icon: Icons.inventory_2_rounded,
                          color: AppColors.pink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Total (simulated)',
                          value: Product.formatPrice(totalAmount),
                          icon: Icons.payments_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminSearchField(
                    controller: _searchController,
                    hint: 'Search by order no, name, phone, city or status...',
                    query: _query,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: _query.isEmpty ? 'All orders' : 'Search results',
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
                        '${orders.length} '
                        '${orders.length == 1 ? 'order' : 'orders'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    const AdminEmptyNote(
                      icon: Icons.search_off_rounded,
                      text: 'No matching orders.\n'
                          'Try a different order number, name, phone or city.',
                    )
                  else
                    for (final order in orders) ...[
                      FutureBuilder<PurchaseOrder>(
                        future: _withCustomer(order),
                        initialData: order,
                        builder: (context, snap) {
                          final resolved = snap.data ?? order;
                          final next = resolved.nextStatus;
                          return _AdminOrderTile(
                            order: resolved,
                            updating: _updating.contains(_keyOf(resolved)),
                            onTap: () => AppNavigator.push(
                              context,
                              BillScreen(order: resolved, showCustomer: true),
                            ),
                            onAdvance: next == null
                                ? null
                                : () => _changeStatus(resolved, next),
                            onCancel: resolved.canCancel
                                ? () => _changeStatus(
                                      resolved,
                                      PurchaseOrder.statusCancelled,
                                    )
                                : null,
                          );
                        },
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  static Color colorFor(String status) {
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

  static IconData iconFor(String status) {
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
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            PurchaseOrder.labelFor(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminOrderTile extends StatelessWidget {
  const _AdminOrderTile({
    required this.order,
    required this.updating,
    required this.onTap,
    required this.onAdvance,
    required this.onCancel,
  });

  final PurchaseOrder order;
  final bool updating;
  final VoidCallback onTap;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = order.customerName ?? 'Loading customer...';
    final shipping = order.shipping;
    final next = order.nextStatus;
    final statusColor = _StatusPill.colorFor(order.status);

    final contactParts = <String>[
      if (shipping != null && shipping.phone.isNotEmpty) shipping.phone,
      if (shipping?.city != null) shipping!.city!,
    ];

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
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: ColoredBox(color: statusColor),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            _StatusPill.iconFor(order.status),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _StatusPill(status: order.status),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.formattedTotal,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.pink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lavender.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.person_outline,
                            color: AppColors.purple,
                            text: order.customerEmail == null
                                ? name
                                : '$name · ${order.customerEmail}',
                          ),
                          if (contactParts.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _InfoRow(
                              icon: Icons.local_shipping_outlined,
                              color: AppColors.purple,
                              text: contactParts.join(' · '),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _InfoRow(
                                  icon: Icons.schedule,
                                  color: colors.outline,
                                  small: true,
                                  text:
                                      '${BillScreen.formatDate(order.createdAt)} · '
                                      '${order.totalQuantity} '
                                      '${order.totalQuantity == 1 ? 'item' : 'items'}',
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.purple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!order.isFinal) ...[
                      const SizedBox(height: 12),
                      if (updating)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            if (next != null)
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _StatusPill.colorFor(next),
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: onAdvance,
                                  icon: Icon(
                                    _StatusPill.iconFor(next),
                                    size: 18,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Mark as '
                                      '${PurchaseOrder.labelFor(next)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (next != null && onCancel != null)
                              const SizedBox(width: 8),
                            if (onCancel != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE5484D),
                                  side: const BorderSide(
                                    color: Color(0x66E5484D),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: onCancel,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
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
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
    this.small = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small
                ? textTheme.bodySmall
                : textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_item.dart';
import 'product.dart';
import 'shipping_details.dart';

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.category,
    this.selectedSize,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String category;
  final String? selectedSize;
  final String? imageUrl;

  double get total => price * quantity;

  factory OrderLine.fromCartItem(CartItem item) {
    return OrderLine(
      productId: item.productId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      category: item.category,
      selectedSize: item.selectedSize,
      imageUrl: item.imageUrl,
    );
  }

  factory OrderLine.fromMap(Map<String, dynamic> data) {
    final size = data['selectedSize'];
    return OrderLine(
      productId: (data['productId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      category: (data['category'] as String?) ?? '',
      selectedSize: size is String && size.isNotEmpty ? size : null,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'category': category,
      'imageUrl': imageUrl,
      if (selectedSize != null) 'selectedSize': selectedSize,
    };
  }
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.items,
    required this.subtotal,
    required this.total,
    required this.status,
    this.createdAt,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.shipping,
  });

  static const String simulatedStatus = 'Simulated';
  static const String statusProcessing = 'Processing';
  static const String statusShipped = 'Shipped';
  static const String statusDelivered = 'Delivered';
  static const String statusCancelled = 'Cancelled';

  static const List<String> flow = [
    simulatedStatus,
    statusProcessing,
    statusShipped,
    statusDelivered,
  ];

  final String id;
  final String orderNumber;
  final List<OrderLine> items;
  final double subtotal;
  final double total;
  final String status;
  final DateTime? createdAt;
  final String? userId;
  final String? customerName;
  final String? customerEmail;
  final ShippingDetails? shipping;

  int get totalQuantity =>
      items.fold<int>(0, (runningTotal, item) => runningTotal + item.quantity);

  String get formattedTotal => Product.formatPrice(total);
  String get formattedSubtotal => Product.formatPrice(subtotal);

  bool get hasCustomerInfo =>
      (customerName != null && customerName!.isNotEmpty) ||
      (customerEmail != null && customerEmail!.isNotEmpty);

  static String labelFor(String status) {
    if (status == simulatedStatus) return 'Placed';
    return status;
  }

  String get statusLabel => labelFor(status);

  bool get isCancelled => status == statusCancelled;

  bool get isDelivered => status == statusDelivered;

  bool get isFinal => isCancelled || isDelivered;

  int get stage {
    final index = flow.indexOf(status);
    return index < 0 ? 0 : index;
  }

  String? get nextStatus {
    if (isFinal) return null;
    final next = stage + 1;
    return next < flow.length ? flow[next] : null;
  }

  bool get canCancel => !isFinal && stage < flow.indexOf(statusShipped);

  PurchaseOrder copyWithCustomer({String? name, String? email}) {
    return PurchaseOrder(
      id: id,
      orderNumber: orderNumber,
      items: items,
      subtotal: subtotal,
      total: total,
      status: status,
      createdAt: createdAt,
      userId: userId,
      customerName: name ?? customerName,
      customerEmail: email ?? customerEmail,
      shipping: shipping,
    );
  }

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  factory PurchaseOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => OrderLine.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : <OrderLine>[];

    return PurchaseOrder(
      id: doc.id,
      orderNumber: (data['orderNumber'] as String?) ?? doc.id,
      items: items,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      status: (data['status'] as String?) ?? simulatedStatus,
      createdAt: created is Timestamp ? created.toDate() : null,
      userId: _text(data['userId']) ?? doc.reference.parent.parent?.id,
      customerName: _text(data['customerName']),
      customerEmail: _text(data['customerEmail']),
      shipping: ShippingDetails.fromMap(data['shipping']),
    );
  }
}

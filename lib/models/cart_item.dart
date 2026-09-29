import 'package:cloud_firestore/cloud_firestore.dart';

import 'product.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.category,
    required this.quantity,
    this.imageUrl,
    this.selectedSize,
    this.addedAt,
  });

  final String id;
  final String productId;
  final String name;
  final double price;
  final String category;
  final int quantity;
  final String? imageUrl;
  final String? selectedSize;
  final DateTime? addedAt;

  double get total => price * quantity;

  String get formattedPrice => Product.formatPrice(price);
  String get formattedTotal => Product.formatPrice(total);

  static String buildId(String productId, String? size) {
    return '${productId}_${size ?? 'none'}';
  }

  factory CartItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final added = data['addedAt'];
    final size = data['selectedSize'];
    return CartItem(
      id: doc.id,
      productId: (data['productId'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      category: (data['category'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: data['imageUrl'] as String?,
      selectedSize: size is String && size.isNotEmpty ? size : null,
      addedAt: added is Timestamp ? added.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'category': category,
      'quantity': quantity,
      'imageUrl': imageUrl,
      if (selectedSize != null) 'selectedSize': selectedSize,
    };
  }
}

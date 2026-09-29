import 'package:cloud_firestore/cloud_firestore.dart';

import 'product.dart';

class WishlistItem {
  const WishlistItem({
    required this.productId,
    required this.name,
    required this.savedPrice,
    required this.category,
    this.imageUrl,
    this.savedAt,
    this.alertSeenPrice,
  });

  final String productId;
  final String name;
  final double savedPrice;
  final String category;
  final String? imageUrl;
  final DateTime? savedAt;
  final double? alertSeenPrice;

  factory WishlistItem.fromProduct(Product product) {
    return WishlistItem(
      productId: product.id,
      name: product.name,
      savedPrice: product.price,
      category: product.category,
      imageUrl: product.coverImage,
    );
  }

  factory WishlistItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final saved = data['savedAt'];
    final seen = data['alertSeenPrice'];
    return WishlistItem(
      productId: (data['productId'] as String?) ?? doc.id,
      name: (data['name'] as String?) ?? '',
      savedPrice: (data['savedPrice'] as num?)?.toDouble() ?? 0,
      category: (data['category'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      savedAt: saved is Timestamp ? saved.toDate() : null,
      alertSeenPrice: seen is num ? seen.toDouble() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'savedPrice': savedPrice,
      'category': category,
      'imageUrl': imageUrl,
    };
  }
}

class WishlistEntry {
  const WishlistEntry({required this.item, this.product});

  final WishlistItem item;
  final Product? product;

  bool get isAvailable => product != null;

  double get currentPrice => product?.price ?? item.savedPrice;

  bool get hasPriceDrop => product != null && product!.price < item.savedPrice;

  bool get hasNewAlert {
    if (!hasPriceDrop) return false;
    final seen = item.alertSeenPrice;
    return seen == null || product!.price < seen;
  }

  double get dropAmount => hasPriceDrop ? item.savedPrice - product!.price : 0;

  String get name => product?.name ?? item.name;

  String? get imageUrl => product?.coverImage ?? item.imageUrl;
}

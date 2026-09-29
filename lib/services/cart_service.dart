import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartException implements Exception {
  const CartException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CartService {
  CartService._();
  static final CartService instance = CartService._();

  static const int maxQuantity = 10;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cartRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const CartException('Please log in to use the cart.');
    }
    return _db.collection('users').doc(uid).collection('cart');
  }

  Stream<List<CartItem>> watchCart() {
    return _cartRef().orderBy('addedAt').snapshots().map(
          (snapshot) => snapshot.docs.map(CartItem.fromDoc).toList(),
        );
  }

  Future<void> addToCart(
    Product product, {
    String? size,
    int quantity = 1,
  }) async {
    if (product.isApparel && (size == null || size.isEmpty)) {
      throw const CartException('Please select a size first.');
    }
    if (product.isApparel && !product.sizes.contains(size)) {
      throw const CartException('This size is not available.');
    }
    final cleanSize = product.isApparel ? size : null;
    final id = CartItem.buildId(product.id, cleanSize);
    final doc = _cartRef().doc(id);

    final existing = await doc.get();
    final currentQuantity =
        (existing.data()?['quantity'] as num?)?.toInt() ?? 0;
    final newQuantity = currentQuantity + quantity;
    if (newQuantity > maxQuantity) {
      throw const CartException(
        'You can add up to $maxQuantity of the same item.',
      );
    }

    final item = CartItem(
      id: id,
      productId: product.id,
      name: product.name,
      price: product.price,
      category: product.category,
      quantity: newQuantity,
      imageUrl: product.coverImage,
      selectedSize: cleanSize,
    );

    final data = item.toMap();
    if (!existing.exists) {
      data['addedAt'] = FieldValue.serverTimestamp();
    }
    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(itemId);
      return;
    }
    if (quantity > maxQuantity) {
      throw const CartException(
        'You can add up to $maxQuantity of the same item.',
      );
    }
    await _cartRef().doc(itemId).update({'quantity': quantity});
  }

  Future<void> removeItem(String itemId) {
    return _cartRef().doc(itemId).delete();
  }

  Future<void> clearCart() async {
    final ref = _cartRef();
    final snapshot = await ref.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

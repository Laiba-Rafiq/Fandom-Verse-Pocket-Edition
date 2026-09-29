import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../models/wishlist_item.dart';
import 'product_service.dart';

class WishlistException implements Exception {
  const WishlistException(this.message);
  final String message;

  @override
  String toString() => message;
}

class WishlistService {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _wishlistRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const WishlistException('Please log in to use your wishlist.');
    }
    return _db.collection('users').doc(uid).collection('wishlist');
  }

  Stream<List<WishlistItem>> watchWishlist() {
    return _wishlistRef().orderBy('savedAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(WishlistItem.fromDoc).toList(),
        );
  }

  Stream<bool> watchIsWishlisted(String productId) {
    return _wishlistRef().doc(productId).snapshots().map((doc) => doc.exists);
  }

  Future<void> addToWishlist(Product product) {
    final data = WishlistItem.fromProduct(product).toMap();
    data['savedAt'] = FieldValue.serverTimestamp();
    return _wishlistRef().doc(product.id).set(data);
  }

  Future<void> removeFromWishlist(String productId) {
    return _wishlistRef().doc(productId).delete();
  }

  Future<bool> toggle(Product product, {required bool isWishlisted}) async {
    if (isWishlisted) {
      await removeFromWishlist(product.id);
      return false;
    }
    await addToWishlist(product);
    return true;
  }

  Stream<List<WishlistEntry>> watchEntries() {
    late StreamController<List<WishlistEntry>> controller;
    StreamSubscription<List<WishlistItem>>? wishlistSub;
    StreamSubscription<List<Product>>? productsSub;
    List<WishlistItem>? latestItems;
    List<Product>? latestProducts;

    void emit() {
      final items = latestItems;
      final products = latestProducts;
      if (items == null || products == null) return;
      final byId = {for (final product in products) product.id: product};
      controller.add([
        for (final item in items)
          WishlistEntry(item: item, product: byId[item.productId]),
      ]);
    }

    controller = StreamController<List<WishlistEntry>>(
      onListen: () {
        wishlistSub = watchWishlist().listen(
          (items) {
            latestItems = items;
            emit();
          },
          onError: controller.addError,
        );
        productsSub = ProductService.instance.watchProducts().listen(
          (products) {
            latestProducts = products;
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await wishlistSub?.cancel();
        await productsSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<List<WishlistEntry>> watchPriceDrops() {
    return watchEntries().map(
      (entries) => entries.where((entry) => entry.hasNewAlert).toList(),
    );
  }

  Future<void> markAlertsSeen(List<WishlistEntry> entries) async {
    final fresh = entries.where((entry) => entry.hasNewAlert).toList();
    if (fresh.isEmpty) return;

    final ref = _wishlistRef();
    final batch = _db.batch();
    for (final entry in fresh) {
      batch.update(ref.doc(entry.item.productId), {
        'alertSeenPrice': entry.product!.price,
      });
    }
    await batch.commit();
  }
}

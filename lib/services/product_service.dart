import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  static const String merchandiseCollection = 'merchandise';

  final CollectionReference<Map<String, dynamic>> _products =
      FirebaseFirestore.instance.collection(merchandiseCollection);

  Stream<List<Product>> watchProducts() {
    return _products.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(Product.fromDoc).toList(),
        );
  }

  Future<void> addProduct({
    required String name,
    required double price,
    required String category,
    required List<String> images,
    String description = '',
    String? fandom,
    List<String> sizes = const [],
    String? collectibleType,
    String? edition,
    String? digitalAssetType,
    String? characterSubject,
  }) {
    final data = _buildData(
      name: name,
      price: price,
      category: category,
      images: images,
      description: description,
      fandom: fandom,
      sizes: sizes,
      collectibleType: collectibleType,
      edition: edition,
      digitalAssetType: digitalAssetType,
      characterSubject: characterSubject,
      forUpdate: false,
    );
    data['previousPrice'] = null;
    data['createdAt'] = FieldValue.serverTimestamp();
    return _products.add(data);
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required double price,
    required String category,
    required List<String> images,
    String description = '',
    String? fandom,
    List<String> sizes = const [],
    String? collectibleType,
    String? edition,
    String? digitalAssetType,
    String? characterSubject,
  }) async {
    final doc = _products.doc(id);
    final current = await doc.get();
    final oldPrice = (current.data()?['price'] as num?)?.toDouble();

    final data = _buildData(
      name: name,
      price: price,
      category: category,
      images: images,
      description: description,
      fandom: fandom,
      sizes: sizes,
      collectibleType: collectibleType,
      edition: edition,
      digitalAssetType: digitalAssetType,
      characterSubject: characterSubject,
      forUpdate: true,
    );
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (oldPrice != null && price < oldPrice) {
      data['previousPrice'] = oldPrice;
      data['priceDroppedAt'] = FieldValue.serverTimestamp();
    } else if (oldPrice != null && price > oldPrice) {
      data['previousPrice'] = null;
    }

    await doc.update(data);
  }

  Future<void> deleteProduct(String id) {
    return _products.doc(id).delete();
  }

  Map<String, dynamic> _buildData({
    required String name,
    required double price,
    required String category,
    required List<String> images,
    required String description,
    required String? fandom,
    required List<String> sizes,
    required String? collectibleType,
    required String? edition,
    required String? digitalAssetType,
    required String? characterSubject,
    required bool forUpdate,
  }) {
    final cover = images.isNotEmpty ? images.first : null;

    final data = <String, dynamic>{
      'name': name.trim(),
      'price': price,
      'category': category,
      'description': description.trim(),
      'fandom': fandom,
      'images': images,
      'coverImage': cover,
      'imageUrl': cover,
    };

    void setOrRemove(String key, Object? value) {
      if (value != null) {
        data[key] = value;
      } else if (forUpdate) {
        data[key] = FieldValue.delete();
      }
    }

    final cleanSizes =
        Product.apparelSizes.where((size) => sizes.contains(size)).toList();
    final cleanSubject = characterSubject?.trim();

    final isApparel = category == Product.apparel;
    final isCollectible = category == Product.collectibles;
    final isDigital = category == Product.digitalAssets;

    setOrRemove('sizes', isApparel ? cleanSizes : null);
    setOrRemove('collectibleType', isCollectible ? collectibleType : null);
    setOrRemove('edition', isCollectible ? edition : null);
    setOrRemove('digitalAssetType', isDigital ? digitalAssetType : null);
    setOrRemove(
      'characterSubject',
      isDigital && cleanSubject != null && cleanSubject.isNotEmpty
          ? cleanSubject
          : null,
    );

    return data;
  }
}

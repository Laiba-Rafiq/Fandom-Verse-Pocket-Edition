import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/fandom_category.dart';

class CategoryException implements Exception {
  const CategoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CategoryService {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  static const String categoriesCollection = 'categories';

  final CollectionReference<Map<String, dynamic>> _categories =
      FirebaseFirestore.instance.collection(categoriesCollection);

  Stream<List<FandomCategory>> watchCategories() {
    return _categories.orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs.map(FandomCategory.fromDoc).toList(),
        );
  }

  Future<List<String>> getCategoryNames() async {
    try {
      final snapshot = await _categories.orderBy('name').get();
      final names = snapshot.docs
          .map((doc) => (doc.data()['name'] as String?) ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      return names.isEmpty ? AppConstants.defaultFandomCategories : names;
    } catch (_) {
      return AppConstants.defaultFandomCategories;
    }
  }

  Future<void> addCategory({
    required String name,
    String? imageUrl,
  }) async {
    final cleanName = name.trim();
    await _ensureUniqueName(cleanName);
    await _categories.add({
      'name': cleanName,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    String? imageUrl,
  }) async {
    final cleanName = name.trim();
    await _ensureUniqueName(cleanName, ignoreId: id);
    await _categories.doc(id).update({
      'name': cleanName,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) {
    return _categories.doc(id).delete();
  }

  Future<void> _ensureUniqueName(String name, {String? ignoreId}) async {
    final snapshot = await _categories.get();
    final lower = name.toLowerCase();
    final exists = snapshot.docs.any((doc) {
      if (doc.id == ignoreId) return false;
      final existing = (doc.data()['name'] as String?) ?? '';
      return existing.trim().toLowerCase() == lower;
    });
    if (exists) {
      throw CategoryException('A category named "$name" already exists.');
    }
  }
}
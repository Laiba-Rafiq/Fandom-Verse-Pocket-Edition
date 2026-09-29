import 'package:cloud_firestore/cloud_firestore.dart';

class FandomCategory {
  const FandomCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? imageUrl;
  final DateTime? createdAt;

  factory FandomCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    return FandomCategory(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    this.fandom,
    this.images = const [],
    this.previousPrice,
    this.createdAt,
    this.sizes = const [],
    this.collectibleType,
    this.edition,
    this.digitalAssetType,
    this.characterSubject,
  });

  static const String apparel = 'Apparel';
  static const String collectibles = 'Collectibles';
  static const String digitalAssets = 'Digital Assets';

  static const List<String> categories = [
    apparel,
    collectibles,
    digitalAssets,
  ];

  static const List<String> apparelSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  static const List<String> collectibleTypes = [
    'Figure',
    'Plush',
    'Poster',
    'Keychain',
    'Trading Card',
    'Accessory',
    'Other',
  ];

  static const List<String> editions = [
    'Standard',
    'Limited Edition',
    'Exclusive',
  ];

  static const List<String> digitalAssetTypes = [
    'Wallpaper',
    'Avatar',
    'Icon Pack',
    'Digital Art',
    'Poster',
    'Other',
  ];

  static const int maxImages = 5;

  static const String currencySymbol = 'Rs.';

  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String? fandom;
  final List<String> images;
  final double? previousPrice;
  final DateTime? createdAt;
  final List<String> sizes;
  final String? collectibleType;
  final String? edition;
  final String? digitalAssetType;
  final String? characterSubject;

  bool get isApparel => category == apparel;
  bool get isCollectible => category == collectibles;
  bool get isDigitalAsset => category == digitalAssets;

  String? get coverImage => images.isNotEmpty ? images.first : null;

  String? get imageUrl => coverImage;

  bool get hasPriceDrop => previousPrice != null && previousPrice! > price;

  String get formattedPrice => formatPrice(price);

  static String formatPrice(double value) {
    final text =
        value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$currencySymbol $text';
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  static String? _nonEmpty(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value;
    return null;
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final previous = data['previousPrice'];

    var images = _stringList(data['images']);
    if (images.isEmpty) {
      final oldImage =
          _nonEmpty(data['coverImage']) ?? _nonEmpty(data['imageUrl']);
      if (oldImage != null) images = [oldImage];
    }

    return Product(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      category: (data['category'] as String?) ?? categories.first,
      description: (data['description'] as String?) ?? '',
      fandom: _nonEmpty(data['fandom']),
      images: images,
      previousPrice: previous is num ? previous.toDouble() : null,
      createdAt: created is Timestamp ? created.toDate() : null,
      sizes: _stringList(data['sizes']),
      collectibleType: _nonEmpty(data['collectibleType']),
      edition: _nonEmpty(data['edition']),
      digitalAssetType: _nonEmpty(data['digitalAssetType']),
      characterSubject: _nonEmpty(data['characterSubject']),
    );
  }
}

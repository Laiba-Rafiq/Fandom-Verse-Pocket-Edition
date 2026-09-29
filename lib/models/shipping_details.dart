class ShippingDetails {
  const ShippingDetails({
    required this.fullName,
    required this.phone,
    this.address,
    this.city,
  });

  final String fullName;
  final String phone;
  final String? address;
  final String? city;

  bool get hasAddress =>
      (address != null && address!.isNotEmpty) ||
      (city != null && city!.isNotEmpty);

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static ShippingDetails? fromMap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final name = _text(map['fullName']);
    final phone = _text(map['phone']);
    if (name == null && phone == null) return null;
    return ShippingDetails(
      fullName: name ?? '',
      phone: phone ?? '',
      address: _text(map['address']),
      city: _text(map['city']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      if (address != null && address!.trim().isNotEmpty)
        'address': address!.trim(),
      if (city != null && city!.trim().isNotEmpty) 'city': city!.trim(),
    };
  }
}

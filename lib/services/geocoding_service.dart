import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PlaceResult {
  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.city,
    this.venue,
    this.address,
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String? city;
  final String? venue;
  final String? address;
}

class GeocodingService {
  GeocodingService._();

  static final GeocodingService instance = GeocodingService._();

  static const String _host = 'nominatim.openstreetmap.org';
  static const Duration _timeout = Duration(seconds: 12);
  static const Map<String, String> _headers = {
    'User-Agent': 'FandomVerse/1.0 (com.techwiz.fandom_verse)',
    'Accept-Language': 'en',
  };

  static const List<String> _venueKeys = [
    'amenity',
    'building',
    'tourism',
    'leisure',
    'shop',
    'office',
    'historic',
    'club',
    'mall',
  ];

  static const List<String> _cityKeys = [
    'city',
    'town',
    'village',
    'municipality',
    'county',
    'state_district',
    'state',
  ];

  static const List<String> _areaKeys = [
    'neighbourhood',
    'quarter',
    'residential',
    'suburb',
    'city_district',
    'district',
  ];

  Future<List<PlaceResult>> search(String query) async {
    final text = query.trim();
    if (text.length < 3) {
      throw const GeocodingException(
        'Type at least 3 characters to search, e.g. "Expo Centre Karachi".',
      );
    }
    final uri = Uri.https(_host, '/search', {
      'q': text,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
    });
    final body = await _get(uri);
    if (body is! List) return const [];
    final results = <PlaceResult>[];
    for (final item in body) {
      if (item is Map<String, dynamic>) {
        final place = _toPlace(item);
        if (place != null) results.add(place);
      }
    }
    return results;
  }

  Future<PlaceResult?> reverse(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': latitude.toStringAsFixed(6),
      'lon': longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
    });
    final body = await _get(uri);
    if (body is! Map<String, dynamic>) return null;
    if (body['error'] != null) return null;
    final place = _toPlace(body);
    if (place == null) return null;
    return PlaceResult(
      title: place.title,
      subtitle: place.subtitle,
      latitude: latitude,
      longitude: longitude,
      city: place.city,
      venue: place.venue,
      address: place.address,
    );
  }

  Future<Object?> _get(Uri uri) async {
    try {
      final response = await http.get(uri, headers: _headers).timeout(_timeout);
      if (response.statusCode == 429) {
        throw const GeocodingException(
          'Too many requests. Please wait a moment and try again.',
        );
      }
      if (response.statusCode != 200) {
        throw const GeocodingException(
          'The map service is not responding. Please try again.',
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on GeocodingException {
      rethrow;
    } on TimeoutException {
      throw const GeocodingException(
        'The map service took too long. Please try again.',
      );
    } on SocketException {
      throw const GeocodingException(
        'No internet connection. Please check your network.',
      );
    } on FormatException {
      throw const GeocodingException(
        'Could not read the map service reply. Please try again.',
      );
    } on http.ClientException {
      throw const GeocodingException(
        'No internet connection. Please check your network.',
      );
    }
  }

  PlaceResult? _toPlace(Map<String, dynamic> item) {
    final lat = double.tryParse('${item['lat']}');
    final lng = double.tryParse('${item['lon']}');
    if (lat == null || lng == null) return null;

    final displayName = _clean(item['display_name']) ?? '';
    final parts = displayName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final raw = item['address'];
    final address = raw is Map
        ? raw.map((key, value) => MapEntry('$key', '$value'))
        : <String, String>{};

    final city = _firstOf(address, _cityKeys);
    final venue = _venueFrom(item, address);
    final street = _streetFrom(address, venue: venue, city: city);

    final title = venue ?? (parts.isNotEmpty ? parts.first : displayName);
    final subtitle = parts.length > 1 ? parts.skip(1).join(', ') : '';

    return PlaceResult(
      title: title,
      subtitle: subtitle,
      latitude: lat,
      longitude: lng,
      city: city,
      venue: venue,
      address: street ?? _fallbackAddress(parts, venue: venue, city: city),
    );
  }

  String? _venueFrom(Map<String, dynamic> item, Map<String, String> address) {
    final name = _clean(item['name']);
    if (name != null) return name;
    return _firstOf(address, _venueKeys);
  }

  String? _streetFrom(
    Map<String, String> address, {
    required String? venue,
    required String? city,
  }) {
    final road = _clean(address['road']) ?? _clean(address['pedestrian']);
    final number = _clean(address['house_number']);
    final pieces = <String>[];
    if (road != null) {
      pieces.add(number == null ? road : '$number $road');
    }
    for (final key in _areaKeys) {
      final value = _clean(address[key]);
      if (value != null) pieces.add(value);
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final piece in pieces) {
      final lower = piece.toLowerCase();
      if (lower == venue?.toLowerCase() || lower == city?.toLowerCase()) {
        continue;
      }
      if (seen.add(lower)) unique.add(piece);
    }
    if (unique.isEmpty) return null;
    return unique.take(3).join(', ');
  }

  String? _fallbackAddress(
    List<String> parts, {
    required String? venue,
    required String? city,
  }) {
    final filtered = parts.where((part) {
      final lower = part.toLowerCase();
      if (lower == venue?.toLowerCase()) return false;
      if (lower == city?.toLowerCase()) return false;
      if (RegExp(r'^\d{4,6}$').hasMatch(part)) return false;
      return true;
    }).toList();
    if (filtered.isEmpty) return null;
    return filtered.take(2).join(', ');
  }

  String? _firstOf(Map<String, String> address, List<String> keys) {
    for (final key in keys) {
      final value = _clean(address[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _clean(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }
}

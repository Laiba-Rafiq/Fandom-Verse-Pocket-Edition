import 'package:cloud_firestore/cloud_firestore.dart';

class FanEvent {
  const FanEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.fandom,
    required this.city,
    required this.venue,
    required this.startsAt,
    this.address,
    this.endsAt,
    this.ticketUrl,
    this.imageUrl,
    this.latitude,
    this.longitude,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String fandom;
  final String city;
  final String venue;
  final DateTime startsAt;
  final String? address;
  final DateTime? endsAt;
  final String? ticketUrl;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;

  static const List<String> monthShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> monthFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool get hasLocation => latitude != null && longitude != null;

  bool get hasTicketLink => ticketUrl != null && ticketUrl!.trim().isNotEmpty;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  DateTime get lastMoment => endsAt ?? startsAt;

  bool get isPast => lastMoment.isBefore(DateTime.now());

  String get cityKey => city.trim().toLowerCase();

  bool isOnDay(DateTime day) {
    final start = dateOnly(startsAt);
    final end = dateOnly(lastMoment);
    final target = dateOnly(day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  String get locationLabel {
    final parts = <String>[
      venue,
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      city,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  String get mapQuery {
    if (hasLocation) return '$latitude,$longitude';
    return locationLabel;
  }

  String get dateLabel {
    final end = endsAt;
    if (end == null) {
      return '${formatDate(startsAt)} • ${formatTime(startsAt)}';
    }
    if (isSameDay(startsAt, end)) {
      return '${formatDate(startsAt)} • '
          '${formatTime(startsAt)} - ${formatTime(end)}';
    }
    return '${formatDate(startsAt)} - ${formatDate(end)}';
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String formatDate(DateTime value) {
    return '${weekdayShort[value.weekday - 1]}, '
        '${value.day} ${monthShort[value.month - 1]} ${value.year}';
  }

  static String formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  static String? _readText(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  factory FanEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FanEvent(
      id: doc.id,
      title: _readText(data['title']) ?? 'Untitled event',
      description: _readText(data['description']) ?? '',
      fandom: _readText(data['fandom']) ?? 'General',
      city: _readText(data['city']) ?? 'Unknown city',
      venue: _readText(data['venue']) ?? '',
      startsAt: _readDate(data['startsAt']) ?? DateTime.now(),
      address: _readText(data['address']),
      endsAt: _readDate(data['endsAt']),
      ticketUrl: _readText(data['ticketUrl']),
      imageUrl: _readText(data['imageUrl']),
      latitude: _readDouble(data['latitude']),
      longitude: _readDouble(data['longitude']),
      createdAt: _readDate(data['createdAt']),
    );
  }
}

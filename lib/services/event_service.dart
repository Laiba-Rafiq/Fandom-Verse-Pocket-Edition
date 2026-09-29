import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/fan_event.dart';
import 'notification_service.dart';

class EventException implements Exception {
  const EventException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EventService {
  EventService._();

  static final EventService instance = EventService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  Stream<List<FanEvent>> watchEvents() {
    return _events.orderBy('startsAt').snapshots().map(
          (snapshot) => snapshot.docs.map(FanEvent.fromDoc).toList(),
        );
  }

  Future<void> addEvent({
    required String title,
    required String description,
    required String fandom,
    required String city,
    required String venue,
    required DateTime startsAt,
    DateTime? endsAt,
    String? address,
    String? ticketUrl,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) async {
    final cleanTicket = normalizeUrl(ticketUrl);
    _validate(
      title: title,
      description: description,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      ticketUrl: cleanTicket,
      latitude: latitude,
      longitude: longitude,
    );
    final data = _buildData(
      title: title,
      description: description,
      fandom: fandom,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      address: address,
      ticketUrl: cleanTicket,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      isUpdate: false,
    );
    data['createdAt'] = FieldValue.serverTimestamp();
    final DocumentReference<Map<String, dynamic>> ref;
    try {
      ref = await _events.add(data);
    } on FirebaseException catch (error) {
      throw EventException(_messageFor(error));
    }
    _notifyNewEvent(
      id: ref.id,
      title: title,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  void _notifyNewEvent({
    required String id,
    required String title,
    required String city,
    required String venue,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) {
    final lastMoment = endsAt ?? startsAt;
    if (lastMoment.isBefore(DateTime.now())) return;
    final place = [venue.trim(), cleanCity(city)]
        .where((part) => part.isNotEmpty)
        .join(', ');
    unawaited(
      NotificationService.instance.broadcast(
        title: 'New event: ${title.trim()}',
        body: '${FanEvent.formatDate(startsAt)} • $place',
        type: NotificationType.event,
        targetId: id,
      ),
    );
  }

  Future<void> updateEvent({
    required String id,
    required String title,
    required String description,
    required String fandom,
    required String city,
    required String venue,
    required DateTime startsAt,
    DateTime? endsAt,
    String? address,
    String? ticketUrl,
    String? imageUrl,
    double? latitude,
    double? longitude,
  }) async {
    final cleanTicket = normalizeUrl(ticketUrl);
    _validate(
      title: title,
      description: description,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      ticketUrl: cleanTicket,
      latitude: latitude,
      longitude: longitude,
    );
    final data = _buildData(
      title: title,
      description: description,
      fandom: fandom,
      city: city,
      venue: venue,
      startsAt: startsAt,
      endsAt: endsAt,
      address: address,
      ticketUrl: cleanTicket,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      isUpdate: true,
    );
    try {
      await _events.doc(id).update(data);
    } on FirebaseException catch (error) {
      throw EventException(_messageFor(error));
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _events.doc(id).delete();
    } on FirebaseException catch (error) {
      throw EventException(_messageFor(error));
    }
  }

  static String? normalizeUrl(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return text;
    }
    return 'https://$text';
  }

  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }

  static String cleanCity(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) => word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  void _validate({
    required String title,
    required String description,
    required String city,
    required String venue,
    required DateTime startsAt,
    required DateTime? endsAt,
    required String? ticketUrl,
    required double? latitude,
    required double? longitude,
  }) {
    if (title.trim().length < 3) {
      throw const EventException(
          'Please enter an event title (min 3 characters).');
    }
    if (description.trim().length < 10) {
      throw const EventException(
        'Please enter a description (min 10 characters).',
      );
    }
    if (city.trim().isEmpty) {
      throw const EventException('Please enter the city.');
    }
    if (venue.trim().isEmpty) {
      throw const EventException('Please enter the venue.');
    }
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      throw const EventException('The end time must be after the start time.');
    }
    if ((latitude == null) != (longitude == null)) {
      throw const EventException(
        'Please enter both latitude and longitude, or leave both empty.',
      );
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      throw const EventException('Latitude must be between -90 and 90.');
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      throw const EventException('Longitude must be between -180 and 180.');
    }
    if (ticketUrl != null && !isValidUrl(ticketUrl)) {
      throw const EventException('Please enter a valid ticket link.');
    }
  }

  Map<String, dynamic> _buildData({
    required String title,
    required String description,
    required String fandom,
    required String city,
    required String venue,
    required DateTime startsAt,
    required DateTime? endsAt,
    required String? address,
    required String? ticketUrl,
    required String? imageUrl,
    required double? latitude,
    required double? longitude,
    required bool isUpdate,
  }) {
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'fandom': fandom.trim().isEmpty ? 'General' : fandom.trim(),
      'city': cleanCity(city),
      'venue': venue.trim(),
      'startsAt': Timestamp.fromDate(startsAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    void setOrRemove(String key, Object? value) {
      if (value != null) {
        data[key] = value;
      } else if (isUpdate) {
        data[key] = FieldValue.delete();
      }
    }

    final cleanAddress = address?.trim();
    final cleanImage = imageUrl?.trim();

    setOrRemove(
      'address',
      cleanAddress == null || cleanAddress.isEmpty ? null : cleanAddress,
    );
    setOrRemove('endsAt', endsAt == null ? null : Timestamp.fromDate(endsAt));
    setOrRemove('ticketUrl', ticketUrl);
    setOrRemove(
      'imageUrl',
      cleanImage == null || cleanImage.isEmpty ? null : cleanImage,
    );
    setOrRemove('latitude', latitude);
    setOrRemove('longitude', longitude);

    return data;
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Only admins can manage events.';
      case 'not-found':
        return 'This event no longer exists.';
      case 'unavailable':
        return 'No internet connection. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/fan_event.dart';
import 'event_service.dart';

class ReminderException implements Exception {
  const ReminderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PlannedReminder {
  const _PlannedReminder({
    required this.event,
    required this.slot,
    required this.at,
  });

  final FanEvent event;
  final int slot;
  final DateTime at;
}

class EventReminderService {
  EventReminderService._();

  static final EventReminderService instance = EventReminderService._();

  static const String _channelId = 'event_reminders';
  static const String _channelName = 'Event reminders';
  static const String _channelDescription =
      'Reminders before events from your fandoms or events you chose.';
  static const String _smallIcon = 'ic_notification';
  static const Color _accent = Color(0xFFF0357A);
  static const int _maxReminders = 60;
  static const int _firstId = 500000;

  static const List<Duration> _offsets = [
    Duration(days: 2),
    Duration(days: 1),
    Duration(hours: 2),
  ];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _uid;
  Set<String> _fandoms = <String>{};
  Set<String> _chosen = <String>{};
  List<FanEvent> _events = const [];
  bool _eventsReady = false;
  bool _chosenReady = false;
  bool _channelReady = false;
  bool _running = false;
  bool _runAgain = false;

  StreamSubscription<List<FanEvent>>? _eventsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chosenSub;
  Timer? _debounce;

  CollectionReference<Map<String, dynamic>> _remindersOf(String uid) =>
      _db.collection('users').doc(uid).collection('eventReminders');

  Stream<bool> watchIsReminded(String eventId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);
    return _remindersOf(uid).doc(eventId).snapshots().map((doc) => doc.exists);
  }

  bool isInterested(FanEvent event) =>
      _fandoms.contains(event.fandom.trim().toLowerCase());

  Future<bool> toggle(String eventId, {required bool isReminded}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const ReminderException('Please log in to set reminders.');
    }
    final ref = _remindersOf(uid).doc(eventId);
    try {
      if (isReminded) {
        await ref.delete().timeout(const Duration(seconds: 10));
        return false;
      }
      await ref.set({
        'eventId': eventId,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 10));
      return true;
    } on TimeoutException {
      return !isReminded;
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw const ReminderException(
            'You do not have permission to do this.',
          );
        case 'unavailable':
          throw const ReminderException(
            'No internet connection. Please try again.',
          );
        default:
          throw const ReminderException(
            'Could not update the reminder. Please try again.',
          );
      }
    }
  }

  void start({required String uid, required List<String> fandoms}) {
    if (_uid == uid) {
      updateFandoms(fandoms);
      return;
    }
    _stopListening();
    _uid = uid;
    _fandoms = _clean(fandoms);
    unawaited(_ensureChannel());

    _eventsSub = EventService.instance.watchEvents().listen(
      (events) {
        _events = events;
        _eventsReady = true;
        _scheduleSoon();
      },
      onError: (Object e) => debugPrint('Reminder events error: $e'),
    );

    _chosenSub = _remindersOf(uid).snapshots().listen(
      (snapshot) {
        _chosen = snapshot.docs.map((doc) => doc.id).toSet();
        _chosenReady = true;
        _scheduleSoon();
      },
      onError: (Object e) {
        debugPrint('Reminder choices error: $e');
        _chosenReady = true;
        _scheduleSoon();
      },
    );
  }

  void updateFandoms(List<String> fandoms) {
    final clean = _clean(fandoms);
    final same = clean.length == _fandoms.length && clean.containsAll(_fandoms);
    if (same) return;
    _fandoms = clean;
    _scheduleSoon();
  }

  Future<void> stop() async {
    _stopListening();
    _uid = null;
    try {
      await _local.cancelAllPendingNotifications();
    } catch (e) {
      debugPrint('Reminder cancel failed: $e');
    }
  }

  void _stopListening() {
    _debounce?.cancel();
    _debounce = null;
    _eventsSub?.cancel();
    _eventsSub = null;
    _chosenSub?.cancel();
    _chosenSub = null;
    _events = const [];
    _chosen = <String>{};
    _eventsReady = false;
    _chosenReady = false;
  }

  Set<String> _clean(List<String> fandoms) {
    return fandoms
        .map((f) => f.trim().toLowerCase())
        .where((f) => f.isNotEmpty)
        .toSet();
  }

  Future<void> _ensureChannel() async {
    if (_channelReady) return;
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }
      _channelReady = true;
    } catch (e) {
      debugPrint('Reminder channel failed: $e');
    }
  }

  void _scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_reschedule());
    });
  }

  Future<void> _reschedule() async {
    if (_uid == null || !_eventsReady || !_chosenReady) return;
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    try {
      final now = DateTime.now();
      final planned = <_PlannedReminder>[];
      for (final event in _events) {
        if (event.isPast) continue;
        final wanted = isInterested(event) || _chosen.contains(event.id);
        if (!wanted) continue;
        for (var slot = 0; slot < _offsets.length; slot++) {
          final at = event.startsAt.subtract(_offsets[slot]);
          if (!at.isAfter(now.add(const Duration(minutes: 1)))) continue;
          planned.add(_PlannedReminder(event: event, slot: slot, at: at));
        }
      }
      planned.sort((a, b) => a.at.compareTo(b.at));

      await _local.cancelAllPendingNotifications();
      var id = _firstId;
      for (final reminder in planned.take(_maxReminders)) {
        if (_uid == null) break;
        final title = _titleFor(reminder);
        final body = _bodyFor(reminder);
        await _local.zonedSchedule(
          id: id++,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              icon: _smallIcon,
              color: _accent,
              styleInformation: BigTextStyleInformation(body),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'title': title,
            'body': body,
            'type': 'event',
            'targetId': reminder.event.id,
          }),
        );
      }
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
    } finally {
      _running = false;
      if (_runAgain) {
        _runAgain = false;
        _scheduleSoon();
      }
    }
  }

  String _placeOf(FanEvent event) {
    return [event.venue.trim(), event.city.trim()]
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  String _titleFor(_PlannedReminder reminder) {
    final name = reminder.event.title;
    switch (reminder.slot) {
      case 0:
        return '2 days left: $name';
      case 1:
        return 'Tomorrow: $name';
      default:
        return 'Starting soon: $name';
    }
  }

  String _bodyFor(_PlannedReminder reminder) {
    final event = reminder.event;
    final place = _placeOf(event);
    switch (reminder.slot) {
      case 0:
        return "${FanEvent.formatDate(event.startsAt)} • $place. "
            "Don't miss it!";
      case 1:
        return 'Starts at ${FanEvent.formatTime(event.startsAt)} • $place';
      default:
        return 'Starts in 2 hours • $place';
    }
  }
}

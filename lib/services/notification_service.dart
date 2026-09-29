import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';

class NotificationFeed {
  const NotificationFeed({required this.items, required this.seenAt});

  final List<AppNotification> items;
  final DateTime? seenAt;

  int get unreadCount => items.where((n) => n.isUnread(seenAt)).length;

  bool isUnread(AppNotification notification) => notification.isUnread(seenAt);
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _limit = 30;
  static const String seenField = 'notificationsSeenAt';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _broadcasts =>
      _db.collection('notifications');

  CollectionReference<Map<String, dynamic>> _personal(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> broadcast({
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
  }) async {
    if (title.trim().isEmpty) return;
    try {
      await _broadcasts
          .add(
            AppNotification.newData(
              title: title,
              body: body,
              type: type,
              targetId: targetId,
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('NotificationService.broadcast failed: $e');
    }
  }

  Future<void> sendToUser(
    String uid, {
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
  }) async {
    if (uid.trim().isEmpty || title.trim().isEmpty) return;
    try {
      await _personal(uid)
          .add(
            AppNotification.newData(
              title: title,
              body: body,
              type: type,
              targetId: targetId,
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('NotificationService.sendToUser failed: $e');
    }
  }

  Stream<NotificationFeed> watchFeed(String uid) {
    final subscriptions = <StreamSubscription<dynamic>>[];
    var broadcastItems = <AppNotification>[];
    var personalItems = <AppNotification>[];
    DateTime? seenAt;
    var broadcastReady = false;
    var personalReady = false;
    var seenReady = false;

    late final StreamController<NotificationFeed> controller;

    void emit() {
      if (!broadcastReady || !personalReady || !seenReady) return;
      if (controller.isClosed) return;
      final now = DateTime.now();
      final all = [...broadcastItems, ...personalItems]..sort(
          (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
        );
      controller.add(
        NotificationFeed(
          items: all.take(_limit).toList(),
          seenAt: seenAt,
        ),
      );
    }

    controller = StreamController<NotificationFeed>(
      onListen: () {
        subscriptions.add(
          _broadcasts
              .orderBy('createdAt', descending: true)
              .limit(_limit)
              .snapshots()
              .listen(
            (snapshot) {
              broadcastItems = snapshot.docs
                  .map((d) => AppNotification.fromDoc(d, personal: false))
                  .toList();
              broadcastReady = true;
              emit();
            },
            onError: (Object e) {
              debugPrint('Broadcast notifications error: $e');
              broadcastReady = true;
              emit();
            },
          ),
        );
        subscriptions.add(
          _personal(uid)
              .orderBy('createdAt', descending: true)
              .limit(_limit)
              .snapshots()
              .listen(
            (snapshot) {
              personalItems = snapshot.docs
                  .map((d) => AppNotification.fromDoc(d, personal: true))
                  .toList();
              personalReady = true;
              emit();
            },
            onError: (Object e) {
              debugPrint('Personal notifications error: $e');
              personalReady = true;
              emit();
            },
          ),
        );
        subscriptions.add(
          _userDoc(uid).snapshots().listen(
            (snapshot) {
              seenAt = _readSeenAt(snapshot.data());
              seenReady = true;
              emit();
            },
            onError: (Object e) {
              debugPrint('Notification seen time error: $e');
              seenAt = _fallbackSeenAt();
              seenReady = true;
              emit();
            },
          ),
        );
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  Stream<int> watchUnreadCount(String uid) =>
      watchFeed(uid).map((feed) => feed.unreadCount);

  Future<void> markAllSeen(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      await _userDoc(uid).set(
        {seenField: FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('NotificationService.markAllSeen failed: $e');
    }
  }

  DateTime? _readSeenAt(Map<String, dynamic>? data) {
    final value = data?[seenField];
    if (value is Timestamp) return value.toDate();
    return _fallbackSeenAt();
  }

  DateTime? _fallbackSeenAt() =>
      FirebaseAuth.instance.currentUser?.metadata.creationTime;
}

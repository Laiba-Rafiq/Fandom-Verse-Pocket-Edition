import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../models/wishlist_item.dart';
import 'notification_service.dart';
import 'wishlist_service.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const String _channelId = 'fandom_updates';
  static const String _channelName = 'Fandom updates';
  static const String _channelDescription =
      'New events, trending posts, order and enquiry updates.';
  static const String _fanTopic = 'fans';
  static const String _smallIcon = 'ic_notification';
  static const Color _accent = Color(0xFFF0357A);

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<AppNotification?> pendingOpen =
      ValueNotifier<AppNotification?>(null);

  bool _initialized = false;
  bool _localReady = false;
  bool _permissionAsked = false;
  bool _subscribedToTopic = false;
  bool _firstFeed = true;
  bool _isFan = false;
  int _nextId = 1000;
  String? _activeUid;

  final Set<String> _knownKeys = <String>{};
  final Set<String> _priceHandled = <String>{};

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamSubscription<NotificationFeed>? _feedSub;
  StreamSubscription<List<WishlistEntry>>? _priceSub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _initLocal();
    await _initMessaging();

    _authSub ??= FirebaseAuth.instance.authStateChanges().listen(
          _onAuthChanged,
          onError: (Object e) => debugPrint('PushService auth error: $e'),
        );
  }

  AppNotification? takePending() {
    final value = pendingOpen.value;
    pendingOpen.value = null;
    return value;
  }

  Future<void> _initLocal() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) =>
            _openFromPayload(response.payload),
      );

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
      _localReady = true;

      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openFromPayload(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('PushService local init failed: $e');
    }
  }

  Future<void> _initMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _deliver(_fromRemote(message)),
      );
      final initial = await messaging.getInitialMessage();
      if (initial != null) _deliver(_fromRemote(initial));
    } catch (e) {
      debugPrint('PushService messaging init failed: $e');
    }
  }

  void _onAuthChanged(User? user) {
    if (user == null) {
      _stopUser();
      return;
    }
    if (user.uid == _activeUid) return;
    _stopUser();
    _activeUid = user.uid;
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) => _onProfile(user.uid, snapshot.data()),
          onError: (Object e) => debugPrint('PushService profile error: $e'),
        );
  }

  void _onProfile(String uid, Map<String, dynamic>? data) {
    if (data == null) return;
    final role = (data['role'] as String? ?? '').toLowerCase();
    final blocked = data['isBlocked'] == true;
    final fan = role != 'admin' && !blocked;

    if (fan && !_isFan) {
      _isFan = true;
      _startFeed(uid);
      unawaited(_askPermission());
      unawaited(_setTopic(subscribe: true));
    } else if (!fan && _isFan) {
      _isFan = false;
      _stopFeed();
      unawaited(_setTopic(subscribe: false));
    }
  }

  void _startFeed(String uid) {
    _stopFeed();
    _firstFeed = true;
    _feedSub = NotificationService.instance.watchFeed(uid).listen(
          _onFeed,
          onError: (Object e) => debugPrint('PushService feed error: $e'),
        );
    _startPriceWatch(uid);
  }

  void _onFeed(NotificationFeed feed) {
    if (_firstFeed) {
      _knownKeys.addAll(
        feed.items.where((n) => n.createdAt != null).map((n) => n.key),
      );
      _firstFeed = false;
      return;
    }
    for (final notification in feed.items.reversed) {
      if (notification.createdAt == null) continue;
      if (_knownKeys.add(notification.key) && feed.isUnread(notification)) {
        unawaited(_showLocal(notification));
      }
    }
  }

  void _startPriceWatch(String uid) {
    _priceSub?.cancel();
    try {
      _priceSub = WishlistService.instance.watchEntries().listen(
            (entries) => _onWishlist(uid, entries),
            onError: (Object e) => debugPrint('PushService wishlist error: $e'),
          );
    } catch (e) {
      debugPrint('PushService wishlist watch failed: $e');
    }
  }

  void _onWishlist(String uid, List<WishlistEntry> entries) {
    for (final entry in entries) {
      if (!entry.hasNewAlert) continue;
      final product = entry.product;
      if (product == null) continue;
      final cents = (product.price * 100).round();
      final docId = 'price_${entry.item.productId}_$cents';
      if (!_priceHandled.add(docId)) continue;
      unawaited(_createPriceNotification(uid, docId, entry));
    }
  }

  Future<void> _createPriceNotification(
    String uid,
    String docId,
    WishlistEntry entry,
  ) async {
    final saved = entry.item.savedPrice;
    final current = entry.currentPrice;
    if (saved <= 0 || current >= saved) return;
    var percent = ((saved - current) / saved * 100).round();
    if (percent < 1) percent = 1;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId);
    try {
      final existing = await ref.get().timeout(const Duration(seconds: 10));
      if (existing.exists) return;
      await ref.set(
        AppNotification.newData(
          title: 'Price drop: ${entry.name}',
          body: "Now $percent% cheaper than when you saved it. "
              "Grab it before it's gone!",
          type: NotificationType.price,
          targetId: entry.item.productId,
        ),
      );
    } catch (e) {
      debugPrint('PushService price notification failed: $e');
    }
  }

  void _stopFeed() {
    _feedSub?.cancel();
    _feedSub = null;
    _priceSub?.cancel();
    _priceSub = null;
    _knownKeys.clear();
    _priceHandled.clear();
    _firstFeed = true;
  }

  void _stopUser() {
    _profileSub?.cancel();
    _profileSub = null;
    _stopFeed();
    if (_isFan || _subscribedToTopic) {
      unawaited(_setTopic(subscribe: false));
    }
    _isFan = false;
    _activeUid = null;
  }

  Future<void> _askPermission() async {
    if (_permissionAsked) return;
    _permissionAsked = true;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('PushService permission failed: $e');
    }
  }

  Future<void> _setTopic({required bool subscribe}) async {
    try {
      if (subscribe) {
        await FirebaseMessaging.instance.subscribeToTopic(_fanTopic);
        _subscribedToTopic = true;
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic(_fanTopic);
        _subscribedToTopic = false;
      }
    } catch (e) {
      debugPrint('PushService topic update failed: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (!_isFan) return;
    final notification = _fromRemote(message);
    if (notification.title.isEmpty && notification.body.isEmpty) return;
    unawaited(_showLocal(notification));
  }

  Future<void> _showLocal(AppNotification notification) async {
    if (!_localReady) return;
    try {
      await _local.show(
        id: _nextId++,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: _smallIcon,
            color: _accent,
            styleInformation: BigTextStyleInformation(notification.body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: _encode(notification),
      );
    } catch (e) {
      debugPrint('PushService show failed: $e');
    }
  }

  AppNotification _fromRemote(RemoteMessage message) {
    final data = message.data;
    final title = message.notification?.title ?? data['title']?.toString();
    final body = message.notification?.body ?? data['body']?.toString();
    final target = data['targetId']?.toString().trim();
    return AppNotification(
      id: message.messageId ?? 'push',
      title: (title ?? '').trim(),
      body: (body ?? '').trim(),
      type: AppNotification.typeFrom(data['type']?.toString()),
      personal: false,
      targetId: target == null || target.isEmpty ? null : target,
      createdAt: message.sentTime ?? DateTime.now(),
    );
  }

  String _encode(AppNotification notification) {
    return jsonEncode({
      'title': notification.title,
      'body': notification.body,
      'type': notification.type.name,
      'targetId': notification.targetId,
    });
  }

  void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is! Map) return;
      final target = data['targetId']?.toString();
      _deliver(
        AppNotification(
          id: 'open',
          title: data['title']?.toString() ?? '',
          body: data['body']?.toString() ?? '',
          type: AppNotification.typeFrom(data['type']?.toString()),
          personal: false,
          targetId: target == null || target.isEmpty ? null : target,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('PushService payload error: $e');
    }
  }

  void _deliver(AppNotification notification) {
    pendingOpen.value = notification;
  }
}

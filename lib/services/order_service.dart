import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/cart_item.dart';
import '../models/purchase_order.dart';
import '../models/shipping_details.dart';
import 'notification_service.dart';

class OrderException implements Exception {
  const OrderException(this.message);
  final String message;

  @override
  String toString() => message;
}

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();

  DocumentReference<Map<String, dynamic>> _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw const OrderException('Please log in to place an order.');
    }
    return _db.collection('users').doc(uid);
  }

  Stream<List<PurchaseOrder>> watchOrders() {
    return _userDoc()
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(PurchaseOrder.fromDoc).toList(),
        );
  }

  Stream<List<PurchaseOrder>> watchAllOrders() {
    return _db.collectionGroup('orders').snapshots().map((snapshot) {
      final orders = snapshot.docs.map(PurchaseOrder.fromDoc).toList();
      orders.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return bDate.compareTo(aDate);
      });
      return orders;
    });
  }

  Future<PurchaseOrder> placeOrder(
    List<CartItem> cartItems, {
    required ShippingDetails shipping,
  }) async {
    if (cartItems.isEmpty) {
      throw const OrderException('Your cart is empty.');
    }
    if (shipping.fullName.trim().isEmpty || shipping.phone.trim().isEmpty) {
      throw const OrderException('Please enter your name and phone number.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final userDoc = _userDoc();

    String? customerName = authUser?.displayName;
    try {
      final profile = await userDoc.get();
      final profileName = profile.data()?['name'];
      if (profileName is String && profileName.trim().isNotEmpty) {
        customerName = profileName;
      }
    } catch (_) {}
    final customerEmail = authUser?.email;

    final lines = cartItems.map(OrderLine.fromCartItem).toList();
    final subtotal =
        lines.fold<double>(0, (running, line) => running + line.total);
    final total = subtotal;
    final orderNumber = _generateOrderNumber();

    final orderRef = userDoc.collection('orders').doc();
    final batch = _db.batch();

    batch.set(orderRef, {
      'orderNumber': orderNumber,
      'userId': userDoc.id,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'shipping': shipping.toMap(),
      'items': lines.map((line) => line.toMap()).toList(),
      'subtotal': subtotal,
      'total': total,
      'status': PurchaseOrder.simulatedStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final item in cartItems) {
      batch.delete(userDoc.collection('cart').doc(item.id));
    }

    await batch.commit();

    _notifyOrderPlaced(
      uid: userDoc.id,
      orderId: orderRef.id,
      orderNumber: orderNumber,
      itemCount: cartItems.length,
      customerName: customerName,
    );

    return PurchaseOrder(
      id: orderRef.id,
      orderNumber: orderNumber,
      items: lines,
      subtotal: subtotal,
      total: total,
      status: PurchaseOrder.simulatedStatus,
      createdAt: DateTime.now(),
      userId: userDoc.id,
      customerName: customerName,
      customerEmail: customerEmail,
      shipping: shipping,
    );
  }

  Future<void> updateStatus(PurchaseOrder order, String newStatus) async {
    final uid = order.userId;
    if (uid == null || uid.isEmpty) {
      throw const OrderException('This order is missing its customer.');
    }
    final allowed = newStatus == order.nextStatus ||
        (newStatus == PurchaseOrder.statusCancelled && order.canCancel);
    if (!allowed) {
      throw const OrderException('This status change is not allowed.');
    }

    final ref =
        _db.collection('users').doc(uid).collection('orders').doc(order.id);
    try {
      await ref.update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _notifyStatusChange(uid: uid, order: order, newStatus: newStatus);
      return;
    } on FirebaseException catch (error) {
      switch (error.code) {
        case 'permission-denied':
          throw const OrderException('Only admins can update orders.');
        case 'not-found':
          throw const OrderException('This order no longer exists.');
        case 'unavailable':
          throw const OrderException(
            'No internet connection. Please try again.',
          );
        default:
          throw const OrderException(
            'Could not update the order. Please try again.',
          );
      }
    }
    _notifyStatusChange(uid: uid, order: order, newStatus: newStatus);
  }

  void _notifyStatusChange({
    required String uid,
    required PurchaseOrder order,
    required String newStatus,
  }) {
    final number = order.orderNumber;
    String title;
    String body;
    switch (newStatus) {
      case PurchaseOrder.statusProcessing:
        title = 'Order $number is being processed';
        body = "We're getting your items ready. "
            "We'll let you know when it ships.";
        break;
      case PurchaseOrder.statusShipped:
        title = 'Order $number has shipped!';
        body = 'Your order is on its way.';
        break;
      case PurchaseOrder.statusDelivered:
        title = 'Order $number delivered';
        body = 'Enjoy your merch! Thanks for shopping with Fandom Verse.';
        break;
      case PurchaseOrder.statusCancelled:
        title = 'Order $number was cancelled';
        body = 'If you have any questions, contact us from the app.';
        break;
      default:
        title = 'Order $number updated';
        body = 'Status: ${PurchaseOrder.labelFor(newStatus)}';
    }
    unawaited(
      NotificationService.instance.sendToUser(
        uid,
        title: title,
        body: body,
        type: NotificationType.order,
        targetId: order.id,
      ),
    );
  }

  void _notifyOrderPlaced({
    required String uid,
    required String orderId,
    required String orderNumber,
    required int itemCount,
    required String? customerName,
  }) {
    final firstName = (customerName ?? '').trim().split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty ? 'Thanks!' : 'Thanks, $firstName!';
    final items = itemCount == 1 ? '1 item' : '$itemCount items';
    unawaited(
      NotificationService.instance.sendToUser(
        uid,
        title: 'Order placed: $orderNumber',
        body: "$greeting We've received your order of $items.",
        type: NotificationType.order,
        targetId: orderId,
      ),
    );
  }

  String _generateOrderNumber() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(
      6,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return 'FV-$code';
  }
}

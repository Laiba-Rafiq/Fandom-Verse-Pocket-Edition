import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';
import '../models/inquiry.dart';
import 'notification_service.dart';

class InquiryException implements Exception {
  const InquiryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InquiryService {
  InquiryService._();

  static final InquiryService instance = InquiryService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int maxMessageLength = 2000;
  static const Duration _sendTimeout = Duration(seconds: 12);

  CollectionReference<Map<String, dynamic>> get _inquiries =>
      _db.collection('inquiries');

  Future<bool> submit({
    required String name,
    required String email,
    required String subject,
    required String message,
    String? phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const InquiryException('Please log in again to send your message.');
    }

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    final cleanPhone = phone?.trim() ?? '';

    if (cleanName.length < 2) {
      throw const InquiryException('Please enter your name.');
    }
    if (!isValidEmail(cleanEmail)) {
      throw const InquiryException('Please enter a valid email address.');
    }
    if (cleanSubject.isEmpty) {
      throw const InquiryException('Please choose a subject.');
    }
    if (cleanMessage.length < 10) {
      throw const InquiryException(
        'Please write a message (min 10 characters).',
      );
    }
    if (cleanMessage.length > maxMessageLength) {
      throw const InquiryException('Your message is too long.');
    }
    if (cleanPhone.isNotEmpty && !isValidPhone(cleanPhone)) {
      throw const InquiryException('Please enter a valid phone number.');
    }

    final data = <String, dynamic>{
      'userId': user.uid,
      'name': cleanName,
      'email': cleanEmail,
      'subject': cleanSubject,
      'message': cleanMessage,
      'status': Inquiry.statusNew,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (cleanPhone.isNotEmpty) data['phone'] = cleanPhone;

    final ref = _inquiries.doc();
    try {
      await ref.set(data).timeout(_sendTimeout);
      return true;
    } on TimeoutException {
      return false;
    } on FirebaseException catch (error) {
      throw InquiryException(_messageFor(error));
    }
  }

  Stream<List<Inquiry>> watchMine() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const <Inquiry>[]);
    return _inquiries
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(Inquiry.fromDoc).toList();
      list.sort(_newestFirst);
      return list;
    });
  }

  Stream<List<Inquiry>> watchAll() {
    return _inquiries.snapshots().map((snapshot) {
      final list = snapshot.docs.map(Inquiry.fromDoc).toList();
      list.sort(_newestFirst);
      return list;
    });
  }

  Future<void> setResolved(String id, bool resolved) async {
    try {
      await _inquiries.doc(id).update({
        'status': resolved ? Inquiry.statusResolved : Inquiry.statusNew,
        'resolvedAt':
            resolved ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } on FirebaseException catch (error) {
      throw InquiryException(_messageFor(error));
    }
    if (resolved) unawaited(_notifyResolved(id));
  }

  Future<void> _notifyResolved(String id) async {
    try {
      final doc =
          await _inquiries.doc(id).get().timeout(const Duration(seconds: 10));
      final data = doc.data();
      if (data == null) return;
      final uid = data['userId'];
      if (uid is! String || uid.trim().isEmpty) return;
      final subject = data['subject'];
      final about = subject is String && subject.trim().isNotEmpty
          ? 'Your message about "${subject.trim()}"'
          : 'Your message';
      await NotificationService.instance.sendToUser(
        uid,
        title: 'Your enquiry has been resolved',
        body: '$about has been marked as resolved. '
            'Any reply from our team will be in your email.',
        type: NotificationType.inquiry,
        targetId: id,
      );
    } catch (_) {}
  }

  Future<void> delete(String id) async {
    try {
      await _inquiries.doc(id).delete();
    } on FirebaseException catch (error) {
      throw InquiryException(_messageFor(error));
    }
  }

  static bool isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
  }

  static bool isValidPhone(String value) {
    final text = value.trim();
    if (!RegExp(r'^[0-9+\-\s()]+$').hasMatch(text)) return false;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7 && digits.length <= 15;
  }

  static int _newestFirst(Inquiry a, Inquiry b) {
    final aDate = a.createdAt;
    final bDate = b.createdAt;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return -1;
    if (bDate == null) return 1;
    return bDate.compareTo(aDate);
  }

  String _messageFor(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do this.';
      case 'not-found':
        return 'This message no longer exists.';
      case 'unavailable':
        return 'No internet connection. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

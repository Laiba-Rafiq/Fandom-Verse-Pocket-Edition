import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { event, post, order, inquiry, general, price }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.personal,
    this.targetId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool personal;
  final String? targetId;
  final DateTime? createdAt;

  String get key => '${personal ? 'u' : 'b'}_$id';

  bool get hasTarget =>
      targetId != null &&
      targetId!.isNotEmpty &&
      type != NotificationType.general;

  static NotificationType typeFrom(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.general,
    );
  }

  factory AppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool personal,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final created = data['createdAt'];
    final target = data['targetId'];
    return AppNotification(
      id: doc.id,
      title: (data['title'] as String? ?? '').trim(),
      body: (data['body'] as String? ?? '').trim(),
      type: typeFrom(data['type'] as String?),
      personal: personal,
      targetId:
          target is String && target.trim().isNotEmpty ? target.trim() : null,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  static Map<String, dynamic> newData({
    required String title,
    required String body,
    required NotificationType type,
    String? targetId,
  }) {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'type': type.name,
      'targetId': targetId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool isUnread(DateTime? seenAt) {
    final created = createdAt;
    if (created == null) return false;
    if (seenAt == null) return true;
    return created.isAfter(seenAt);
  }

  String get timeAgo {
    final created = createdAt;
    if (created == null) return 'Just now';
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    const months = [
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
    return '${created.day} ${months[created.month - 1]} ${created.year}';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class Inquiry {
  const Inquiry({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    this.phone,
    this.createdAt,
    this.resolvedAt,
  });

  static const String statusNew = 'new';
  static const String statusResolved = 'resolved';

  static const List<String> _months = [
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

  final String id;
  final String userId;
  final String name;
  final String email;
  final String subject;
  final String message;
  final String status;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isResolved => status == statusResolved;

  String get statusLabel => isResolved ? 'Resolved' : 'New';

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  String get sentLabel {
    final date = createdAt;
    if (date == null) return 'Sending...';
    return formatDateTime(date);
  }

  static String formatDateTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour < 12 ? 'AM' : 'PM';
    return '${value.day} ${_months[value.month - 1]} ${value.year}, '
        '$hour:$minute $period';
  }

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  factory Inquiry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final status = _text(data['status']);
    return Inquiry(
      id: doc.id,
      userId: _text(data['userId']) ?? '',
      name: _text(data['name']) ?? 'Fan',
      email: _text(data['email']) ?? '',
      subject: _text(data['subject']) ?? 'General question',
      message: _text(data['message']) ?? '',
      status: status == statusResolved ? statusResolved : statusNew,
      phone: _text(data['phone']),
      createdAt: _date(data['createdAt']),
      resolvedAt: _date(data['resolvedAt']),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.selectedFandoms = const [],
    this.badges = const [],
    this.bio = '',
    this.avatarUrl,
    this.profileCompleted = false,
    this.createdAt,
    this.isBlocked = false,
    this.blockedAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final List<String> selectedFandoms;
  final List<String> badges;
  final String bio;
  final String? avatarUrl;
  final bool profileCompleted;
  final DateTime? createdAt;
  final bool isBlocked;
  final DateTime? blockedAt;

  bool get isAdmin => role == UserRole.admin;
  bool get isFan => role == UserRole.fan;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final created = data['createdAt'];
    final blocked = data['blockedAt'];
    final role = UserRole.fromValue(data['role'] as String?);

    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      role: role,
      selectedFandoms: List<String>.from(data['selectedFandoms'] ?? const []),
      badges: List<String>.from(data['badges'] ?? const []),
      bio: (data['bio'] as String?) ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      profileCompleted:
          (data['profileCompleted'] as bool?) ?? role == UserRole.admin,
      createdAt: created is Timestamp ? created.toDate() : null,
      isBlocked: data['isBlocked'] == true,
      blockedAt: blocked is Timestamp ? blocked.toDate() : null,
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
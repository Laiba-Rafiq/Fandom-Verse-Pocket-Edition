import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  static const String usersCollection = 'users';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection(usersCollection).doc(uid);
  }

  Stream<AppUser?> watchUser(String uid) {
    return _userDoc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _userDoc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  Future<void> createFanProfile({
    required String uid,
    required String name,
    required String email,
  }) {
    return _userDoc(uid).set({
      'name': name,
      'email': email,
      'role': UserRole.fan.value,
      'selectedFandoms': <String>[],
      'badges': <String>[],
      'bio': '',
      'avatarUrl': null,
      'profileCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeProfileSetup({
    required String uid,
    required List<String> selectedFandoms,
    required List<String> badges,
    String? avatarUrl,
  }) {
    return _userDoc(uid).update({
      'selectedFandoms': selectedFandoms,
      'badges': badges,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? bio,
    String? avatarUrl,
    List<String>? selectedFandoms,
    List<String>? badges,
  }) {
    return _userDoc(uid).update({
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (selectedFandoms != null) 'selectedFandoms': selectedFandoms,
      if (badges != null) 'badges': badges,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
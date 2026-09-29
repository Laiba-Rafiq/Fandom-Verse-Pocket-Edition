import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/user_role.dart';

class UserAdminException implements Exception {
  const UserAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UserAdminService {
  UserAdminService._();

  static final UserAdminService instance = UserAdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxNameLength = 50;
  static const int maxBioLength = 300;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<List<AppUser>> watchAllUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs.map(AppUser.fromDoc).toList();
      users.sort((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return bDate.compareTo(aDate);
      });
      return users;
    });
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? AppUser.fromDoc(doc) : null,
        );
  }

  Future<void> setBlocked(AppUser user, bool blocked) async {
    if (user.isAdmin) {
      throw const UserAdminException('Admin accounts cannot be blocked.');
    }
    try {
      await _users.doc(user.uid).update({
        'isBlocked': blocked,
        'blockedAt':
            blocked ? FieldValue.serverTimestamp() : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw UserAdminException(_firestoreMessage(error));
    }
  }

  Future<void> updateUser({
    required String uid,
    required String name,
    required String bio,
  }) async {
    final cleanName = name.trim();
    final cleanBio = bio.trim();
    if (cleanName.length < 2) {
      throw const UserAdminException('Please enter a name (min 2 characters).');
    }
    if (cleanName.length > maxNameLength) {
      throw const UserAdminException(
        'Name can be up to $maxNameLength characters.',
      );
    }
    if (cleanBio.length > maxBioLength) {
      throw const UserAdminException(
        'Bio can be up to $maxBioLength characters.',
      );
    }
    try {
      await _users.doc(uid).update({
        'name': cleanName,
        'bio': cleanBio,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw UserAdminException(_firestoreMessage(error));
    }
  }

  Future<void> createFan({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.length < 2 || cleanName.length > maxNameLength) {
      throw const UserAdminException(
        'Please enter a name (2 to $maxNameLength characters).',
      );
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw const UserAdminException('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw const UserAdminException(
        'Password must be at least 6 characters.',
      );
    }

    FirebaseApp? helperApp;
    try {
      helperApp = await Firebase.initializeApp(
        name: 'adminHelper${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final helperAuth = FirebaseAuth.instanceFor(app: helperApp);
      final credential = await helperAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final newUser = credential.user;
      if (newUser == null) {
        throw const UserAdminException(
          'Could not create the account. Please try again.',
        );
      }
      await newUser.updateDisplayName(cleanName);

      final helperDb = FirebaseFirestore.instanceFor(app: helperApp);
      await helperDb.collection('users').doc(newUser.uid).set({
        'name': cleanName,
        'email': cleanEmail,
        'role': UserRole.fan.value,
        'selectedFandoms': <String>[],
        'badges': <String>[],
        'bio': '',
        'avatarUrl': null,
        'profileCompleted': false,
        'createdByAdmin': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await helperAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw UserAdminException(_authMessage(error));
    } on FirebaseException catch (error) {
      throw UserAdminException(_firestoreMessage(error));
    } finally {
      try {
        await helperApp?.delete();
      } catch (_) {}
    }
  }

  String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return 'Could not create the account. Please try again.';
    }
  }

  String _firestoreMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do this.';
      case 'not-found':
        return 'This user no longer exists.';
      case 'unavailable':
        return 'No internet connection. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
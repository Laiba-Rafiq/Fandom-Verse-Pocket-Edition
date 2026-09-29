import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/user_role.dart';
import 'user_service.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signUpFan({
    required String name,
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }

    final user = credential.user!;
    try {
      await user.updateDisplayName(name.trim());
      await UserService.instance.createFanProfile(
        uid: user.uid,
        name: name.trim(),
        email: email.trim(),
      );
    } on FirebaseException catch (e) {
      await _safeDelete(user);
      throw AuthFailure(
        'Could not save your profile (${e.message ?? e.code}). Please try again.',
      );
    }
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }

    final AppUser? profile;
    try {
      profile = await UserService.instance.getUser(credential.user!.uid);
    } on FirebaseException catch (e) {
      await signOut();
      throw AuthFailure(
          'Could not load your profile (${e.message ?? e.code}).');
    }

    if (profile == null) {
      await signOut();
      throw const AuthFailure(
        'No profile was found for this account. Please contact the app team.',
      );
    }

    if (profile.role != expectedRole) {
      await signOut();
      throw AuthFailure(
        expectedRole == UserRole.admin
            ? 'This account does not have Admin access. Please log in as a Fan.'
            : 'This is an Admin account. Please go back and choose "Admin".',
      );
    }

    return profile;
  }

  Future<AppUser> signInWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      await _initGoogle();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('Google sign-in was cancelled.');
      }
      throw AuthFailure(
        'Google sign-in failed: ${e.description ?? e.code.name}',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure(
        'Google did not return a sign-in token. Please try again.',
      );
    }

    final UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (e) {
      await signOut();
      throw AuthFailure(_messageFor(e));
    }

    final user = userCredential.user!;
    AppUser? profile;
    try {
      profile = await UserService.instance.getUser(user.uid);
      if (profile == null) {
        await UserService.instance.createFanProfile(
          uid: user.uid,
          name: user.displayName ?? account.displayName ?? 'Fan',
          email: user.email ?? account.email,
        );
        profile = await UserService.instance.getUser(user.uid);
      }
    } on FirebaseException catch (e) {
      await signOut();
      throw AuthFailure(
          'Could not load your profile (${e.message ?? e.code}).');
    }

    if (profile == null) {
      await signOut();
      throw const AuthFailure(
        'Could not create your profile. Please try again.',
      );
    }

    if (profile.role != UserRole.fan) {
      await signOut();
      throw const AuthFailure(
        'This is an Admin account. Please go back and choose "Admin".',
      );
    }

    return profile;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _initGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> _initGoogle() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize();
    _googleInitialized = true;
  }

  Future<void> _safeDelete(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await signOut();
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the app team.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Try logging in.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in method.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase yet.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

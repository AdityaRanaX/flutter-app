import 'package:firebase_auth/firebase_auth.dart';

/// Application-level exception wrapper for authentication errors.
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Firebase Authentication Service for EduLens.
///
/// Encapsulates direct interaction with [FirebaseAuth] and converts low-level
/// SDK exception codes into user-friendly [AuthException] instances.
class AuthService {
  final FirebaseAuth? _customFirebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
    : _customFirebaseAuth = firebaseAuth;

  FirebaseAuth get _firebaseAuth =>
      _customFirebaseAuth ?? FirebaseAuth.instance;

  /// Stream emitting the current authenticated [User] or `null` if signed out.
  Stream<User?> get authStateChanges {
    final custom = _customFirebaseAuth;
    if (custom != null) {
      return custom.authStateChanges();
    }
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Currently authenticated Firebase [User], if any.
  User? get currentUser {
    final custom = _customFirebaseAuth;
    if (custom != null) {
      return custom.currentUser;
    }
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Authenticates a user with email and password.
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code, e.message),
        code: e.code,
      );
    } catch (e) {
      throw AuthException('An unexpected error occurred during sign in.');
    }
  }

  /// Sends a password reset link to the given email address.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(
        _mapFirebaseAuthError(e.code, e.message),
        code: e.code,
      );
    } catch (e) {
      throw AuthException(
        'An unexpected error occurred while sending password reset email.',
      );
    }
  }

  /// Signs out the currently authenticated user.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  /// Converts Firebase error codes into clean, safe user-facing error messages.
  static String _mapFirebaseAuthError(String code, String? defaultMessage) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is formatted incorrectly.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No user account found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      default:
        return defaultMessage ?? 'Authentication failed. Please try again.';
    }
  }
}

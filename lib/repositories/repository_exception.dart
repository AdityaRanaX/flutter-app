import 'package:cloud_firestore/cloud_firestore.dart';

/// Why a repository call failed.
///
/// The screens built on top of these repositories have to tell a denied
/// request apart from a broken one: a permission denial must show the
/// unauthorized state, never an empty list or a generic error. Raw
/// `FirebaseException` codes are mapped onto this enum so no screen has
/// to know Firebase's own strings.
enum RepositoryErrorKind {
  /// Firestore rules rejected the request. The caller is signed in but
  /// not allowed to see or change this data.
  permissionDenied,

  /// The document asked for does not exist.
  notFound,

  /// Firestore could not be reached, or the request timed out.
  unavailable,

  /// Anything else.
  unknown,
}

/// A failure raised by a repository.
///
/// [message] is safe to show a user: it never carries a stack trace or
/// the raw Firebase payload. [cause] keeps the original error for logs.
class RepositoryException implements Exception {
  final RepositoryErrorKind kind;
  final String message;
  final Object? cause;

  const RepositoryException(this.kind, this.message, {this.cause});

  /// True when the failure was an authorization decision rather than a
  /// fault, so a screen can route it to the unauthorized state.
  bool get isPermissionDenied => kind == RepositoryErrorKind.permissionDenied;

  /// Translates a [FirebaseException] into a repository failure.
  ///
  /// [action] describes what was being attempted, in words a user could
  /// read, e.g. 'load schools'.
  factory RepositoryException.fromFirebase(
    FirebaseException error,
    String action,
  ) {
    switch (error.code) {
      case 'permission-denied':
        return RepositoryException(
          RepositoryErrorKind.permissionDenied,
          'You do not have permission to $action.',
          cause: error,
        );
      case 'not-found':
        return RepositoryException(
          RepositoryErrorKind.notFound,
          'We could not find what you asked for.',
          cause: error,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return RepositoryException(
          RepositoryErrorKind.unavailable,
          'We could not reach the server. Check your connection and try again.',
          cause: error,
        );
      default:
        return RepositoryException(
          RepositoryErrorKind.unknown,
          'Something went wrong while trying to $action.',
          cause: error,
        );
    }
  }

  @override
  String toString() => 'RepositoryException(${kind.name}): $message';
}

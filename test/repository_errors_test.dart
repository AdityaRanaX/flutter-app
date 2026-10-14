import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/constants/firestore_collections.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

FirebaseException _firebaseError(String code) => FirebaseException(
  plugin: 'cloud_firestore',
  code: code,
  message: 'raw firebase detail that users should never see',
);

void main() {
  group('RepositoryException', () {
    test('a denied request is reported as permissionDenied, not a failure', () {
      final e = RepositoryException.fromFirebase(
        _firebaseError('permission-denied'),
        'load schools',
      );
      expect(e.kind, RepositoryErrorKind.permissionDenied);
      expect(e.isPermissionDenied, isTrue);
    });

    test('a missing document is reported as notFound', () {
      final e = RepositoryException.fromFirebase(
        _firebaseError('not-found'),
        'load this exam',
      );
      expect(e.kind, RepositoryErrorKind.notFound);
      expect(e.isPermissionDenied, isFalse);
    });

    test('connectivity problems are reported as unavailable', () {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        final e = RepositoryException.fromFirebase(
          _firebaseError(code),
          'load exams',
        );
        expect(e.kind, RepositoryErrorKind.unavailable, reason: code);
      }
    });

    test('an unrecognised code falls back to unknown', () {
      final e = RepositoryException.fromFirebase(
        _firebaseError('something-new'),
        'load exams',
      );
      expect(e.kind, RepositoryErrorKind.unknown);
    });

    test('the message is safe to show and names the action', () {
      final e = RepositoryException.fromFirebase(
        _firebaseError('permission-denied'),
        'load schools',
      );
      expect(e.message, contains('load schools'));
      // The raw Firebase text must not leak through to the user.
      expect(e.message, isNot(contains('raw firebase detail')));
    });

    test('the original error is kept for logging', () {
      final raw = _firebaseError('permission-denied');
      final e = RepositoryException.fromFirebase(raw, 'load schools');
      expect(e.cause, same(raw));
    });
  });

  group('UserRoles.normalise', () {
    test('accepts both spellings the security rules allow', () {
      expect(UserRoles.normalise('districtAdmin'), UserRoles.districtAdmin);
      expect(UserRoles.normalise('district_admin'), UserRoles.districtAdmin);
      expect(UserRoles.normalise('schoolAdmin'), UserRoles.schoolAdmin);
      expect(UserRoles.normalise('school_admin'), UserRoles.schoolAdmin);
    });

    test('is case insensitive', () {
      expect(UserRoles.normalise('DISTRICTADMIN'), UserRoles.districtAdmin);
      expect(UserRoles.normalise('Teacher'), UserRoles.teacher);
    });

    test('returns empty for unknown, null or blank roles', () {
      // Empty rather than a default role: a profile with an unreadable
      // role must not quietly become a student, or anything else.
      expect(UserRoles.normalise(null), '');
      expect(UserRoles.normalise(''), '');
      expect(UserRoles.normalise('headmaster'), '');
    });
  });

  group('FirestoreCollections', () {
    test('names match the deployed security rules', () {
      // firestore.rules matches on these exact lower-case names.
      expect(FirestoreCollections.users, 'users');
      expect(FirestoreCollections.schools, 'schools');
      expect(FirestoreCollections.students, 'students');
      expect(FirestoreCollections.attendance, 'attendance');
      expect(FirestoreCollections.fees, 'fees');
      expect(FirestoreCollections.exams, 'exams');
    });
  });
}

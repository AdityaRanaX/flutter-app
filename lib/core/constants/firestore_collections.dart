/// The Firestore collection names EduLens reads and writes.
///
/// These are kept in one place so a collection is never spelled out as a
/// string literal inside a repository. The names are lower-case to match
/// what `firestore.rules` matches on and what the Day 3 user bootstrap
/// already writes — note that the PRD writes them capitalised
/// (`Users/{uid}`), but the deployed rules and the existing code both use
/// `users`, so the code is the source of truth here.
abstract class FirestoreCollections {
  static const String users = 'users';
  static const String schools = 'schools';
  static const String students = 'students';
  static const String attendance = 'attendance';
  static const String fees = 'fees';
  static const String exams = 'exams';
}

/// Document field names used in Firestore `where` clauses.
///
/// Only the fields actually queried on are listed. Fields that are merely
/// read back and handed to a model's `fromMap` do not need a constant —
/// the model already owns those names.
abstract class FirestoreFields {
  static const String schoolId = 'schoolId';
  static const String studentId = 'studentId';
  static const String className = 'className';
  static const String role = 'role';
  static const String date = 'date';
}

/// The role strings stored on a user profile.
///
/// `firestore.rules` accepts both the camelCase and snake_case spellings
/// for the two admin roles, so both are listed and [normalise] maps either
/// onto the camelCase form the app uses.
abstract class UserRoles {
  static const String districtAdmin = 'districtAdmin';
  static const String schoolAdmin = 'schoolAdmin';
  static const String teacher = 'teacher';
  static const String student = 'student';

  /// Folds `district_admin` and casing differences onto the canonical
  /// spelling, returning an empty string for anything unrecognised so a
  /// caller can treat it as a missing role rather than guessing.
  static String normalise(String? role) {
    if (role == null) return '';
    switch (role.toLowerCase().replaceAll('_', '')) {
      case 'districtadmin':
        return districtAdmin;
      case 'schooladmin':
        return schoolAdmin;
      case 'teacher':
        return teacher;
      case 'student':
        return student;
      default:
        return '';
    }
  }
}

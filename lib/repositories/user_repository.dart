import '../models/user_model.dart';

/// Reads and writes EduLens user profiles.
///
/// A user profile is the application-level identity that sits beside the
/// Firebase Auth account: Auth answers "who are you", this answers "what
/// role do you have and which school do you belong to".
abstract class UserRepository {
  /// The profile stored against a Firebase Auth UID, or null when the
  /// account has no profile document yet.
  Future<UserModel?> getUserById(String uid);

  /// Creates or updates a profile.
  Future<void> saveUser(UserModel user);

  /// Every user at [schoolId] holding [role].
  ///
  /// This is what the School List's teacher count is derived from — the
  /// school document itself does not store a teacher count, so it is
  /// counted from the users who have that role at that school.
  Future<List<UserModel>> getUsersBySchoolAndRole({
    required String schoolId,
    required String role,
  });
}

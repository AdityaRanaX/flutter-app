import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_service.dart';

/// Status of the user authentication and profile bootstrap process.
enum UserBootstrapStatus {
  unauthenticated,
  loading,
  profileFound,
  profileNotFound,
  invalidProfile,
  error,
}

/// Holds the resulting state of the user bootstrap operation.
class UserBootstrapState {
  final UserBootstrapStatus status;
  final UserModel? userModel;
  final User? authUser;
  final String? errorMessage;

  const UserBootstrapState({
    required this.status,
    this.userModel,
    this.authUser,
    this.errorMessage,
  });

  factory UserBootstrapState.unauthenticated() =>
      const UserBootstrapState(status: UserBootstrapStatus.unauthenticated);

  factory UserBootstrapState.loading({User? authUser}) => UserBootstrapState(
    status: UserBootstrapStatus.loading,
    authUser: authUser,
  );

  factory UserBootstrapState.profileFound({
    required User authUser,
    required UserModel userModel,
  }) => UserBootstrapState(
    status: UserBootstrapStatus.profileFound,
    authUser: authUser,
    userModel: userModel,
  );

  factory UserBootstrapState.profileNotFound({required User authUser}) =>
      UserBootstrapState(
        status: UserBootstrapStatus.profileNotFound,
        authUser: authUser,
      );

  factory UserBootstrapState.invalidProfile({
    required User authUser,
    required UserModel userModel,
  }) => UserBootstrapState(
    status: UserBootstrapStatus.invalidProfile,
    authUser: authUser,
    userModel: userModel,
  );

  factory UserBootstrapState.error(String message, {User? authUser}) =>
      UserBootstrapState(
        status: UserBootstrapStatus.error,
        authUser: authUser,
        errorMessage: message,
      );
}

/// Service handling authenticated user bootstrap flow:
/// FirebaseAuth currentUser.uid -> Users Firestore document -> UserModel
class UserBootstrapService {
  final AuthService _authService;
  final UserRepository userRepository;

  UserBootstrapService({AuthService? authService, required this.userRepository})
    : _authService = authService ?? AuthService();

  /// Executes bootstrap for the given authenticated [User] or current Firebase user.
  Future<UserBootstrapState> bootstrapUser([User? currentUser]) async {
    final authUser = currentUser ?? _authService.currentUser;

    if (authUser == null) {
      return UserBootstrapState.unauthenticated();
    }

    try {
      final profile = await userRepository.getUserById(authUser.uid);
      if (profile == null) {
        return UserBootstrapState.profileNotFound(authUser: authUser);
      }

      // Check for malformed or incomplete profile (missing role or UID)
      if (profile.role.trim().isEmpty || profile.uid.trim().isEmpty) {
        return UserBootstrapState.invalidProfile(
          authUser: authUser,
          userModel: profile,
        );
      }

      return UserBootstrapState.profileFound(
        authUser: authUser,
        userModel: profile,
      );
    } catch (e) {
      return UserBootstrapState.error(
        'Failed to load user profile: ${e.toString()}',
        authUser: authUser,
      );
    }
  }
}

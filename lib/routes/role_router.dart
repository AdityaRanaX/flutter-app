import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/widgets/state_message.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/district/screens/district_shell.dart';
import '../features/school_admin/screens/school_admin_shell.dart';
import '../features/student/screens/student_shell.dart';
import '../features/teacher/screens/teacher_shell.dart';
import '../models/user_model.dart';
import '../repositories/firestore_user_repository.dart';
import '../services/auth_service.dart';
import '../services/user_bootstrap_service.dart';
import 'app_routes.dart';

/// Centralized widget evaluating auth state and user profile role to route
/// users to their corresponding dashboard or return to Login.
class RoleRouter extends StatefulWidget {
  final AuthService? authService;
  final UserBootstrapService? bootstrapService;

  const RoleRouter({super.key, this.authService, this.bootstrapService});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final AuthService _authService;
  UserBootstrapService? _bootstrapService;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _bootstrapService = widget.bootstrapService;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: StateMessage(
              type: StateMessageType.loading,
              title: 'Authenticating...',
            ),
          );
        }

        final authUser = authSnapshot.data;
        if (authUser == null) {
          debugPrint(
            '[RoleRouter] No authenticated user. Rendering LoginScreen.',
          );
          return const LoginScreen();
        }

        debugPrint(
          '[RoleRouter] Authenticated user detected. UID: ${authUser.uid}',
        );

        // Authenticated user exists - resolve user profile via UserBootstrapService
        final bootstrapService =
            _bootstrapService ??
            UserBootstrapService(
              authService: _authService,
              userRepository: FirestoreUserRepository(),
            );

        return FutureBuilder<UserBootstrapState>(
          future: bootstrapService.bootstrapUser(authUser),
          builder: (context, bootstrapSnapshot) {
            if (bootstrapSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: StateMessage(
                  type: StateMessageType.loading,
                  title: 'Loading profile...',
                ),
              );
            }

            final bootstrapState = bootstrapSnapshot.data;
            if (bootstrapState == null ||
                bootstrapState.status == UserBootstrapStatus.loading) {
              return const Scaffold(
                body: StateMessage(
                  type: StateMessageType.loading,
                  title: 'Loading profile...',
                ),
              );
            }

            final UserModel? userModel = bootstrapState.userModel;

            debugPrint(
              '[RoleRouter] Bootstrap state: ${bootstrapState.status}, role: ${userModel?.role}',
            );

            if (bootstrapState.status == UserBootstrapStatus.unauthenticated) {
              return const LoginScreen();
            }

            if (bootstrapState.status == UserBootstrapStatus.profileNotFound) {
              return Scaffold(
                body: StateMessage(
                  type: StateMessageType.error,
                  title: 'Profile Not Found',
                  message:
                      'No user profile document found at users/${authUser.uid}. Please check Firestore configuration.',
                  onRetry: () => _authService.signOut(),
                ),
              );
            }

            if (bootstrapState.status == UserBootstrapStatus.invalidProfile) {
              return Scaffold(
                body: StateMessage(
                  type: StateMessageType.unauthorized,
                  title: 'Invalid Role Profile',
                  message: 'Your user profile has an unassigned or invalid role. Please contact support.',
                  onRetry: () => _authService.signOut(),
                ),
              );
            }

            if (bootstrapState.status == UserBootstrapStatus.error) {
              return Scaffold(
                body: StateMessage(
                  type: StateMessageType.error,
                  title: 'Profile Load Error',
                  message:
                      bootstrapState.errorMessage ??
                      'An error occurred loading profile.',
                  onRetry: () => setState(() {}),
                ),
              );
            }

            // Profile found - evaluate role
            final role = userModel?.role;
            final destinationRoute = AppRoutes.getDashboardRouteForRole(role);

            debugPrint(
              '[RoleRouter] Mapped role "$role" to destination route: $destinationRoute',
            );

            if (destinationRoute == null) {
              return Scaffold(
                body: StateMessage(
                  type: StateMessageType.unauthorized,
                  title: 'Invalid Role',
                  message:
                      'Your user profile role ("$role") is invalid or unrecognized. Please contact support.',
                  onRetry: () => _authService.signOut(),
                ),
              );
            }

            switch (destinationRoute) {
              case AppRoutes.districtDashboard:
                return const DistrictShell();
              case AppRoutes.schoolAdminDashboard:
                return const SchoolAdminShell();
              case AppRoutes.teacherDashboard:
                return const TeacherShell();
              case AppRoutes.studentDashboard:
                return const StudentShell();
              default:
                return const LoginScreen();
            }
          },
        );
      },
    );
  }
}

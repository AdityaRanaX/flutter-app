import 'package:flutter/material.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/district/controllers/exam_details_controller.dart';
import '../features/district/controllers/school_details_controller.dart';
import '../features/district/screens/district_shell.dart';
import '../features/district/screens/exam_details_screen.dart';
import '../features/district/screens/school_details_screen.dart';
import '../repositories/firestore_attendance_repository.dart';
import '../repositories/firestore_exam_repository.dart';
import '../repositories/firestore_fee_repository.dart';
import '../repositories/firestore_school_repository.dart';
import '../repositories/firestore_student_repository.dart';
import '../features/school_admin/screens/school_admin_shell.dart';
import '../features/student/screens/student_shell.dart';
import '../features/teacher/screens/teacher_shell.dart';

abstract class AppRoutes {
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String districtDashboard = '/district-dashboard';

  /// Takes the selected school's id as its route argument. The id is
  /// passed rather than the school itself so the details screen reloads
  /// the record instead of trusting data the list happened to be holding.
  static const String schoolDetails = '/school-details';

  /// Takes the selected exam's id as its route argument. A subject is
  /// not enough: several schools and classes can hold an exam in the
  /// same subject.
  static const String examDetails = '/exam-details';
  static const String schoolAdminDashboard = '/school-admin-dashboard';
  static const String teacherDashboard = '/teacher-dashboard';
  static const String studentDashboard = '/student-dashboard';
  static const String profile = '/profile';

  static const String initial = login;

  static String? getDashboardRouteForRole(String? role) {
    if (role == null) return null;
    final normalized = role.toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'districtadmin':
        return districtDashboard;
      case 'schooladmin':
        return schoolAdminDashboard;
      case 'teacher':
        return teacherDashboard;
      case 'student':
        return studentDashboard;
      default:
        return null;
    }
  }

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    resetPassword: (context) => const ResetPasswordScreen(),
    districtDashboard: (context) => const DistrictShell(),
    schoolAdminDashboard: (context) => const SchoolAdminShell(),
    teacherDashboard: (context) => const TeacherShell(),
    studentDashboard: (context) => const StudentShell(),
    profile: (context) => const _PlaceholderScreen(
      title: 'Profile & Settings',
      subtitle: 'User Account Details',
    ),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // School Details is handled before the table because it is the one
    // route that takes an argument, and because its controller needs the
    // Firestore repositories wiring up.
    if (settings.name == schoolDetails) {
      final schoolId = settings.arguments;
      if (schoolId is! String || schoolId.isEmpty) {
        return MaterialPageRoute(
          builder: (context) => const _PlaceholderScreen(
            title: 'School Not Specified',
            subtitle: 'No school was selected, so there is nothing to show.',
          ),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (context) => SchoolDetailsScreen(
          schoolId: schoolId,
          controller: SchoolDetailsController(
            schoolRepository: FirestoreSchoolRepository(),
            studentRepository: FirestoreStudentRepository(),
            attendanceRepository: FirestoreAttendanceRepository(),
            feeRepository: FirestoreFeeRepository(),
            examRepository: FirestoreExamRepository(),
          ),
        ),
        settings: settings,
      );
    }

    if (settings.name == examDetails) {
      final examId = settings.arguments;
      if (examId is! String || examId.isEmpty) {
        return MaterialPageRoute(
          builder: (context) => const _PlaceholderScreen(
            title: 'Exam Not Specified',
            subtitle: 'No exam was selected, so there is nothing to show.',
          ),
          settings: settings,
        );
      }
      return MaterialPageRoute(
        builder: (context) => ExamDetailsScreen(
          examId: examId,
          controller: ExamDetailsController(
            examRepository: FirestoreExamRepository(),
            schoolRepository: FirestoreSchoolRepository(),
            studentRepository: FirestoreStudentRepository(),
          ),
        ),
        settings: settings,
      );
    }

    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return MaterialPageRoute(
      builder: (context) => const _PlaceholderScreen(
        title: 'Destination Not Found',
        subtitle: 'The requested route does not exist.',
      ),
      settings: settings,
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderScreen({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

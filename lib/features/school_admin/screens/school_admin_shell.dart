import 'package:flutter/material.dart';

import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/placeholder_destination.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/firestore_attendance_repository.dart';
import '../../../repositories/firestore_exam_repository.dart';
import '../../../repositories/firestore_fee_repository.dart';
import '../../../repositories/firestore_school_repository.dart';
import '../../../repositories/firestore_student_repository.dart';
import '../../../repositories/firestore_user_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/user_bootstrap_service.dart';
import '../controllers/school_admin_dashboard_controller.dart';
import '../controllers/school_info_controller.dart';
import 'school_admin_dashboard_screen.dart';
import 'school_info_screen.dart';

/// The School Administrator navigation container.
///
/// Supplies the School Admin navigation tabs to [AppShell], owns the
/// dashboard and school info controllers, and handles tab selection.
class SchoolAdminShell extends StatefulWidget {
  final String? schoolId;
  final String? administratorName;
  final SchoolAdminDashboardController? dashboardController;
  final SchoolInfoController? schoolInfoController;
  final SchoolRepository? schoolRepository;
  final StudentRepository? studentRepository;
  final UserRepository? userRepository;
  final AttendanceRepository? attendanceRepository;
  final FeeRepository? feeRepository;
  final ExamRepository? examRepository;
  final UserBootstrapService? bootstrapService;

  const SchoolAdminShell({
    super.key,
    this.schoolId,
    this.administratorName,
    this.dashboardController,
    this.schoolInfoController,
    this.schoolRepository,
    this.studentRepository,
    this.userRepository,
    this.attendanceRepository,
    this.feeRepository,
    this.examRepository,
    this.bootstrapService,
  });

  @override
  State<SchoolAdminShell> createState() => _SchoolAdminShellState();
}

class _SchoolAdminShellState extends State<SchoolAdminShell> {
  int _currentIndex = 0;

  late final SchoolAdminDashboardController _dashboardController;
  late final SchoolInfoController _schoolInfoController;

  @override
  void initState() {
    super.initState();
    final userRepository = widget.userRepository ?? FirestoreUserRepository();
    final schoolRepository =
        widget.schoolRepository ?? FirestoreSchoolRepository();
    final bootstrapService =
        widget.bootstrapService ??
        UserBootstrapService(userRepository: userRepository);

    _dashboardController =
        widget.dashboardController ??
        SchoolAdminDashboardController(
          schoolRepository: schoolRepository,
          studentRepository:
              widget.studentRepository ?? FirestoreStudentRepository(),
          userRepository: userRepository,
          attendanceRepository:
              widget.attendanceRepository ?? FirestoreAttendanceRepository(),
          feeRepository: widget.feeRepository ?? FirestoreFeeRepository(),
          examRepository: widget.examRepository ?? FirestoreExamRepository(),
          bootstrapService: bootstrapService,
        );

    _schoolInfoController =
        widget.schoolInfoController ??
        SchoolInfoController(
          schoolRepository: schoolRepository,
          bootstrapService: bootstrapService,
        );
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    _schoolInfoController.dispose();
    super.dispose();
  }

  static const List<AppNavItem> _tabs = [
    AppNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    AppNavItem(
      label: 'Students',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
    ),
    AppNavItem(
      label: 'School',
      icon: Icons.school_outlined,
      activeIcon: Icons.school,
    ),
    AppNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  Widget _destination(int index) {
    switch (index) {
      case 0:
        return SchoolAdminDashboardScreen(
          controller: _dashboardController,
          schoolId: widget.schoolId,
        );
      case 1:
        return const PlaceholderDestination(
          title: 'Students & Fees',
          icon: Icons.groups_outlined,
        );
      case 2:
        return SchoolInfoScreen(
          controller: _schoolInfoController,
          schoolId: widget.schoolId,
        );
      default:
        return const PlaceholderDestination(
          title: 'Profile',
          icon: Icons.person_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      items: _tabs,
      currentIndex: _currentIndex,
      onItemSelected: (index) => setState(() => _currentIndex = index),
      appBar: AppScreenBar.large(title: _tabs[_currentIndex].label),
      body: _destination(_currentIndex),
    );
  }
}

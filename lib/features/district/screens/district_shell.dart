import 'package:flutter/material.dart';

import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/placeholder_destination.dart';
import '../../../repositories/firestore_attendance_repository.dart';
import '../../../repositories/firestore_exam_repository.dart';
import '../../../repositories/firestore_fee_repository.dart';
import '../../../repositories/firestore_school_repository.dart';
import '../../../repositories/firestore_student_repository.dart';
import '../../../repositories/firestore_user_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../routes/app_routes.dart';
import '../controllers/district_dashboard_controller.dart';
import '../controllers/exam_overview_controller.dart';
import '../controllers/district_data_loader.dart';
import '../controllers/school_list_controller.dart';
import 'district_dashboard_screen.dart';
import 'district_exam_overview_screen.dart';
import 'school_list_screen.dart';

/// The District Administrator navigation container.
///
/// It supplies the District tab set to the shared [AppShell], owns the
/// controllers behind the Home and Schools tabs, and remembers which tab
/// is open. The shell itself knows nothing about roles; this file is what
/// makes it a District experience.
///
/// This is the composition root for the District feature: the Firestore
/// repositories are wired up here, so no screen or controller below
/// reaches for `FirebaseFirestore.instance` itself.
class DistrictShell extends StatefulWidget {
  /// Supplied by tests with fake repositories. Left null in the app, where
  /// the real Firestore-backed loader is built instead.
  final DistrictDataLoader? loader;

  /// Shown in the dashboard greeting.
  final String? administratorName;

  /// Supplied by tests. The Exams tab reads exams and schools directly
  /// rather than through [loader], which gathers the dashboard's figures.
  final ExamRepository? examRepository;
  final SchoolRepository? schoolRepository;

  const DistrictShell({
    super.key,
    this.loader,
    this.administratorName,
    this.examRepository,
    this.schoolRepository,
  });

  @override
  State<DistrictShell> createState() => _DistrictShellState();
}

class _DistrictShellState extends State<DistrictShell> {
  /// Which tab is open. Starts on the first one.
  int _currentIndex = 0;

  late final DistrictDataLoader _loader;
  late final DistrictDashboardController _dashboardController;
  late final SchoolListController _schoolListController;
  late final ExamOverviewController _examOverviewController;

  @override
  void initState() {
    super.initState();
    _loader = widget.loader ?? _firestoreLoader();
    _dashboardController = DistrictDashboardController(loader: _loader);
    _schoolListController = SchoolListController(loader: _loader);
    _examOverviewController = ExamOverviewController(
      examRepository: widget.examRepository ?? FirestoreExamRepository(),
      schoolRepository: widget.schoolRepository ?? FirestoreSchoolRepository(),
    );
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    _schoolListController.dispose();
    _examOverviewController.dispose();
    super.dispose();
  }

  static DistrictDataLoader _firestoreLoader() => DistrictDataLoader(
    schoolRepository: FirestoreSchoolRepository(),
    studentRepository: FirestoreStudentRepository(),
    userRepository: FirestoreUserRepository(),
    attendanceRepository: FirestoreAttendanceRepository(),
    feeRepository: FirestoreFeeRepository(),
    examRepository: FirestoreExamRepository(),
  );

  static const List<AppNavItem> _tabs = [
    AppNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    AppNavItem(
      label: 'Schools',
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment,
    ),
    AppNavItem(
      label: 'Exams',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
    ),
    AppNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  void _openSchools() => setState(() => _currentIndex = 1);

  void _openSchoolDetails(String schoolId) {
    Navigator.of(context)
        .pushNamed(AppRoutes.schoolDetails, arguments: schoolId);
  }

  void _openExamDetails(String examId) {
    Navigator.of(context).pushNamed(AppRoutes.examDetails, arguments: examId);
  }

  Widget _destination(int index) {
    switch (index) {
      case 0:
        return DistrictDashboardScreen(
          controller: _dashboardController,
          administratorName: widget.administratorName,
          onViewSchools: _openSchools,
        );
      case 1:
        return SchoolListScreen(
          controller: _schoolListController,
          onSchoolSelected: _openSchoolDetails,
        );
      case 2:
        return DistrictExamOverviewScreen(
          controller: _examOverviewController,
          onExamSelected: _openExamDetails,
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

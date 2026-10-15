import 'package:flutter/material.dart';

import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/placeholder_destination.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/firestore_exam_repository.dart';
import '../../../repositories/firestore_school_repository.dart';
import '../../../repositories/firestore_user_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/user_bootstrap_service.dart';
import '../../school_admin/controllers/school_exam_schedule_controller.dart';
import '../../school_admin/screens/school_exam_schedule_screen.dart';

/// The Student navigation container.
class StudentShell extends StatefulWidget {
  final String? schoolId;
  final ExamRepository? examRepository;
  final SchoolRepository? schoolRepository;
  final UserRepository? userRepository;
  final UserBootstrapService? bootstrapService;
  final SchoolExamScheduleController? examScheduleController;

  const StudentShell({
    super.key,
    this.schoolId,
    this.examRepository,
    this.schoolRepository,
    this.userRepository,
    this.bootstrapService,
    this.examScheduleController,
  });

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  late final SchoolExamScheduleController _examScheduleController;

  @override
  void initState() {
    super.initState();
    final userRepository = widget.userRepository ?? FirestoreUserRepository();
    _examScheduleController =
        widget.examScheduleController ??
        SchoolExamScheduleController(
          examRepository: widget.examRepository ?? FirestoreExamRepository(),
          schoolRepository:
              widget.schoolRepository ?? FirestoreSchoolRepository(),
          bootstrapService:
              widget.bootstrapService ??
              UserBootstrapService(userRepository: userRepository),
        );
  }

  @override
  void dispose() {
    _examScheduleController.dispose();
    super.dispose();
  }

  static const List<AppNavItem> _tabs = [
    AppNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
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

  Widget _destination(int index) {
    switch (index) {
      case 0:
        return const PlaceholderDestination(
          title: 'Student Home',
          icon: Icons.home_outlined,
        );
      case 1:
        return SchoolExamScheduleScreen(
          controller: _examScheduleController,
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

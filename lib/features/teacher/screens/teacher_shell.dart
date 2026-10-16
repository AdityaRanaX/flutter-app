import 'package:flutter/material.dart';

import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/placeholder_destination.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/firestore_attendance_repository.dart';
import '../../../repositories/firestore_exam_repository.dart';
import '../../../repositories/firestore_school_repository.dart';
import '../../../repositories/firestore_student_repository.dart';
import '../../../repositories/firestore_user_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/user_bootstrap_service.dart';
import '../../school_admin/controllers/school_exam_schedule_controller.dart';
import '../../school_admin/screens/school_exam_schedule_screen.dart';
import '../controllers/attendance_management_controller.dart';
import 'attendance_management_screen.dart';

/// The Teacher navigation container.
class TeacherShell extends StatefulWidget {
  final String? schoolId;
  final String? teacherId;
  final AttendanceRepository? attendanceRepository;
  final StudentRepository? studentRepository;
  final ExamRepository? examRepository;
  final SchoolRepository? schoolRepository;
  final UserRepository? userRepository;
  final UserBootstrapService? bootstrapService;
  final AttendanceManagementController? attendanceController;
  final SchoolExamScheduleController? examScheduleController;

  const TeacherShell({
    super.key,
    this.schoolId,
    this.teacherId,
    this.attendanceRepository,
    this.studentRepository,
    this.examRepository,
    this.schoolRepository,
    this.userRepository,
    this.bootstrapService,
    this.attendanceController,
    this.examScheduleController,
  });

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;

  late final AttendanceManagementController _attendanceController;
  late final SchoolExamScheduleController _examScheduleController;

  @override
  void initState() {
    super.initState();
    final userRepository = widget.userRepository ?? FirestoreUserRepository();
    final bootstrapService =
        widget.bootstrapService ??
        UserBootstrapService(userRepository: userRepository);

    _attendanceController =
        widget.attendanceController ??
        AttendanceManagementController(
          studentRepository:
              widget.studentRepository ?? FirestoreStudentRepository(),
          attendanceRepository:
              widget.attendanceRepository ?? FirestoreAttendanceRepository(),
          bootstrapService: bootstrapService,
        );

    _examScheduleController =
        widget.examScheduleController ??
        SchoolExamScheduleController(
          examRepository: widget.examRepository ?? FirestoreExamRepository(),
          schoolRepository:
              widget.schoolRepository ?? FirestoreSchoolRepository(),
          bootstrapService: bootstrapService,
        );
  }

  @override
  void dispose() {
    _attendanceController.dispose();
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
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check,
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
          title: 'Teacher Home',
          icon: Icons.home_outlined,
        );
      case 1:
        return AttendanceManagementScreen(
          controller: _attendanceController,
          schoolId: widget.schoolId,
          teacherId: widget.teacherId,
        );
      case 2:
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

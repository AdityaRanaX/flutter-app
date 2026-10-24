import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/state/view_state.dart';
import '../../../core/state/safe_notifier.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../../../models/school_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/user_bootstrap_service.dart';

/// Data aggregated for the School Administrator Dashboard.
class SchoolAdminDashboardData {
  final SchoolModel school;
  final UserModel administratorProfile;
  final int totalStudents;
  final int totalTeachers;
  final AttendanceBreakdown attendanceBreakdown;
  final double? attendancePercent;
  final FeeBreakdown feeBreakdown;
  final double? feePaidPercent;
  final List<ExamModel> upcomingExams;

  const SchoolAdminDashboardData({
    required this.school,
    required this.administratorProfile,
    required this.totalStudents,
    required this.totalTeachers,
    required this.attendanceBreakdown,
    required this.attendancePercent,
    required this.feeBreakdown,
    required this.feePaidPercent,
    required this.upcomingExams,
  });
}

/// Drives the School Administrator Dashboard.
///
/// Resolves the authenticated school administrator's assigned school,
/// fetches school-scoped metrics through repositories, and exposes
/// [ViewState] for the UI layer.
class SchoolAdminDashboardController extends ChangeNotifier with SafeNotifier {
  final SchoolRepository schoolRepository;
  final StudentRepository studentRepository;
  final UserRepository userRepository;
  final AttendanceRepository attendanceRepository;
  final FeeRepository feeRepository;
  final ExamRepository examRepository;
  final UserBootstrapService? bootstrapService;
  final DateTime Function() clock;

  /// Window size in days for upcoming exams.
  static const int upcomingExamWindowDays = 7;

  SchoolAdminDashboardController({
    required this.schoolRepository,
    required this.studentRepository,
    required this.userRepository,
    required this.attendanceRepository,
    required this.feeRepository,
    required this.examRepository,
    this.bootstrapService,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<SchoolAdminDashboardData> _state = const ViewState.loading();
  ViewState<SchoolAdminDashboardData> get state => _state;

  /// Loads the dashboard data for the given [schoolId] or the currently
  /// authenticated school administrator profile.
  Future<void> load({String? schoolId, UserModel? profile}) async {
    _state = const ViewState.loading();
    safeNotify();

    try {
      UserModel? adminProfile = profile;
      String? targetSchoolId = schoolId;

      if (adminProfile == null &&
          (targetSchoolId == null || targetSchoolId.isEmpty)) {
        if (bootstrapService == null) {
          _state = const ViewState.error(
            'User bootstrap service is not configured.',
          );
          safeNotify();
          return;
        }

        final bootstrapState = await bootstrapService!.bootstrapUser();
        if (bootstrapState.status != UserBootstrapStatus.profileFound ||
            bootstrapState.userModel == null) {
          _state = const ViewState.unauthorized(
            message: 'Unable to resolve user profile.',
          );
          safeNotify();
          return;
        }

        adminProfile = bootstrapState.userModel;
        targetSchoolId = adminProfile?.schoolId;
      }

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        _state = const ViewState.error(
          'No school is currently assigned to this account.',
        );
        safeNotify();
        return;
      }

      final school = await schoolRepository.getSchoolById(targetSchoolId);
      if (school == null) {
        _state = const ViewState.error('Assigned school could not be found.');
        safeNotify();
        return;
      }

      final students = await studentRepository.getStudentsBySchool(
        targetSchoolId,
      );
      final teachers = await userRepository.getUsersBySchoolAndRole(
        schoolId: targetSchoolId,
        role: UserRoles.teacher,
      );
      final attendance = await attendanceRepository.getAttendanceBySchool(
        targetSchoolId,
      );
      final fees = await feeRepository.getFeesBySchool(targetSchoolId);
      final exams = await examRepository.getExamsBySchool(targetSchoolId);

      final upcoming = Metrics.examsWithinDays(
        exams,
        from: AppDate.today(clock()),
        days: upcomingExamWindowDays,
      );

      final data = SchoolAdminDashboardData(
        school: school,
        administratorProfile:
            adminProfile ??
            UserModel(
              uid: 'admin',
              name: 'School Administrator',
              email: '',
              role: UserRoles.schoolAdmin,
              schoolId: targetSchoolId,
            ),
        totalStudents: students.length,
        totalTeachers: teachers.length,
        attendanceBreakdown: Metrics.attendanceBreakdown(attendance),
        attendancePercent: Metrics.attendancePercentage(attendance),
        feeBreakdown: Metrics.feeBreakdown(fees),
        feePaidPercent: Metrics.feePaidPercentage(fees),
        upcomingExams: upcoming,
      );

      _state = ViewState.ready(data);
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    safeNotify();
  }
}

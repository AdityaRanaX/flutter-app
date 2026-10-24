import 'package:flutter/foundation.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/state/view_state.dart';
import '../../../core/state/safe_notifier.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../../../models/fee_model.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../services/user_bootstrap_service.dart';

/// Everything the Student Dashboard shows, for one signed-in student.
///
/// [exams] is a [ViewState] of its own, which the other sections are not.
/// That is deliberate: attendance and fees are matched to the student by
/// `studentId`, while exams are matched by the student's *school*, under a
/// different Firestore rule. A student whose user profile carries no
/// `schoolId` is denied exams while still being allowed their own
/// attendance and fees, so one denied section must not blank the two that
/// worked. See section 7 of the data-model gap report.
class StudentDashboardData {
  /// The student's own record, resolved from their Auth UID.
  final StudentModel student;

  /// `present / all records * 100`, or null when there are no records.
  ///
  /// Null means "no records to measure", never "attended nothing".
  final double? attendancePercent;

  /// The same records counted into Present / Absent / Leave.
  final AttendanceBreakdown attendanceBreakdown;

  /// How many records the percentage was computed from, so the screen can
  /// say what the number is based on instead of presenting it bare.
  final int attendanceRecordCount;

  /// The student's fee record, or null when none has been raised yet.
  final FeeModel? fee;

  /// Upcoming exams for the student's school and class, soonest first.
  final ViewState<List<ExamModel>> exams;

  const StudentDashboardData({
    required this.student,
    required this.attendancePercent,
    required this.attendanceBreakdown,
    required this.attendanceRecordCount,
    required this.fee,
    required this.exams,
  });

  /// True when no attendance record exists, which the screen shows as
  /// unavailable rather than as 0%.
  bool get hasNoAttendance => attendanceRecordCount == 0;
}

/// Loads the signed-in student's own dashboard data.
///
/// The flow is: Auth UID -> `users` profile -> `students` record ->
/// attendance, fees and exams scoped to that student. Nothing here reads
/// another student's records, and nothing here writes.
///
/// All five [ViewStatus] values are reachable and they mean different
/// things. In particular a permission denial becomes
/// [ViewStatus.unauthorized] and never an empty list, because showing a
/// denial as "no records" would state that the data does not exist when
/// it does.
class StudentDashboardController extends ChangeNotifier with SafeNotifier {
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final FeeRepository feeRepository;
  final ExamRepository examRepository;
  final UserBootstrapService? bootstrapService;

  /// Injectable so "upcoming" is deterministic in tests rather than
  /// depending on the day they happen to run.
  final DateTime Function() clock;

  StudentDashboardController({
    required this.studentRepository,
    required this.attendanceRepository,
    required this.feeRepository,
    required this.examRepository,
    this.bootstrapService,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<StudentDashboardData> _state = const ViewState.loading();
  ViewState<StudentDashboardData> get state => _state;

  /// Loads the dashboard for [profile], or for the currently authenticated
  /// user when [profile] is omitted.
  Future<void> load({UserModel? profile}) async {
    _state = const ViewState.loading();
    safeNotify();

    try {
      final resolved = await _resolveProfile(profile);
      if (resolved == null) return;

      // The approved mapping: a student's records are keyed on their
      // Firebase Auth UID. firestore.rules enforces exactly this, so the
      // app must not look them up by anything else.
      final studentId = resolved.uid;

      final student = await studentRepository.getStudentById(studentId);
      if (student == null) {
        // Not "no data yet" — the signed-in user cannot be matched to a
        // student record at all, so every section below would come back
        // empty for the wrong reason.
        _state = const ViewState.error(
          'Your student record could not be found. Please ask your school '
          'administrator to check your account.',
        );
        safeNotify();
        return;
      }

      final attendance = await attendanceRepository.getAttendanceByStudent(
        studentId,
      );
      final fee = await feeRepository.getFeeByStudentId(studentId);
      final exams = await _loadUpcomingExams(student);

      _state = ViewState.ready(
        StudentDashboardData(
          student: student,
          attendancePercent: Metrics.attendancePercentage(attendance),
          attendanceBreakdown: Metrics.attendanceBreakdown(attendance),
          attendanceRecordCount: attendance.length,
          fee: fee,
          exams: exams,
        ),
      );
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    safeNotify();
  }

  /// Resolves the signed-in student's profile, or sets a failure state and
  /// returns null.
  Future<UserModel?> _resolveProfile(UserModel? given) async {
    var profile = given;

    if (profile == null) {
      if (bootstrapService == null) {
        _state = const ViewState.error(
          'User bootstrap service is not configured.',
        );
        safeNotify();
        return null;
      }

      final bootstrapState = await bootstrapService!.bootstrapUser();
      if (bootstrapState.status != UserBootstrapStatus.profileFound ||
          bootstrapState.userModel == null) {
        _state = const ViewState.unauthorized(
          message: 'Unable to resolve your profile. Please sign in again.',
        );
        safeNotify();
        return null;
      }
      profile = bootstrapState.userModel;
    }

    if (UserRoles.normalise(profile!.role) != UserRoles.student) {
      _state = const ViewState.unauthorized(
        message: 'This dashboard is only available to students.',
      );
      safeNotify();
      return null;
    }

    if (profile.uid.trim().isEmpty) {
      _state = const ViewState.error(
        'Your account is missing an identifier, so your records cannot be '
        'looked up.',
      );
      safeNotify();
      return null;
    }

    return profile;
  }

  /// Upcoming exams for the student's school and class.
  ///
  /// Failures are caught here rather than by [load], so a denied or failed
  /// exam read leaves attendance and fees on screen. An empty schedule and
  /// a denial stay distinguishable: the first is [ViewStatus.empty], the
  /// second [ViewStatus.unauthorized].
  Future<ViewState<List<ExamModel>>> _loadUpcomingExams(
    StudentModel student,
  ) async {
    if (student.schoolId.trim().isEmpty) {
      // No school on the record, so there is nothing to scope a query to.
      // Querying anyway would be a request we already know matches nothing.
      return const ViewState.empty(
        message:
            'Your account is not linked to a school yet, so your exam '
            'schedule is unavailable.',
      );
    }

    try {
      final exams = await examRepository.getExamsBySchoolAndClass(
        schoolId: student.schoolId,
        className: student.className,
      );
      final upcoming = Metrics.upcomingExams(
        exams,
        from: AppDate.today(clock()),
      );
      return ViewState.fromList(
        upcoming,
        emptyMessage: 'No exams are scheduled for your class right now.',
      );
    } catch (e) {
      return ViewState<List<ExamModel>>.fromError(e);
    }
  }
}

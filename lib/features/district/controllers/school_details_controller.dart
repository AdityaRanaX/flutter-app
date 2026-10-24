import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/state/safe_notifier.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../../../models/school_model.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';

/// Everything one school's detail screen shows.
class SchoolDetails {
  final SchoolModel school;
  final int studentCount;
  final AttendanceBreakdown attendance;
  final double? attendancePercent;
  final FeeBreakdown fees;
  final double? feePaidPercent;
  final List<ExamModel> upcomingExams;

  const SchoolDetails({
    required this.school,
    required this.studentCount,
    required this.attendance,
    required this.attendancePercent,
    required this.fees,
    required this.feePaidPercent,
    required this.upcomingExams,
  });
}

/// Drives the School Details screen for one selected school.
///
/// The school is loaded by its id, never by name or list position: two
/// schools can share a name, and a position means nothing once the list
/// has been searched or sorted.
class SchoolDetailsController extends ChangeNotifier with SafeNotifier {
  final SchoolRepository schoolRepository;
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final FeeRepository feeRepository;
  final ExamRepository examRepository;
  final DateTime Function() clock;

  SchoolDetailsController({
    required this.schoolRepository,
    required this.studentRepository,
    required this.attendanceRepository,
    required this.feeRepository,
    required this.examRepository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<SchoolDetails> _state = const ViewState.loading();
  ViewState<SchoolDetails> get state => _state;

  Future<void> load(String schoolId) async {
    _state = const ViewState.loading();
    safeNotify();

    try {
      final school = await schoolRepository.getSchoolById(schoolId);
      if (school == null) {
        // A school that does not exist is a not-found condition. It is
        // deliberately not reported as an empty list, which would imply
        // the school exists but holds no data.
        _state = const ViewState.error('This school could not be found.');
        safeNotify();
        return;
      }

      final students = await studentRepository.getStudentsBySchool(schoolId);
      final attendance = await attendanceRepository.getAttendanceBySchool(
        schoolId,
      );
      final fees = await feeRepository.getFeesBySchool(schoolId);
      final exams = await examRepository.getExamsBySchool(schoolId);

      _state = ViewState.ready(
        SchoolDetails(
          school: school,
          studentCount: students.length,
          attendance: Metrics.attendanceBreakdown(attendance),
          attendancePercent: Metrics.attendancePercentage(attendance),
          fees: Metrics.feeBreakdown(fees),
          feePaidPercent: Metrics.feePaidPercentage(fees),
          upcomingExams: Metrics.upcomingExams(
            exams,
            from: AppDate.today(clock()),
          ),
        ),
      );
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    safeNotify();
  }
}

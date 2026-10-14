import '../../../models/exam_model.dart';
import '../../../models/school_model.dart';

/// One school plus the numbers the District screens show beside it.
///
/// Every field other than [school] is derived from source records at load
/// time. None of it is stored on the school document — see the Day 5
/// data-model gap report for why.
class SchoolSummary {
  final SchoolModel school;
  final int studentCount;
  final int teacherCount;

  /// Null when the school has no attendance records at all, which is a
  /// different fact from 0% and must not be displayed as one.
  final double? attendancePercent;

  /// Null when nothing is due at the school.
  final double? feePaidPercent;

  final int examCount;

  const SchoolSummary({
    required this.school,
    required this.studentCount,
    required this.teacherCount,
    required this.attendancePercent,
    required this.feePaidPercent,
    required this.examCount,
  });

  String get schoolId => school.schoolId;
  String get schoolName => school.schoolName;

  /// Whether this school falls under the dashboard's attention threshold.
  ///
  /// A school with no attendance records is not flagged: there is nothing
  /// to judge it on, and flagging it would read as a performance problem
  /// when it is really missing data.
  bool needsAttention(double threshold) {
    final percent = attendancePercent;
    if (percent == null) return false;
    return percent < threshold;
  }
}

/// Everything the District Dashboard and School List need, loaded once.
class DistrictData {
  final List<SchoolSummary> schools;

  /// Attendance across every record the user may read, not the mean of
  /// the per-school percentages — a small school would otherwise weigh as
  /// heavily as a large one.
  final double? districtAttendancePercent;

  /// Likewise amount-weighted across every fee record.
  final double? districtFeePaidPercent;

  /// Every exam, unfiltered. The dashboard narrows this to a seven-day
  /// window; other screens filter it differently.
  final List<ExamModel> allExams;

  const DistrictData({
    required this.schools,
    required this.districtAttendancePercent,
    required this.districtFeePaidPercent,
    required this.allExams,
  });

  int get totalSchools => schools.length;

  bool get isEmpty => schools.isEmpty;
}

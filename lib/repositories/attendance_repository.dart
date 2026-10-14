import '../models/attendance_model.dart';

/// Reads and writes daily attendance records.
///
/// These are *daily classroom* attendance records. They are not tied to
/// any particular exam, and must not be used to say whether a student sat
/// an exam — that relationship does not exist in the approved model. See
/// the data-model gap report.
abstract class AttendanceRepository {
  /// Attendance for one school on one date. Backs the teacher's daily
  /// attendance screen.
  Future<List<AttendanceModel>> getAttendanceBySchoolAndDate({
    required String schoolId,
    required String date,
  });

  /// Every attendance record for [schoolId].
  ///
  /// Attendance percentage is derived from these records rather than
  /// stored on the school, so the caller reads them and does the sum.
  Future<List<AttendanceModel>> getAttendanceBySchool(String schoolId);

  /// Every attendance record for one student, for their own attendance
  /// percentage on the Student Dashboard.
  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId);

  /// Creates or replaces a single record, keyed on its `attendanceId`.
  Future<void> saveAttendance(AttendanceModel attendance);

  /// Writes a whole class's attendance in one atomic batch.
  ///
  /// Taking attendance marks every student at once, and a half-saved
  /// register is worse than a failed one, so the batch either lands
  /// completely or not at all.
  Future<void> saveAttendanceBatch(List<AttendanceModel> records);
}

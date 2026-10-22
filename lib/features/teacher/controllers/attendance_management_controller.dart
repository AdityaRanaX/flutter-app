import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/attendance_model.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../services/user_bootstrap_service.dart';

/// Classroom student attendance record item for the daily register.
class StudentAttendanceItem {
  final StudentModel student;
  final AttendanceModel? attendance;
  String currentStatus;

  StudentAttendanceItem({
    required this.student,
    this.attendance,
    String? currentStatus,
  }) : currentStatus = currentStatus ?? (attendance?.status ?? 'Present');
}

/// Data payload for the Attendance Management screen.
class AttendanceManagementData {
  final String schoolId;
  final String date;
  final List<StudentAttendanceItem> items;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final double? attendanceRate;

  const AttendanceManagementData({
    required this.schoolId,
    required this.date,
    required this.items,
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.attendanceRate,
  });
}

/// Drives the daily classroom Attendance Management workflow for Teachers and Admins.
class AttendanceManagementController extends ChangeNotifier {
  final StudentRepository studentRepository;
  final AttendanceRepository attendanceRepository;
  final UserBootstrapService? bootstrapService;
  final DateTime Function() clock;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  AttendanceManagementController({
    required this.studentRepository,
    required this.attendanceRepository,
    this.bootstrapService,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<AttendanceManagementData> _state = const ViewState.loading();
  ViewState<AttendanceManagementData> get state => _state;

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _selectedDate;
  String get selectedDate =>
      _selectedDate ?? _formatDate(AppDate.today(clock()));

  /// Loads daily classroom attendance for [schoolId] on [date].
  Future<void> loadAttendance({
    String? schoolId,
    String? date,
    UserModel? profile,
  }) async {
    _state = const ViewState.loading();
    _saveError = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      String? targetSchoolId = schoolId;

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        UserModel? userProfile = profile;
        if (userProfile == null && bootstrapService != null) {
          final bootstrapState = await bootstrapService!.bootstrapUser();
          if (bootstrapState.status == UserBootstrapStatus.profileFound) {
            userProfile = bootstrapState.userModel;
          }
        }
        targetSchoolId = userProfile?.schoolId;
      }

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        _state = const ViewState.error(
          'No school is currently assigned to this account.',
        );
        notifyListeners();
        return;
      }

      _selectedDate = date ?? _formatDate(AppDate.today(clock()));
      final targetDate = _selectedDate!;

      final students = await studentRepository.getStudentsBySchool(
        targetSchoolId,
      );
      final records = await attendanceRepository.getAttendanceBySchoolAndDate(
        schoolId: targetSchoolId,
        date: targetDate,
      );

      final recordMap = {for (var r in records) r.studentId: r};

      final items = students
          .map(
            (s) => StudentAttendanceItem(
              student: s,
              attendance: recordMap[s.studentId],
              currentStatus: recordMap[s.studentId]?.status ?? 'Present',
            ),
          )
          .toList();

      if (items.isEmpty) {
        _state = ViewState.empty(
          message: 'No student records found for this school.',
        );
        notifyListeners();
        return;
      }

      final presentCount = items
          .where((i) => i.currentStatus.toLowerCase() == 'present')
          .length;
      final absentCount = items.length - presentCount;
      final rate = records.isEmpty
          ? (items.isEmpty ? null : (presentCount / items.length * 100))
          : Metrics.attendancePercentage(records);

      final data = AttendanceManagementData(
        schoolId: targetSchoolId,
        date: targetDate,
        items: items,
        totalStudents: items.length,
        presentCount: presentCount,
        absentCount: absentCount,
        attendanceRate: rate,
      );

      _state = ViewState.ready(data);
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  /// Updates status for a single student item locally before batch save.
  void updateItemStatus(String studentId, String status) {
    final data = _state.data;
    if (data == null) return;

    final normStatus = status.trim().toLowerCase() == 'absent'
        ? 'Absent'
        : 'Present';

    for (final item in data.items) {
      if (item.student.studentId == studentId) {
        item.currentStatus = normStatus;
        break;
      }
    }

    notifyListeners();
  }

  /// Sets all students in current register to [status] ('Present' or 'Absent').
  void markAll(String status) {
    final data = _state.data;
    if (data == null) return;

    final normStatus = status.trim().toLowerCase() == 'absent'
        ? 'Absent'
        : 'Present';

    for (final item in data.items) {
      item.currentStatus = normStatus;
    }

    notifyListeners();
  }

  /// Saves the complete class attendance register in an atomic batch write.
  Future<bool> saveAttendanceRegister({
    required String schoolId,
    required String teacherId,
    required String date,
  }) async {
    if (_isSaving) return false;

    final data = _state.data;
    if (data == null || data.items.isEmpty) return false;

    _isSaving = true;
    _saveError = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      final batchRecords = data.items.map((item) {
        final existingId = item.attendance?.attendanceId;
        final attendanceId = (existingId != null && existingId.isNotEmpty)
            ? existingId
            : 'att_${item.student.studentId}_$date';

        return AttendanceModel(
          attendanceId: attendanceId,
          studentId: item.student.studentId,
          schoolId: schoolId,
          teacherId: teacherId.isNotEmpty ? teacherId : 'teacher',
          date: date,
          status: item.currentStatus,
        );
      }).toList();

      await attendanceRepository.saveAttendanceBatch(batchRecords);

      _saveSuccess = true;
      _isSaving = false;

      await loadAttendance(schoolId: schoolId, date: date);
      return true;
    } catch (e) {
      _isSaving = false;
      final viewError = ViewState<AttendanceManagementData>.fromError(e);
      _saveError = viewError.message ?? 'Failed to save attendance register.';
      notifyListeners();
      return false;
    }
  }
}

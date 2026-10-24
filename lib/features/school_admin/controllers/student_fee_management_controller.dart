import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/state/safe_notifier.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/fee_model.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../services/user_bootstrap_service.dart';

/// Combined student and fee information for display in the management table/list.
class StudentFeeListItem {
  final StudentModel student;
  final FeeModel? fee;

  const StudentFeeListItem({required this.student, this.fee});
}

/// Aggregated data for Student/Fee Management screen.
class StudentFeeData {
  final String schoolId;
  final List<StudentFeeListItem> items;
  final int totalStudents;
  final double? feePaidPercent;
  final FeeBreakdown feeBreakdown;

  const StudentFeeData({
    required this.schoolId,
    required this.items,
    required this.totalStudents,
    required this.feePaidPercent,
    required this.feeBreakdown,
  });
}

/// Drives the Student/Fee Management screen for School Administrators.
class StudentFeeManagementController extends ChangeNotifier with SafeNotifier {
  final StudentRepository studentRepository;
  final FeeRepository feeRepository;
  final UserBootstrapService? bootstrapService;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  StudentFeeManagementController({
    required this.studentRepository,
    required this.feeRepository,
    this.bootstrapService,
  });

  ViewState<StudentFeeData> _state = const ViewState.loading();
  ViewState<StudentFeeData> get state => _state;

  /// Loads student and fee records for the specified [schoolId] or authenticated user.
  Future<void> load({String? schoolId, UserModel? profile}) async {
    _state = const ViewState.loading();
    _saveError = null;
    _saveSuccess = false;
    safeNotify();

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
        safeNotify();
        return;
      }

      final students = await studentRepository.getStudentsBySchool(
        targetSchoolId,
      );
      final fees = await feeRepository.getFeesBySchool(targetSchoolId);

      final feeMap = {for (var f in fees) f.studentId: f};

      final items = students
          .map((s) => StudentFeeListItem(student: s, fee: feeMap[s.studentId]))
          .toList();

      if (items.isEmpty) {
        _state = ViewState.empty(
          message: 'No student records found for this school.',
        );
        safeNotify();
        return;
      }

      final data = StudentFeeData(
        schoolId: targetSchoolId,
        items: items,
        totalStudents: students.length,
        feePaidPercent: Metrics.feePaidPercentage(fees),
        feeBreakdown: Metrics.feeBreakdown(fees),
      );

      _state = ViewState.ready(data);
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    safeNotify();
  }

  /// Updates a student's fee status, paid amount, and remarks note while
  /// preserving all unrelated fields (`feeId`, `studentId`, `schoolId`, `totalDue`).
  Future<bool> updateFeeRecord({
    required FeeModel currentFee,
    required String newStatus,
    double? newPaidAmount,
    String? newRemarks,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _saveError = null;
    _saveSuccess = false;
    safeNotify();

    try {
      final updatedFee = currentFee.copyWith(
        status: newStatus,
        paidAmount: newPaidAmount ?? currentFee.paidAmount,
        remarks: newRemarks?.trim().isEmpty == true ? null : newRemarks?.trim(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      await feeRepository.updateFeeStatus(updatedFee);

      _isSaving = false;

      // Reload data to reflect updated fee details across the list
      final currentSchoolId = _state.data?.schoolId ?? currentFee.schoolId;
      await load(schoolId: currentSchoolId);

      // Recorded after the reload, because load() clears the save flags.
      // Setting it first meant the screen was never told the save worked.
      _saveSuccess = true;
      safeNotify();
      return true;
    } catch (e) {
      _isSaving = false;
      final viewError = ViewState<StudentFeeData>.fromError(e);
      _saveError = viewError.message ?? 'Failed to update fee status.';
      safeNotify();
      return false;
    }
  }

  void resetSaveStatus() {
    _saveSuccess = false;
    _saveError = null;
    safeNotify();
  }
}

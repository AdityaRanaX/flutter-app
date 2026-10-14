import '../models/fee_model.dart';

/// Reads and updates student fee records.
abstract class FeeRepository {
  /// The fee record for one student, or null when none exists.
  Future<FeeModel?> getFeeByStudentId(String studentId);

  /// Every fee record at [schoolId].
  ///
  /// The fees-paid percentage and the Paid / Partial / Outstanding
  /// breakdown are both derived from these records; neither is stored on
  /// the school document.
  Future<List<FeeModel>> getFeesBySchool(String schoolId);

  /// Creates or replaces a fee record, keyed on its `feeId`.
  ///
  /// The School Admin's Edit Fee Status screen is the only approved
  /// writer. `totalDue` and `paidAmount` keep their existing meaning —
  /// this does not recompute them from the status.
  Future<void> updateFeeStatus(FeeModel fee);
}

class FeeModel {
  final String feeId;
  final String studentId;
  final String schoolId;
  final double totalDue;
  final double paidAmount;
  final String status;
  final String updatedAt;
  final String? remarks;

  const FeeModel({
    required this.feeId,
    required this.studentId,
    required this.schoolId,
    required this.totalDue,
    required this.paidAmount,
    required this.status,
    required this.updatedAt,
    this.remarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'feeId': feeId,
      'studentId': studentId,
      'schoolId': schoolId,
      'totalDue': totalDue,
      'paidAmount': paidAmount,
      'status': status,
      'updatedAt': updatedAt,
      'remarks': remarks,
    };
  }

  factory FeeModel.fromMap(Map<String, dynamic> map) {
    return FeeModel(
      feeId: map['feeId'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      schoolId: map['schoolId'] as String? ?? '',
      totalDue: (map['totalDue'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? '',
      updatedAt: map['updatedAt'] as String? ?? '',
      remarks: map['remarks'] as String?,
    );
  }

  FeeModel copyWith({
    String? feeId,
    String? studentId,
    String? schoolId,
    double? totalDue,
    double? paidAmount,
    String? status,
    String? updatedAt,
    String? remarks,
  }) {
    return FeeModel(
      feeId: feeId ?? this.feeId,
      studentId: studentId ?? this.studentId,
      schoolId: schoolId ?? this.schoolId,
      totalDue: totalDue ?? this.totalDue,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
    );
  }
}

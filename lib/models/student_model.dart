class StudentModel {
  final String studentId;
  final String name;
  final String schoolId;
  final String className;
  final String section;
  final String? rollNumber;

  const StudentModel({
    required this.studentId,
    required this.name,
    required this.schoolId,
    required this.className,
    required this.section,
    this.rollNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'name': name,
      'schoolId': schoolId,
      'className': className,
      'section': section,
      'rollNumber': rollNumber,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      studentId: map['studentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      schoolId: map['schoolId'] as String? ?? '',
      className: map['className'] as String? ?? '',
      section: map['section'] as String? ?? '',
      rollNumber: map['rollNumber'] as String?,
    );
  }

  StudentModel copyWith({
    String? studentId,
    String? name,
    String? schoolId,
    String? className,
    String? section,
    String? rollNumber,
  }) {
    return StudentModel(
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      schoolId: schoolId ?? this.schoolId,
      className: className ?? this.className,
      section: section ?? this.section,
      rollNumber: rollNumber ?? this.rollNumber,
    );
  }
}

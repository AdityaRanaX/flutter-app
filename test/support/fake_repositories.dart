import 'package:my_flutter_edulens/models/attendance_model.dart';
import 'package:my_flutter_edulens/models/exam_model.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/attendance_repository.dart';
import 'package:my_flutter_edulens/repositories/exam_repository.dart';
import 'package:my_flutter_edulens/repositories/fee_repository.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';
import 'package:my_flutter_edulens/repositories/school_repository.dart';
import 'package:my_flutter_edulens/repositories/student_repository.dart';
import 'package:my_flutter_edulens/repositories/user_repository.dart';

/// In-memory repositories for widget and controller tests.
///
/// They hold records in lists rather than talking to Firestore, and each
/// one can be told to fail, so a screen's error and unauthorized paths can
/// be exercised without a network.
///
/// These fakes verify how the UI *responds* to a permission error. They
/// prove nothing about whether the real Firestore rules are correct —
/// that stays a separate verification gate.
mixin FailableRepository {
  /// Set to make every call throw. Use [RepositoryErrorKind.permissionDenied]
  /// to drive the unauthorized state.
  RepositoryErrorKind? failWith;

  void _maybeFail(String action) {
    final kind = failWith;
    if (kind == null) return;
    throw RepositoryException(kind, 'Fake failure while trying to $action.');
  }
}

class FakeSchoolRepository with FailableRepository implements SchoolRepository {
  final List<SchoolModel> schools = [];

  @override
  Future<List<SchoolModel>> getSchools() async {
    _maybeFail('load schools');
    return List.of(schools);
  }

  @override
  Future<SchoolModel?> getSchoolById(String schoolId) async {
    _maybeFail('load this school');
    for (final s in schools) {
      if (s.schoolId == schoolId) return s;
    }
    return null;
  }
}

class FakeStudentRepository
    with FailableRepository
    implements StudentRepository {
  final List<StudentModel> students = [];

  @override
  Future<List<StudentModel>> getStudentsBySchool(String schoolId) async {
    _maybeFail('load students');
    return students.where((s) => s.schoolId == schoolId).toList();
  }

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    _maybeFail('load this student');
    for (final s in students) {
      if (s.studentId == studentId) return s;
    }
    return null;
  }

  @override
  Future<List<StudentModel>> getStudentsBySchoolAndClass({
    required String schoolId,
    required String className,
  }) async {
    _maybeFail('load students for this class');
    return students
        .where((s) => s.schoolId == schoolId && s.className == className)
        .toList();
  }
}

class FakeUserRepository with FailableRepository implements UserRepository {
  final List<UserModel> users = [];

  @override
  Future<UserModel?> getUserById(String uid) async {
    _maybeFail('load your profile');
    for (final u in users) {
      if (u.uid == uid) return u;
    }
    return null;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    _maybeFail('save this profile');
    users.removeWhere((u) => u.uid == user.uid);
    users.add(user);
  }

  @override
  Future<List<UserModel>> getUsersBySchoolAndRole({
    required String schoolId,
    required String role,
  }) async {
    _maybeFail('load staff for this school');
    return users
        .where((u) => u.schoolId == schoolId && u.role == role)
        .toList();
  }
}

class FakeAttendanceRepository
    with FailableRepository
    implements AttendanceRepository {
  final List<AttendanceModel> records = [];

  @override
  Future<List<AttendanceModel>> getAttendanceBySchoolAndDate({
    required String schoolId,
    required String date,
  }) async {
    _maybeFail('load attendance');
    return records
        .where((a) => a.schoolId == schoolId && a.date == date)
        .toList();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceBySchool(String schoolId) async {
    _maybeFail('load attendance');
    return records.where((a) => a.schoolId == schoolId).toList();
  }

  @override
  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId) async {
    _maybeFail('load attendance');
    return records.where((a) => a.studentId == studentId).toList();
  }

  @override
  Future<void> saveAttendance(AttendanceModel attendance) async {
    _maybeFail('save attendance');
    records.removeWhere((a) => a.attendanceId == attendance.attendanceId);
    records.add(attendance);
  }

  @override
  Future<void> saveAttendanceBatch(List<AttendanceModel> batch) async {
    _maybeFail('save attendance');
    for (final record in batch) {
      records.removeWhere((a) => a.attendanceId == record.attendanceId);
      records.add(record);
    }
  }
}

class FakeFeeRepository with FailableRepository implements FeeRepository {
  final List<FeeModel> fees = [];

  @override
  Future<FeeModel?> getFeeByStudentId(String studentId) async {
    _maybeFail('load fee details');
    for (final f in fees) {
      if (f.studentId == studentId) return f;
    }
    return null;
  }

  @override
  Future<List<FeeModel>> getFeesBySchool(String schoolId) async {
    _maybeFail('load fee details');
    return fees.where((f) => f.schoolId == schoolId).toList();
  }

  @override
  Future<void> updateFeeStatus(FeeModel fee) async {
    _maybeFail('update this fee record');
    fees.removeWhere((f) => f.feeId == fee.feeId);
    fees.add(fee);
  }
}

class FakeExamRepository with FailableRepository implements ExamRepository {
  final List<ExamModel> exams = [];

  @override
  Future<List<ExamModel>> getExamsBySchool(String schoolId) async {
    _maybeFail('load exams');
    return exams.where((e) => e.schoolId == schoolId).toList();
  }

  @override
  Future<List<ExamModel>> getAllExams() async {
    _maybeFail('load exams');
    return List.of(exams);
  }

  @override
  Future<ExamModel?> getExamById(String examId) async {
    _maybeFail('load this exam');
    for (final e in exams) {
      if (e.examId == examId) return e;
    }
    return null;
  }

  @override
  Future<void> saveExam(ExamModel exam) async {
    _maybeFail('save this exam');
    exams.removeWhere((e) => e.examId == exam.examId);
    exams.add(exam);
  }
}

// ---------------------------------------------------------------- builders

SchoolModel school(String id, {String? name, String location = 'Zone'}) =>
    SchoolModel(
      schoolId: id,
      schoolName: name ?? 'School $id',
      location: location,
    );

StudentModel student(
  String id, {
  required String schoolId,
  String className = 'Class 10',
  String? name,
}) => StudentModel(
  studentId: id,
  name: name ?? 'Student $id',
  schoolId: schoolId,
  className: className,
  section: 'A',
);

UserModel teacher(String id, {required String schoolId}) => UserModel(
  uid: id,
  name: 'Teacher $id',
  email: '$id@edulens.test',
  role: 'teacher',
  schoolId: schoolId,
);

AttendanceModel attendance(
  String id, {
  required String schoolId,
  required String status,
  String studentId = 'st1',
  String date = '2026-10-10',
}) => AttendanceModel(
  attendanceId: id,
  studentId: studentId,
  schoolId: schoolId,
  teacherId: 't1',
  date: date,
  status: status,
);

FeeModel fee(
  String id, {
  required String schoolId,
  required double totalDue,
  required double paidAmount,
  required String status,
  String studentId = 'st1',
}) => FeeModel(
  feeId: id,
  studentId: studentId,
  schoolId: schoolId,
  totalDue: totalDue,
  paidAmount: paidAmount,
  status: status,
  updatedAt: '2026-10-01',
);

ExamModel exam(
  String id, {
  required String schoolId,
  required String date,
  String subject = 'Science',
  String className = 'Class 10',
}) => ExamModel(
  examId: id,
  schoolId: schoolId,
  className: className,
  subject: subject,
  date: date,
  startTime: '10:00',
  endTime: '12:00',
  createdBy: 't1',
);

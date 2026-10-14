import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/models/attendance_model.dart';
import 'package:my_flutter_edulens/models/exam_model.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/attendance_repository.dart';
import 'package:my_flutter_edulens/repositories/exam_repository.dart';
import 'package:my_flutter_edulens/repositories/fee_repository.dart';
import 'package:my_flutter_edulens/repositories/school_repository.dart';
import 'package:my_flutter_edulens/repositories/student_repository.dart';
import 'package:my_flutter_edulens/repositories/user_repository.dart';

class TestUserRepository implements UserRepository {
  final List<UserModel> users = [];

  @override
  Future<UserModel?> getUserById(String uid) async {
    for (final u in users) {
      if (u.uid == uid) return u;
    }
    return null;
  }

  @override
  Future<void> saveUser(UserModel user) async {
    users.removeWhere((u) => u.uid == user.uid);
    users.add(user);
  }

  @override
  Future<List<UserModel>> getUsersBySchoolAndRole({
    required String schoolId,
    required String role,
  }) async =>
      users.where((u) => u.schoolId == schoolId && u.role == role).toList();
}

class TestSchoolRepository implements SchoolRepository {
  final List<SchoolModel> schools = [];

  @override
  Future<List<SchoolModel>> getSchools() async => schools;

  @override
  Future<SchoolModel?> getSchoolById(String schoolId) async {
    for (final s in schools) {
      if (s.schoolId == schoolId) return s;
    }
    return null;
  }
}

class TestStudentRepository implements StudentRepository {
  final List<StudentModel> students = [];

  @override
  Future<List<StudentModel>> getStudentsBySchool(String schoolId) async =>
      students.where((s) => s.schoolId == schoolId).toList();

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    for (final s in students) {
      if (s.studentId == studentId) return s;
    }
    return null;
  }

  @override
  Future<List<StudentModel>> getStudentsBySchoolAndClass({
    required String schoolId,
    required String className,
  }) async => students
      .where((s) => s.schoolId == schoolId && s.className == className)
      .toList();
}

class TestAttendanceRepository implements AttendanceRepository {
  final List<AttendanceModel> records = [];

  @override
  Future<List<AttendanceModel>> getAttendanceBySchoolAndDate({
    required String schoolId,
    required String date,
  }) async =>
      records.where((a) => a.schoolId == schoolId && a.date == date).toList();

  @override
  Future<List<AttendanceModel>> getAttendanceBySchool(String schoolId) async =>
      records.where((a) => a.schoolId == schoolId).toList();

  @override
  Future<List<AttendanceModel>> getAttendanceByStudent(
    String studentId,
  ) async => records.where((a) => a.studentId == studentId).toList();

  @override
  Future<void> saveAttendance(AttendanceModel attendance) async {
    records.removeWhere((a) => a.attendanceId == attendance.attendanceId);
    records.add(attendance);
  }

  @override
  Future<void> saveAttendanceBatch(List<AttendanceModel> batch) async {
    for (final record in batch) {
      await saveAttendance(record);
    }
  }
}

class TestFeeRepository implements FeeRepository {
  final List<FeeModel> fees = [];

  @override
  Future<FeeModel?> getFeeByStudentId(String studentId) async {
    for (final f in fees) {
      if (f.studentId == studentId) return f;
    }
    return null;
  }

  @override
  Future<List<FeeModel>> getFeesBySchool(String schoolId) async =>
      fees.where((f) => f.schoolId == schoolId).toList();

  @override
  Future<void> updateFeeStatus(FeeModel fee) async {
    fees.removeWhere((f) => f.feeId == fee.feeId);
    fees.add(fee);
  }
}

class TestExamRepository implements ExamRepository {
  final List<ExamModel> exams = [];

  @override
  Future<List<ExamModel>> getExamsBySchool(String schoolId) async =>
      exams.where((e) => e.schoolId == schoolId).toList();

  @override
  Future<List<ExamModel>> getAllExams() async => exams;

  @override
  Future<ExamModel?> getExamById(String examId) async {
    for (final e in exams) {
      if (e.examId == examId) return e;
    }
    return null;
  }

  @override
  Future<void> saveExam(ExamModel exam) async {
    exams.removeWhere((e) => e.examId == exam.examId);
    exams.add(exam);
  }
}

void main() {
  group('Repository Contracts Tests', () {
    test('UserRepository contract test', () async {
      final repo = TestUserRepository();
      const user = UserModel(
        uid: 'u1',
        name: 'Admin',
        email: 'admin@edulens.org',
        role: 'district_admin',
      );
      await repo.saveUser(user);
      final fetched = await repo.getUserById('u1');
      expect(fetched?.name, 'Admin');
    });

    test('SchoolRepository contract test', () async {
      final repo = TestSchoolRepository();
      const school = SchoolModel(
        schoolId: 's1',
        schoolName: 'City Academy',
        location: 'North Zone',
      );
      repo.schools.add(school);
      final fetched = await repo.getSchoolById('s1');
      expect(fetched?.schoolName, 'City Academy');
    });

    test('StudentRepository contract test', () async {
      final repo = TestStudentRepository();
      const student = StudentModel(
        studentId: 'st1',
        name: 'Bob',
        schoolId: 's1',
        className: '10',
        section: 'B',
      );
      repo.students.add(student);
      final list = await repo.getStudentsBySchool('s1');
      expect(list.length, 1);
      expect(list.first.name, 'Bob');
    });

    test('AttendanceRepository contract test', () async {
      final repo = TestAttendanceRepository();
      const record = AttendanceModel(
        attendanceId: 'att1',
        studentId: 'st1',
        schoolId: 's1',
        teacherId: 't1',
        date: '2026-03-30',
        status: 'Present',
      );
      await repo.saveAttendance(record);
      final list = await repo.getAttendanceBySchoolAndDate(
        schoolId: 's1',
        date: '2026-03-30',
      );
      expect(list.length, 1);
      expect(list.first.status, 'Present');
    });

    test('FeeRepository contract test', () async {
      final repo = TestFeeRepository();
      const fee = FeeModel(
        feeId: 'f1',
        studentId: 'st1',
        schoolId: 's1',
        totalDue: 1000.0,
        paidAmount: 1000.0,
        status: 'Paid',
        updatedAt: '2026-03-30',
      );
      await repo.updateFeeStatus(fee);
      final fetched = await repo.getFeeByStudentId('st1');
      expect(fetched?.status, 'Paid');
    });

    test('ExamRepository contract test', () async {
      final repo = TestExamRepository();
      const exam = ExamModel(
        examId: 'ex1',
        schoolId: 's1',
        className: '10',
        subject: 'Science',
        date: '2026-04-15',
        startTime: '10:00 AM',
        endTime: '01:00 PM',
        createdBy: 't1',
      );
      await repo.saveExam(exam);
      final list = await repo.getExamsBySchool('s1');
      expect(list.length, 1);
      expect(list.first.subject, 'Science');
    });
  });

  group('Read contracts added for the District screens', () {
    test(
      'teacher count comes from users filtered by school and role',
      () async {
        final repo = TestUserRepository();
        await repo.saveUser(
          const UserModel(
            uid: 't1',
            name: 'Priya',
            email: 'priya@edulens.test',
            role: 'teacher',
            schoolId: 's1',
          ),
        );
        await repo.saveUser(
          const UserModel(
            uid: 't2',
            name: 'Rahul',
            email: 'rahul@edulens.test',
            role: 'teacher',
            schoolId: 's1',
          ),
        );
        // A teacher at a different school, and a student at the same one:
        // neither should be counted.
        await repo.saveUser(
          const UserModel(
            uid: 't3',
            name: 'Arjun',
            email: 'arjun@edulens.test',
            role: 'teacher',
            schoolId: 's2',
          ),
        );
        await repo.saveUser(
          const UserModel(
            uid: 's9',
            name: 'Meera',
            email: 'meera@edulens.test',
            role: 'student',
            schoolId: 's1',
          ),
        );

        final teachers = await repo.getUsersBySchoolAndRole(
          schoolId: 's1',
          role: 'teacher',
        );
        expect(teachers.length, 2);
        expect(teachers.map((t) => t.uid), containsAll(['t1', 't2']));
      },
    );

    test('students narrow by school AND class, not school alone', () async {
      final repo = TestStudentRepository();
      repo.students.addAll(const [
        StudentModel(
          studentId: 'a',
          name: 'A',
          schoolId: 's1',
          className: 'Class 10',
          section: 'A',
        ),
        StudentModel(
          studentId: 'b',
          name: 'B',
          schoolId: 's1',
          className: 'Class 9',
          section: 'A',
        ),
        StudentModel(
          studentId: 'c',
          name: 'C',
          schoolId: 's2',
          className: 'Class 10',
          section: 'A',
        ),
      ]);

      final list = await repo.getStudentsBySchoolAndClass(
        schoolId: 's1',
        className: 'Class 10',
      );
      expect(list.length, 1);
      expect(list.first.studentId, 'a');
    });

    test('attendance can be read whole-school and per-student', () async {
      final repo = TestAttendanceRepository();
      await repo.saveAttendanceBatch(const [
        AttendanceModel(
          attendanceId: 'a1',
          studentId: 'st1',
          schoolId: 's1',
          teacherId: 't1',
          date: '2026-03-30',
          status: 'Present',
        ),
        AttendanceModel(
          attendanceId: 'a2',
          studentId: 'st2',
          schoolId: 's1',
          teacherId: 't1',
          date: '2026-03-30',
          status: 'Absent',
        ),
        AttendanceModel(
          attendanceId: 'a3',
          studentId: 'st1',
          schoolId: 's1',
          teacherId: 't1',
          date: '2026-03-31',
          status: 'Present',
        ),
      ]);

      expect((await repo.getAttendanceBySchool('s1')).length, 3);
      expect((await repo.getAttendanceByStudent('st1')).length, 2);
      expect((await repo.getAttendanceBySchool('s2')), isEmpty);
    });

    test(
      'saving the same attendance id twice replaces, never duplicates',
      () async {
        final repo = TestAttendanceRepository();
        const first = AttendanceModel(
          attendanceId: 'a1',
          studentId: 'st1',
          schoolId: 's1',
          teacherId: 't1',
          date: '2026-03-30',
          status: 'Absent',
        );
        await repo.saveAttendance(first);
        await repo.saveAttendance(first.copyWith(status: 'Present'));

        final all = await repo.getAttendanceBySchool('s1');
        expect(all.length, 1);
        expect(all.first.status, 'Present');
      },
    );

    test('fees can be read for a whole school', () async {
      final repo = TestFeeRepository();
      await repo.updateFeeStatus(
        const FeeModel(
          feeId: 'f1',
          studentId: 'st1',
          schoolId: 's1',
          totalDue: 1000,
          paidAmount: 1000,
          status: 'Paid',
          updatedAt: '2026-03-30',
        ),
      );
      await repo.updateFeeStatus(
        const FeeModel(
          feeId: 'f2',
          studentId: 'st2',
          schoolId: 's1',
          totalDue: 1000,
          paidAmount: 0,
          status: 'Outstanding',
          updatedAt: '2026-03-30',
        ),
      );
      await repo.updateFeeStatus(
        const FeeModel(
          feeId: 'f3',
          studentId: 'st3',
          schoolId: 's2',
          totalDue: 1000,
          paidAmount: 500,
          status: 'Partial',
          updatedAt: '2026-03-30',
        ),
      );

      final fees = await repo.getFeesBySchool('s1');
      expect(fees.length, 2);
      expect(fees.map((f) => f.status), containsAll(['Paid', 'Outstanding']));
    });

    test('exams can be read district-wide and fetched by id', () async {
      final repo = TestExamRepository();
      await repo.saveExam(
        const ExamModel(
          examId: 'ex1',
          schoolId: 's1',
          className: 'Class 10',
          subject: 'Maths',
          date: '2026-04-15',
          startTime: '10:00',
          endTime: '12:00',
          createdBy: 't1',
        ),
      );
      await repo.saveExam(
        const ExamModel(
          examId: 'ex2',
          schoolId: 's2',
          className: 'Class 10',
          subject: 'Maths',
          date: '2026-04-16',
          startTime: '10:00',
          endTime: '12:00',
          createdBy: 't2',
        ),
      );

      expect((await repo.getAllExams()).length, 2);
      expect((await repo.getExamsBySchool('s1')).length, 1);

      // Two exams share a subject, which is exactly why the details
      // screen is reached by id rather than by subject.
      final byId = await repo.getExamById('ex2');
      expect(byId?.schoolId, 's2');
      expect(await repo.getExamById('nope'), isNull);
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/features/district/controllers/district_dashboard_controller.dart';
import 'package:my_flutter_edulens/features/district/controllers/district_data_loader.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_exam_schedule_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_info_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/student_fee_management_controller.dart';
import 'package:my_flutter_edulens/features/student/controllers/student_dashboard_controller.dart';
import 'package:my_flutter_edulens/features/teacher/controllers/attendance_management_controller.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

/// Cross-role journeys over **one shared set of repositories**.
///
/// Each role's controller reads the same records, so a write made through
/// one role's screen is observed through another's. That is the property
/// these tests exist for: not that each screen works alone, but that the
/// four roles agree about the same underlying data.
///
/// These are mocked repository tests. They execute no Firestore rules and
/// make no claim about live latency; runtime authorization is covered by
/// `test/rules/rules.test.mjs`.
const String kSchoolA = 'sch-a';
const String kSchoolB = 'sch-b';
final DateTime kToday = DateTime(2026, 10, 24);
const String kTodayStr = '2026-10-24';

/// A student repository whose reads can be held open, for testing what
/// happens when a screen is disposed while a load is still running.
class _GatedStudentRepository extends FakeStudentRepository {
  Completer<void>? gate;

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    final open = gate;
    if (open != null) await open.future;
    return super.getStudentById(studentId);
  }

  @override
  Future<List<StudentModel>> getStudentsBySchool(String schoolId) async {
    final open = gate;
    if (open != null) await open.future;
    return super.getStudentsBySchool(schoolId);
  }
}

/// One district, two schools, with staff and students in each.
///
/// Every controller below is built over these same instances, which is
/// what makes the cross-role assertions meaningful.
class _District {
  final schools = FakeSchoolRepository();
  final students = _GatedStudentRepository();
  final users = FakeUserRepository();
  final attendance = FakeAttendanceRepository();
  final fees = FakeFeeRepository();
  final exams = FakeExamRepository();

  _District() {
    schools.schools.addAll([
      school(kSchoolA, name: 'Riverside High'),
      school(kSchoolB, name: 'Hillcrest'),
    ]);
    students.students.addAll([
      student('stu-a1', schoolId: kSchoolA, name: 'Asha'),
      student('stu-a2', schoolId: kSchoolA, name: 'Bala'),
      student('stu-b1', schoolId: kSchoolB, name: 'Chen'),
    ]);
    users.users.addAll([
      teacher('teach-a', schoolId: kSchoolA),
      teacher('teach-b', schoolId: kSchoolB),
    ]);
    fees.fees.addAll([
      fee(
        'fee-a1',
        schoolId: kSchoolA,
        totalDue: 1000,
        paidAmount: 0,
        status: 'Outstanding',
        studentId: 'stu-a1',
      ),
      fee(
        'fee-a2',
        schoolId: kSchoolA,
        totalDue: 1000,
        paidAmount: 1000,
        status: 'Paid',
        studentId: 'stu-a2',
      ),
    ]);
    exams.exams.add(exam('exam-a1', schoolId: kSchoolA, date: '2026-10-28'));
  }

  DistrictDataLoader get loader => DistrictDataLoader(
    schoolRepository: schools,
    studentRepository: students,
    userRepository: users,
    attendanceRepository: attendance,
    feeRepository: fees,
    examRepository: exams,
  );

  DistrictDashboardController district() =>
      DistrictDashboardController(loader: loader, clock: () => kToday);

  AttendanceManagementController register() => AttendanceManagementController(
    studentRepository: students,
    attendanceRepository: attendance,
    clock: () => kToday,
  );

  StudentFeeManagementController feeDesk() => StudentFeeManagementController(
    studentRepository: students,
    feeRepository: fees,
  );

  SchoolExamScheduleController schedule() => SchoolExamScheduleController(
    examRepository: exams,
    schoolRepository: schools,
    clock: () => kToday,
  );

  SchoolInfoController info() =>
      SchoolInfoController(schoolRepository: schools);

  StudentDashboardController studentDash() => StudentDashboardController(
    studentRepository: students,
    attendanceRepository: attendance,
    feeRepository: fees,
    examRepository: exams,
    clock: () => kToday,
  );
}

UserModel studentProfile(String uid) => UserModel(
  uid: uid,
  name: uid,
  email: '$uid@edulens.test',
  role: 'student',
  schoolId: kSchoolA,
);

void main() {
  late _District d;

  setUp(() => d = _District());

  group('Journey A — district monitoring', () {
    test('the district sees every configured school and its figures', () async {
      final district = d.district();
      await district.load();

      expect(district.state.status, ViewStatus.ready);
      expect(district.totalSchools, 2);
      // No attendance anywhere yet, so the rate is unavailable rather
      // than zero.
      expect(district.averageAttendance, isNull);
      // 1000 paid of 2000 due across school A.
      expect(district.feesPaidPercent, 50);
      expect(district.upcomingExams.map((e) => e.examId), ['exam-a1']);
    });
  });

  group('Journey B — school admin updates', () {
    test('a fee update reaches the district dashboard', () async {
      final district = d.district();
      await district.load();
      expect(district.feesPaidPercent, 50);

      final desk = d.feeDesk();
      await desk.load(schoolId: kSchoolA);
      final outstanding = desk.state.data!.items
          .firstWhere((i) => i.student.studentId == 'stu-a1')
          .fee!;
      await desk.updateFeeRecord(
        currentFee: outstanding,
        newStatus: 'Paid',
        newPaidAmount: 1000,
      );

      // The district reads the same records, so a reload reflects the
      // school admin's change without either screen knowing about the
      // other.
      await district.load();
      expect(district.feesPaidPercent, 100);
    });

    test('a school information edit is visible on reload', () async {
      final info = d.info();
      await info.load(schoolId: kSchoolA);
      await info.saveSchoolInfo(
        schoolId: kSchoolA,
        address: '12 Station Road',
        email: 'office@riverside.test',
      );

      final reopened = d.info();
      await reopened.load(schoolId: kSchoolA);
      expect(reopened.state.data!.address, '12 Station Road');
      expect(reopened.state.data!.email, 'office@riverside.test');
      // The identity of the record is untouched by an edit.
      expect(reopened.state.data!.schoolName, 'Riverside High');
    });
  });

  group('Journey C — teacher attendance', () {
    test('a saved register changes what the district reports', () async {
      final register = d.register();
      await register.loadAttendance(schoolId: kSchoolA, date: kTodayStr);
      register.markAll('Present');
      register.updateItemStatus('stu-a2', 'Absent');
      final saved = await register.saveAttendanceRegister(
        schoolId: kSchoolA,
        teacherId: 'teach-a',
        date: kTodayStr,
      );

      expect(saved, isTrue);

      final district = d.district();
      await district.load();
      // One present of two records in the whole district.
      expect(district.averageAttendance, 50);
    });

    test('a saved register changes what that student sees', () async {
      final register = d.register();
      await register.loadAttendance(schoolId: kSchoolA, date: kTodayStr);
      register.markAll('Present');
      await register.saveAttendanceRegister(
        schoolId: kSchoolA,
        teacherId: 'teach-a',
        date: kTodayStr,
      );

      final dash = d.studentDash();
      await dash.load(profile: studentProfile('stu-a1'));

      expect(dash.state.status, ViewStatus.ready);
      expect(dash.state.data!.attendancePercent, 100);
      // Still only their own record, not the classmate's.
      expect(dash.state.data!.attendanceRecordCount, 1);
    });
  });

  group('Journey D — teacher examination schedule', () {
    test('a new exam reaches the district and the student', () async {
      final schedule = d.schedule();
      await schedule.load(schoolId: kSchoolA);
      await schedule.addExam(
        schoolId: kSchoolA,
        subject: 'Biology',
        className: 'Class 10',
        date: '2026-10-27',
        startTime: '09:00',
        endTime: '11:00',
        createdBy: 'teach-a',
      );

      final district = d.district();
      await district.load();
      expect(district.upcomingExams.map((e) => e.subject), contains('Biology'));

      final dash = d.studentDash();
      await dash.load(profile: studentProfile('stu-a1'));
      expect(
        dash.state.data!.exams.data!.map((e) => e.subject),
        contains('Biology'),
      );
      // Soonest first: the new exam precedes the seeded one.
      expect(dash.state.data!.exams.data!.first.subject, 'Biology');
    });
  });

  group('Journey E — student read-only dashboard', () {
    test('a student sees their own records and nobody else"s', () async {
      d.attendance.records.addAll([
        attendance(
          'att-a1',
          schoolId: kSchoolA,
          status: 'Present',
          studentId: 'stu-a1',
        ),
        attendance(
          'att-a2',
          schoolId: kSchoolA,
          status: 'Absent',
          studentId: 'stu-a2',
        ),
      ]);

      final dash = d.studentDash();
      await dash.load(profile: studentProfile('stu-a1'));
      final data = dash.state.data!;

      expect(data.student.studentId, 'stu-a1');
      expect(data.attendanceRecordCount, 1);
      expect(data.attendancePercent, 100);
      expect(data.fee!.feeId, 'fee-a1');
    });

    test('a student with no records gets empty, not an error', () async {
      final dash = d.studentDash();
      await dash.load(profile: studentProfile('stu-a2'));

      expect(dash.state.status, ViewStatus.ready);
      expect(dash.state.data!.attendancePercent, isNull);
      expect(dash.state.data!.exams.status, ViewStatus.ready);
    });
  });

  group('Reliability — failures leave a safe, honest state', () {
    test('a service outage ends in error, not a stuck spinner', () async {
      d.schools.failWith = RepositoryErrorKind.unavailable;
      final district = d.district();
      await district.load();

      expect(district.state.status, ViewStatus.error);
      expect(district.state.isLoading, isFalse);
    });

    test('a denial is unauthorized and carries no record data', () async {
      d.fees.failWith = RepositoryErrorKind.permissionDenied;
      final dash = d.studentDash();
      await dash.load(profile: studentProfile('stu-a1'));

      expect(dash.state.status, ViewStatus.unauthorized);
      // The message explains the denial without naming records.
      final message = dash.state.message ?? '';
      expect(message, isNot(contains('fee-a1')));
      expect(message, isNot(contains('stu-a1')));
    });

    test('a transient failure recovers on retry', () async {
      final district = d.district();
      d.schools.failWith = RepositoryErrorKind.unavailable;
      await district.load();
      expect(district.state.status, ViewStatus.error);

      // The retry the error state offers.
      d.schools.failWith = null;
      await district.load();

      expect(district.state.status, ViewStatus.ready);
      expect(district.totalSchools, 2);
    });

    test('retrying a write does not duplicate it', () async {
      final desk = d.feeDesk();
      await desk.load(schoolId: kSchoolA);
      final target = desk.state.data!.items
          .firstWhere((i) => i.student.studentId == 'stu-a1')
          .fee!;

      await desk.updateFeeRecord(currentFee: target, newStatus: 'Partial');
      await desk.updateFeeRecord(currentFee: target, newStatus: 'Paid');

      // Keyed on feeId, so a repeat is an update and not a second record.
      expect(d.fees.fees.where((f) => f.feeId == 'fee-a1').length, 1);
      expect(d.fees.fees.length, 2);
    });

    test('a failed write reports failure and changes nothing', () async {
      final desk = d.feeDesk();
      await desk.load(schoolId: kSchoolA);
      final target = desk.state.data!.items
          .firstWhere((i) => i.student.studentId == 'stu-a1')
          .fee!;

      d.fees.failWith = RepositoryErrorKind.unavailable;
      final saved = await desk.updateFeeRecord(
        currentFee: target,
        newStatus: 'Paid',
        newPaidAmount: 1000,
      );

      expect(saved, isFalse);
      expect(desk.saveError, isNotNull);
      expect(desk.saveSuccess, isFalse);
      expect(desk.isSaving, isFalse);
      // The stored record is untouched.
      expect(
        d.fees.fees.firstWhere((f) => f.feeId == 'fee-a1').status,
        'Outstanding',
      );
    });

    test('repeated reloads do not accumulate records', () async {
      final district = d.district();
      await district.load();
      await district.load();
      await district.load();

      expect(district.totalSchools, 2);
      expect(district.upcomingExams.length, 1);
    });

    test('disposing mid-load does not throw', () async {
      // Navigating away while a read is still in flight: the controller
      // must not notify listeners after disposal.
      final gate = Completer<void>();
      d.students.gate = gate;

      final dash = d.studentDash();
      final pending = dash.load(profile: studentProfile('stu-a1'));

      dash.dispose();
      gate.complete();

      await expectLater(pending, completes);
    });
  });
}

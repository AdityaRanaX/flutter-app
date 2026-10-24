import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_exam_schedule_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_info_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/student_fee_management_controller.dart';
import 'package:my_flutter_edulens/features/teacher/controllers/attendance_management_controller.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

/// Update-propagation tests: after a write succeeds, does the value the
/// screen shows actually come back from the store?
///
/// These are **mocked repository tests**. They exercise the application's
/// write-then-refresh path and prove nothing about live Firestore latency,
/// network behaviour or Security Rules. Measured freshness against a real
/// backend is reported separately in `docs/DAY12_INTEGRATION_REPORT.md`.
const String kSchoolA = 'sch-a';
const String kSchoolB = 'sch-b';
final DateTime kToday = DateTime(2026, 10, 24);

String get kTodayString => '2026-10-24';

/// A school store that normalises on write, the way a real backend may.
///
/// It exists to separate two things that optimistic UI conflates: the
/// value that was *submitted* and the value that is *stored*. A screen
/// that echoes the submission looks identical to a correct one until the
/// store disagrees.
class _NormalisingSchoolRepository extends FakeSchoolRepository {
  @override
  Future<void> saveSchool(SchoolModel school) async {
    await super.saveSchool(school.copyWith(email: school.email?.toLowerCase()));
  }
}

/// A fee store whose write succeeds and whose next read fails, modelling a
/// connection lost between saving and refreshing.
class _RefreshFailsFeeRepository extends FakeFeeRepository {
  bool _written = false;

  @override
  Future<void> updateFeeStatus(FeeModel fee) async {
    await super.updateFeeStatus(fee);
    _written = true;
  }

  @override
  Future<List<FeeModel>> getFeesBySchool(String schoolId) async {
    if (_written) {
      throw const RepositoryException(
        RepositoryErrorKind.unavailable,
        'Could not reach the server while refreshing.',
      );
    }
    return super.getFeesBySchool(schoolId);
  }
}

void main() {
  group('Attendance update propagation', () {
    late FakeStudentRepository students;
    late FakeAttendanceRepository attendance;
    late AttendanceManagementController controller;

    setUp(() {
      students = FakeStudentRepository()
        ..students.addAll([
          student('stu-1', schoolId: kSchoolA),
          student('stu-2', schoolId: kSchoolA),
        ]);
      attendance = FakeAttendanceRepository();
      controller = AttendanceManagementController(
        studentRepository: students,
        attendanceRepository: attendance,
        clock: () => kToday,
      );
    });

    test('a saved register is stored and read back into the state', () async {
      await controller.loadAttendance(schoolId: kSchoolA, date: kTodayString);
      controller.markAll('Present');
      controller.updateItemStatus('stu-2', 'Absent');

      final saved = await controller.saveAttendanceRegister(
        schoolId: kSchoolA,
        teacherId: 'teacher-1',
        date: kTodayString,
      );

      expect(saved, isTrue);
      // Reached the store ...
      expect(attendance.records.length, 2);
      // ... and the refreshed state reflects what the store now holds.
      final data = controller.state.data!;
      expect(data.presentCount, 1);
      expect(data.absentCount, 1);
      expect(data.attendanceRate, 50);
    });

    test('a saved register reports success to the screen', () async {
      await controller.loadAttendance(schoolId: kSchoolA, date: kTodayString);
      controller.markAll('Present');

      await controller.saveAttendanceRegister(
        schoolId: kSchoolA,
        teacherId: 'teacher-1',
        date: kTodayString,
      );

      // The refresh that follows a save must not erase the outcome of the
      // save, or the teacher is never told it worked.
      expect(controller.saveSuccess, isTrue);
      expect(controller.isSaving, isFalse);
      expect(controller.saveError, isNull);
    });

    test(
      're-saving the same register updates rather than duplicates',
      () async {
        await controller.loadAttendance(schoolId: kSchoolA, date: kTodayString);
        controller.markAll('Present');
        await controller.saveAttendanceRegister(
          schoolId: kSchoolA,
          teacherId: 'teacher-1',
          date: kTodayString,
        );

        controller.markAll('Absent');
        await controller.saveAttendanceRegister(
          schoolId: kSchoolA,
          teacherId: 'teacher-1',
          date: kTodayString,
        );

        // Two students, saved twice: still two records, not four. A retry
        // must not fork a student's day into competing records.
        expect(attendance.records.length, 2);
        expect(controller.state.data!.absentCount, 2);
      },
    );
  });

  group('Fee update propagation', () {
    late FakeStudentRepository students;
    late FakeFeeRepository fees;
    late StudentFeeManagementController controller;

    setUp(() {
      students = FakeStudentRepository()
        ..students.add(student('stu-1', schoolId: kSchoolA));
      fees = FakeFeeRepository()
        ..fees.add(
          fee(
            'fee-1',
            schoolId: kSchoolA,
            totalDue: 1000,
            paidAmount: 0,
            status: 'Outstanding',
            studentId: 'stu-1',
          ),
        );
      controller = StudentFeeManagementController(
        studentRepository: students,
        feeRepository: fees,
      );
    });

    test('an updated fee is stored and read back into the list', () async {
      await controller.load(schoolId: kSchoolA);
      final current = controller.state.data!.items.first.fee!;

      final saved = await controller.updateFeeRecord(
        currentFee: current,
        newStatus: 'Paid',
        newPaidAmount: 1000,
        newRemarks: 'Settled in full',
      );

      expect(saved, isTrue);
      expect(fees.fees.single.status, 'Paid');

      final refreshed = controller.state.data!.items.first.fee!;
      expect(refreshed.status, 'Paid');
      expect(refreshed.paidAmount, 1000);
      expect(refreshed.remarks, 'Settled in full');
      // The derived figure is recomputed from the refreshed records.
      expect(controller.state.data!.feePaidPercent, 100);
    });

    test('an updated fee reports success to the screen', () async {
      await controller.load(schoolId: kSchoolA);
      final current = controller.state.data!.items.first.fee!;

      await controller.updateFeeRecord(
        currentFee: current,
        newStatus: 'Partial',
        newPaidAmount: 400,
      );

      expect(controller.saveSuccess, isTrue);
      expect(controller.isSaving, isFalse);
    });

    test('an update preserves the identifiers it must not change', () async {
      await controller.load(schoolId: kSchoolA);
      final current = controller.state.data!.items.first.fee!;

      await controller.updateFeeRecord(
        currentFee: current,
        newStatus: 'Partial',
        newPaidAmount: 400,
      );

      final stored = fees.fees.single;
      expect(stored.feeId, 'fee-1');
      expect(stored.studentId, 'stu-1');
      expect(stored.schoolId, kSchoolA);
      expect(stored.totalDue, 1000);
    });

    test(
      'a failed refresh after a successful write surfaces an error',
      () async {
        final failing = _RefreshFailsFeeRepository()
          ..fees.add(
            fee(
              'fee-1',
              schoolId: kSchoolA,
              totalDue: 1000,
              paidAmount: 0,
              status: 'Outstanding',
              studentId: 'stu-1',
            ),
          );
        final c = StudentFeeManagementController(
          studentRepository: students,
          feeRepository: failing,
        );
        await c.load(schoolId: kSchoolA);
        final current = c.state.data!.items.first.fee!;

        await c.updateFeeRecord(currentFee: current, newStatus: 'Paid');

        // The write landed, the refresh did not. The screen must say so
        // rather than sitting on a spinner or showing the pre-write list as
        // though it were current.
        expect(failing.fees.single.status, 'Paid');
        expect(c.state.status, ViewStatus.error);
        expect(c.isSaving, isFalse);
      },
    );
  });

  group('Exam update propagation', () {
    test('a new exam appears in the refreshed schedule', () async {
      final exams = FakeExamRepository();
      final schools = FakeSchoolRepository()..schools.add(school(kSchoolA));
      final controller = SchoolExamScheduleController(
        examRepository: exams,
        schoolRepository: schools,
        clock: () => kToday,
      );

      await controller.load(schoolId: kSchoolA);
      expect(controller.state.status, ViewStatus.empty);

      final saved = await controller.addExam(
        schoolId: kSchoolA,
        subject: 'Chemistry',
        className: 'Class 10',
        date: '2026-10-30',
        startTime: '09:00',
        endTime: '11:00',
        createdBy: 'teacher-1',
      );

      expect(saved, isTrue);
      expect(exams.exams.single.subject, 'Chemistry');
      expect(controller.state.status, ViewStatus.ready);
      expect(
        controller.state.data!.map((e) => e.subject),
        contains('Chemistry'),
      );
    });
  });

  group('School information update propagation', () {
    test('the screen shows the stored value, not the submitted one', () async {
      final schools = _NormalisingSchoolRepository()
        ..schools.add(school(kSchoolA));
      final controller = SchoolInfoController(schoolRepository: schools);

      await controller.load(schoolId: kSchoolA);

      final saved = await controller.saveSchoolInfo(
        schoolId: kSchoolA,
        address: '12 Station Road',
        contactNumber: '0123456789',
        email: 'Office@SchoolA.EDU',
      );

      expect(saved, isTrue);
      // The store normalised the address of record.
      expect(schools.schools.single.email, 'office@schoola.edu');
      // So must the screen. Echoing the submitted value would present an
      // unconfirmed write as though it were stored data.
      expect(controller.state.data!.email, 'office@schoola.edu');
      expect(controller.state.data!.address, '12 Station Road');
    });

    test('a saved change reports success to the screen', () async {
      final schools = FakeSchoolRepository()..schools.add(school(kSchoolA));
      final controller = SchoolInfoController(schoolRepository: schools);
      await controller.load(schoolId: kSchoolA);

      await controller.saveSchoolInfo(
        schoolId: kSchoolA,
        address: '12 Station Road',
      );

      expect(controller.saveSuccess, isTrue);
      expect(controller.isSaving, isFalse);
    });

    test('identifiers survive an edit', () async {
      final schools = FakeSchoolRepository()
        ..schools.add(school(kSchoolA, name: 'Riverside High'));
      final controller = SchoolInfoController(schoolRepository: schools);
      await controller.load(schoolId: kSchoolA);

      await controller.saveSchoolInfo(
        schoolId: kSchoolA,
        address: '12 Station Road',
      );

      final stored = schools.schools.single;
      expect(stored.schoolId, kSchoolA);
      expect(stored.schoolName, 'Riverside High');
    });
  });

  group('Refreshing does not widen access', () {
    test('a fee refresh returns only the acting school', () async {
      final students = FakeStudentRepository()
        ..students.addAll([
          student('stu-a', schoolId: kSchoolA),
          student('stu-b', schoolId: kSchoolB),
        ]);
      final fees = FakeFeeRepository()
        ..fees.addAll([
          fee(
            'fee-a',
            schoolId: kSchoolA,
            totalDue: 1000,
            paidAmount: 0,
            status: 'Outstanding',
            studentId: 'stu-a',
          ),
          fee(
            'fee-b',
            schoolId: kSchoolB,
            totalDue: 500,
            paidAmount: 500,
            status: 'Paid',
            studentId: 'stu-b',
          ),
        ]);
      final controller = StudentFeeManagementController(
        studentRepository: students,
        feeRepository: fees,
      );

      await controller.load(schoolId: kSchoolA);
      final current = controller.state.data!.items.first.fee!;
      await controller.updateFeeRecord(
        currentFee: current,
        newStatus: 'Paid',
        newPaidAmount: 1000,
      );

      // The reload after a write is a fresh scoped query, not a widened
      // one: the other school's records are still absent.
      final ids = controller.state.data!.items.map((i) => i.student.studentId);
      expect(ids, ['stu-a']);
      expect(
        fees.fees.firstWhere((f) => f.feeId == 'fee-b').schoolId,
        kSchoolB,
      );
    });

    test('an attendance refresh returns only the acting school', () async {
      final students = FakeStudentRepository()
        ..students.addAll([
          student('stu-a', schoolId: kSchoolA),
          student('stu-b', schoolId: kSchoolB),
        ]);
      final attendance = FakeAttendanceRepository();
      final controller = AttendanceManagementController(
        studentRepository: students,
        attendanceRepository: attendance,
        clock: () => kToday,
      );

      await controller.loadAttendance(schoolId: kSchoolA, date: kTodayString);
      controller.markAll('Present');
      await controller.saveAttendanceRegister(
        schoolId: kSchoolA,
        teacherId: 'teacher-1',
        date: kTodayString,
      );

      expect(controller.state.data!.items.length, 1);
      expect(controller.state.data!.items.single.student.studentId, 'stu-a');
      // Nothing was written against the other school.
      expect(attendance.records.every((r) => r.schoolId == kSchoolA), isTrue);
    });
  });
}

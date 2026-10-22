import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/state_message.dart';
import 'package:my_flutter_edulens/core/utils/metrics.dart';
import 'package:my_flutter_edulens/features/student/controllers/student_dashboard_controller.dart';
import 'package:my_flutter_edulens/features/student/screens/student_dashboard_screen.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

/// The signed-in student. Their `students` record is keyed on this same
/// value, which is the identity mapping firestore.rules enforces.
const String kUid = 'student-uid-1';

/// Fixed so "upcoming" never depends on the day the suite runs.
final DateTime kToday = DateTime(2026, 10, 20);

UserModel studentProfile({
  String uid = kUid,
  String role = 'student',
  String? schoolId = 'sch1',
}) => UserModel(
  uid: uid,
  name: 'Asha Rao',
  email: 'asha@edulens.test',
  role: role,
  schoolId: schoolId,
);

StudentModel studentRecord({
  String id = kUid,
  String schoolId = 'sch1',
  String className = 'Class 10',
}) => StudentModel(
  studentId: id,
  name: 'Asha Rao',
  schoolId: schoolId,
  className: className,
  section: 'A',
  rollNumber: '21',
);

/// A student repository whose reads can be held open, so a test can
/// observe the loading state instead of racing past it.
class _GatedStudentRepository extends FakeStudentRepository {
  Completer<void>? gate;

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    final open = gate;
    if (open != null) await open.future;
    return super.getStudentById(studentId);
  }
}

/// Builds a controller over fakes, with every collaborator exposed so a
/// test can seed records or force a failure on exactly one of them.
class _Harness {
  final students = _GatedStudentRepository();
  final attendance = FakeAttendanceRepository();
  final fees = FakeFeeRepository();
  final exams = FakeExamRepository();

  late final StudentDashboardController controller = StudentDashboardController(
    studentRepository: students,
    attendanceRepository: attendance,
    feeRepository: fees,
    examRepository: exams,
    clock: () => kToday,
  );

  /// Seeds the student record the dashboard resolves itself to.
  void seedStudent({String schoolId = 'sch1', String className = 'Class 10'}) {
    students.students.add(
      studentRecord(schoolId: schoolId, className: className),
    );
  }
}

void main() {
  group('StudentDashboardController identity resolution', () {
    test('resolves the student record from the authenticated UID', () async {
      final h = _Harness()..seedStudent();
      // A second student exists whose records must never be reached.
      h.students.students.add(student('other-uid', schoolId: 'sch1'));

      await h.controller.load(profile: studentProfile());

      expect(h.controller.state.status, ViewStatus.ready);
      expect(h.controller.state.data!.student.studentId, kUid);
    });

    test('reads only the signed-in student, never another student', () async {
      final h = _Harness()..seedStudent();
      h.attendance.records.addAll([
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
        // Belongs to someone else. It must not reach this dashboard, and
        // must not move the percentage.
        attendance(
          'a2',
          schoolId: 'sch1',
          status: 'Absent',
          studentId: 'other-uid',
        ),
      ]);
      h.fees.fees.addAll([
        fee(
          'f1',
          schoolId: 'sch1',
          totalDue: 1000,
          paidAmount: 400,
          status: 'Partial',
          studentId: kUid,
        ),
        fee(
          'f2',
          schoolId: 'sch1',
          totalDue: 9999,
          paidAmount: 0,
          status: 'Outstanding',
          studentId: 'other-uid',
        ),
      ]);

      await h.controller.load(profile: studentProfile());
      final data = h.controller.state.data!;

      expect(data.attendanceRecordCount, 1);
      expect(data.attendancePercent, 100);
      expect(data.fee!.feeId, 'f1');
    });

    test(
      'a missing student record is an error, not an empty dashboard',
      () async {
        // Profile exists, but no `students` document is keyed on the UID.
        final h = _Harness();

        await h.controller.load(profile: studentProfile());

        expect(h.controller.state.status, ViewStatus.error);
        expect(h.controller.state.message, contains('could not be found'));
      },
    );

    test('a non-student role is refused the dashboard', () async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile(role: 'teacher'));

      expect(h.controller.state.status, ViewStatus.unauthorized);
      expect(
        h.controller.state.message,
        contains('only available to students'),
      );
    });

    test('a profile with no UID cannot be looked up', () async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile(uid: '   '));

      expect(h.controller.state.status, ViewStatus.error);
    });
  });

  group('StudentDashboardController attendance', () {
    test('uses the approved formula and counts non-Present records', () async {
      final h = _Harness()..seedStudent();
      h.attendance.records.addAll([
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
        attendance('a2', schoolId: 'sch1', status: 'Present', studentId: kUid),
        attendance('a3', schoolId: 'sch1', status: 'Absent', studentId: kUid),
        attendance('a4', schoolId: 'sch1', status: 'Leave', studentId: kUid),
      ]);

      await h.controller.load(profile: studentProfile());
      final data = h.controller.state.data!;

      // 2 Present out of 4 records. Leave lowers the figure without being
      // treated as an absence.
      expect(data.attendancePercent, 50);
      expect(data.attendanceRecordCount, 4);
      expect(data.attendanceBreakdown.present, 2);
      expect(data.attendanceBreakdown.absent, 1);
      expect(data.attendanceBreakdown.leave, 1);
    });

    test('no records reads as unavailable, not as zero per cent', () async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile());
      final data = h.controller.state.data!;

      expect(data.attendancePercent, isNull);
      expect(data.hasNoAttendance, isTrue);
      expect(Metrics.formatPercent(data.attendancePercent), '—');
    });
  });

  group('StudentDashboardController fees', () {
    test(
      'no fee record leaves the section empty rather than failing',
      () async {
        final h = _Harness()..seedStudent();

        await h.controller.load(profile: studentProfile());

        expect(h.controller.state.status, ViewStatus.ready);
        expect(h.controller.state.data!.fee, isNull);
      },
    );

    test('a denied fee read is surfaced, not shown as no fees', () async {
      final h = _Harness()..seedStudent();
      h.fees.failWith = RepositoryErrorKind.permissionDenied;

      await h.controller.load(profile: studentProfile());

      expect(h.controller.state.status, ViewStatus.unauthorized);
    });
  });

  group('StudentDashboardController upcoming exams', () {
    test('keeps only this class, from today onwards, soonest first', () async {
      final h = _Harness()..seedStudent();
      h.exams.exams.addAll([
        exam('e-past', schoolId: 'sch1', date: '2026-10-19'),
        exam('e-today', schoolId: 'sch1', date: '2026-10-20'),
        exam('e-later', schoolId: 'sch1', date: '2026-11-05'),
        exam('e-soon', schoolId: 'sch1', date: '2026-10-25'),
        // Right school, wrong class.
        exam(
          'e-other-class',
          schoolId: 'sch1',
          date: '2026-10-21',
          className: 'Class 9',
        ),
        // Right class, wrong school.
        exam('e-other-school', schoolId: 'sch2', date: '2026-10-22'),
      ]);

      await h.controller.load(profile: studentProfile());
      final exams = h.controller.state.data!.exams;

      expect(exams.status, ViewStatus.ready);
      expect(
        exams.data!.map((e) => e.examId),
        // An exam held today is still upcoming.
        ['e-today', 'e-soon', 'e-later'],
      );
    });

    test('an empty schedule is empty, and the rest still renders', () async {
      final h = _Harness()..seedStudent();
      h.attendance.records.add(
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
      );

      await h.controller.load(profile: studentProfile());

      expect(h.controller.state.status, ViewStatus.ready);
      expect(h.controller.state.data!.exams.status, ViewStatus.empty);
      expect(h.controller.state.data!.attendancePercent, 100);
    });

    test('a denied exam read does not blank attendance and fees', () async {
      // The real case from the gap report: a student with no schoolId on
      // their user profile is denied exams but still owns their own
      // attendance and fee records.
      final h = _Harness()..seedStudent();
      h.attendance.records.add(
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
      );
      h.fees.fees.add(
        fee(
          'f1',
          schoolId: 'sch1',
          totalDue: 1000,
          paidAmount: 1000,
          status: 'Paid',
          studentId: kUid,
        ),
      );
      h.exams.failWith = RepositoryErrorKind.permissionDenied;

      await h.controller.load(profile: studentProfile());
      final data = h.controller.state.data!;

      expect(h.controller.state.status, ViewStatus.ready);
      expect(data.exams.status, ViewStatus.unauthorized);
      // The sections governed by a different rule survived.
      expect(data.attendancePercent, 100);
      expect(data.fee!.feeId, 'f1');
    });

    test(
      'a student with no school gets an explanation, not a denial',
      () async {
        final h = _Harness()..seedStudent(schoolId: '');

        await h.controller.load(profile: studentProfile(schoolId: null));
        final exams = h.controller.state.data!.exams;

        expect(exams.status, ViewStatus.empty);
        expect(exams.message, contains('not linked to a school'));
      },
    );
  });

  group('StudentDashboardController failure handling', () {
    test('a repository failure becomes error, not unauthorized', () async {
      final h = _Harness()..seedStudent();
      h.attendance.failWith = RepositoryErrorKind.unavailable;

      await h.controller.load(profile: studentProfile());

      expect(h.controller.state.status, ViewStatus.error);
    });

    test('a denied student read is unauthorized', () async {
      final h = _Harness()..seedStudent();
      h.students.failWith = RepositoryErrorKind.permissionDenied;

      await h.controller.load(profile: studentProfile());

      expect(h.controller.state.status, ViewStatus.unauthorized);
    });

    test(
      'without a bootstrap service and without a profile it errors',
      () async {
        final h = _Harness()..seedStudent();

        await h.controller.load();

        expect(h.controller.state.status, ViewStatus.error);
      },
    );

    test('starts in the loading state before any load runs', () {
      final h = _Harness();
      expect(h.controller.state.status, ViewStatus.loading);
    });
  });

  // -------------------------------------------------------------- widget

  group('StudentDashboardScreen', () {
    Future<void> pumpDashboard(
      WidgetTester tester,
      StudentDashboardController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: StudentDashboardScreen(controller: controller)),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders attendance, fees and upcoming exams', (tester) async {
      final h = _Harness()..seedStudent();
      h.attendance.records.addAll([
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
        attendance('a2', schoolId: 'sch1', status: 'Present', studentId: kUid),
        attendance('a3', schoolId: 'sch1', status: 'Absent', studentId: kUid),
      ]);
      h.fees.fees.add(
        fee(
          'f1',
          schoolId: 'sch1',
          totalDue: 1000,
          paidAmount: 1000,
          status: 'Paid',
          studentId: kUid,
        ),
      );
      h.exams.exams.add(
        exam('e1', schoolId: 'sch1', date: '2026-10-25', subject: 'Physics'),
      );

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('Welcome back, Asha Rao'), findsOneWidget);
      // The roll number is shown when the record carries one.
      expect(find.textContaining('Roll 21'), findsOneWidget);
      // 2 Present out of 3 records.
      expect(find.text('67%'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('1000'), findsWidgets);
      expect(find.text('Physics'), findsOneWidget);
    });

    testWidgets('no attendance shows unavailable, never zero per cent', (
      tester,
    ) async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(
        find.text('No attendance has been recorded for you yet'),
        findsOneWidget,
      );
    });

    testWidgets('a student below the threshold is flagged', (tester) async {
      final h = _Harness()..seedStudent();
      h.attendance.records.addAll([
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
        attendance('a2', schoolId: 'sch1', status: 'Absent', studentId: kUid),
      ]);

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Below 70%'), findsOneWidget);
    });

    testWidgets('no fee record shows an empty fee section', (tester) async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(
        find.text('No fee record has been raised for you yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a part-paid fee shows the outstanding balance', (
      tester,
    ) async {
      final h = _Harness()..seedStudent();
      h.fees.fees.add(
        const FeeModel(
          feeId: 'f1',
          studentId: kUid,
          schoolId: 'sch1',
          totalDue: 1000,
          paidAmount: 400,
          status: 'Partial',
          updatedAt: '2026-10-01',
          remarks: 'Second instalment due in November',
        ),
      );

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('600'), findsOneWidget);
      expect(find.text('Second instalment due in November'), findsOneWidget);
    });

    testWidgets('an empty schedule shows its own empty state', (tester) async {
      final h = _Harness()..seedStudent();

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('No upcoming exams'), findsOneWidget);
    });

    testWidgets('a denied exam read is shown as a denial, not as no exams', (
      tester,
    ) async {
      final h = _Harness()..seedStudent();
      h.attendance.records.add(
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
      );
      h.exams.failWith = RepositoryErrorKind.permissionDenied;

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      // The exam section reports the denial ...
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('No upcoming exams'), findsNothing);
      // ... while the sections that did load are still on screen.
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows a spinner while reloading', (tester) async {
      final h = _Harness()..seedStudent();
      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Hold the next read open so the loading state can be observed.
      final gate = Completer<void>();
      h.students.gate = gate;
      unawaited(h.controller.load(profile: studentProfile()));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final h = _Harness()..seedStudent();
      h.attendance.failWith = RepositoryErrorKind.unavailable;

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a denied load is unauthorized and offers no retry', (
      tester,
    ) async {
      final h = _Harness()..seedStudent();
      h.students.failWith = RepositoryErrorKind.permissionDenied;

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      expect(find.text('Access denied'), findsOneWidget);
      // Retrying cannot grant permission, so no button is offered.
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(StateMessage), findsOneWidget);
    });

    testWidgets('offers the student no way to write anything', (tester) async {
      final h = _Harness()..seedStudent();
      h.attendance.records.add(
        attendance('a1', schoolId: 'sch1', status: 'Present', studentId: kUid),
      );
      h.fees.fees.add(
        fee(
          'f1',
          schoolId: 'sch1',
          totalDue: 1000,
          paidAmount: 0,
          status: 'Outstanding',
          studentId: kUid,
        ),
      );
      h.exams.exams.add(exam('e1', schoolId: 'sch1', date: '2026-10-25'));

      await h.controller.load(profile: studentProfile());
      await pumpDashboard(tester, h.controller);

      // Nothing to type into and nothing to submit. This is the approved
      // read-only presentation; the rules enforce it independently.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
      for (final label in const [
        'Save',
        'Edit',
        'Update',
        'Mark Attendance',
        'Pay Now',
        'Add Exam',
      ]) {
        expect(find.text(label), findsNothing, reason: '"$label" is a write');
      }
    });
  });
}

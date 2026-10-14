import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/district/controllers/district_data_loader.dart';
import 'package:my_flutter_edulens/features/district/controllers/school_details_controller.dart';
import 'package:my_flutter_edulens/features/district/controllers/school_list_controller.dart';
import 'package:my_flutter_edulens/features/district/screens/school_details_screen.dart';
import 'package:my_flutter_edulens/features/district/screens/school_list_screen.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _Fixture {
  final schools = FakeSchoolRepository();
  final students = FakeStudentRepository();
  final users = FakeUserRepository();
  final attendanceRepo = FakeAttendanceRepository();
  final feesRepo = FakeFeeRepository();
  final examsRepo = FakeExamRepository();

  DistrictDataLoader get loader => DistrictDataLoader(
    schoolRepository: schools,
    studentRepository: students,
    userRepository: users,
    attendanceRepository: attendanceRepo,
    feeRepository: feesRepo,
    examRepository: examsRepo,
  );

  SchoolDetailsController get detailsController => SchoolDetailsController(
    schoolRepository: schools,
    studentRepository: students,
    attendanceRepository: attendanceRepo,
    feeRepository: feesRepo,
    examRepository: examsRepo,
    clock: () => DateTime(2026, 10, 14),
  );

  void seed() {
    schools.schools.addAll([
      school('school01', name: 'Greenwood High', location: 'North'),
      school('school02', name: 'Riverside Public', location: 'East'),
      school('school03', name: 'Hilltop Academy', location: 'West'),
    ]);

    students.students.addAll([
      student('a', schoolId: 'school01'),
      student('b', schoolId: 'school01'),
      student('c', schoolId: 'school02'),
    ]);

    users.users.add(teacher('t1', schoolId: 'school01'));

    attendanceRepo.records.addAll([
      attendance('1', schoolId: 'school01', status: 'Present'),
      attendance('2', schoolId: 'school01', status: 'Absent'),
      attendance('3', schoolId: 'school01', status: 'Leave'),
    ]);

    feesRepo.fees.addAll([
      fee(
        'f1',
        schoolId: 'school01',
        totalDue: 1000,
        paidAmount: 1000,
        status: 'Paid',
      ),
      fee(
        'f2',
        schoolId: 'school01',
        totalDue: 1000,
        paidAmount: 500,
        status: 'Partial',
      ),
    ]);

    examsRepo.exams.addAll([
      exam('past', schoolId: 'school01', date: '2026-10-01'),
      exam(
        'soon',
        schoolId: 'school01',
        date: '2026-10-20',
        subject: 'Chemistry',
      ),
    ]);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

/// Targets a tab by label.
///
/// Scoped to the [TabBar] because some labels also appear in the page
/// body — "Attendance" is both a tab and a row on the Overview tab.
Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

void main() {
  group('SchoolListController', () {
    test('loads every school the user may read', () async {
      final f = _Fixture()..seed();
      final c = SchoolListController(loader: f.loader);
      await c.load();

      expect(c.state.status, ViewStatus.ready);
      expect(c.state.data!.length, 3);
    });

    test('search matches on name, ignoring case', () async {
      final f = _Fixture()..seed();
      final c = SchoolListController(loader: f.loader);
      await c.load();

      c.search('river');
      expect(c.state.data!.single.schoolName, 'Riverside Public');

      c.search('RIVER');
      expect(c.state.data!.single.schoolName, 'Riverside Public');
    });

    test(
      'clearing the search restores every school without reloading',
      () async {
        final f = _Fixture()..seed();
        final c = SchoolListController(loader: f.loader);
        await c.load();

        c.search('river');
        expect(c.state.data!.length, 1);

        // Emptying the box must not need another round trip.
        f.schools.failWith = RepositoryErrorKind.unavailable;
        c.search('');
        expect(c.state.data!.length, 3);
      },
    );

    test(
      'a search matching nothing is empty, and says so in its own words',
      () async {
        final f = _Fixture()..seed();
        final c = SchoolListController(loader: f.loader);
        await c.load();

        c.search('zzz');
        expect(c.state.status, ViewStatus.empty);
        // Worded as "no matches", not "no schools" — the data is still there.
        expect(c.state.message, contains('zzz'));
      },
    );

    test(
      'typing after a failure does not turn the error into an empty list',
      () async {
        final f = _Fixture()..seed();
        f.schools.failWith = RepositoryErrorKind.unavailable;
        final c = SchoolListController(loader: f.loader);
        await c.load();

        expect(c.state.status, ViewStatus.error);
        c.search('green');
        expect(c.state.status, ViewStatus.error);
      },
    );

    test('a permission denial becomes unauthorized', () async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;
      final c = SchoolListController(loader: f.loader);
      await c.load();

      expect(c.state.status, ViewStatus.unauthorized);
    });
  });

  group('SchoolListScreen', () {
    testWidgets('shows each school with its derived figures', (tester) async {
      final f = _Fixture()..seed();
      final c = SchoolListController(loader: f.loader);

      await tester.pumpWidget(_wrap(SchoolListScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Greenwood High'), findsOneWidget);
      expect(find.text('2 students'), findsOneWidget);
      expect(find.text('1 teachers'), findsOneWidget);
      // 1 Present of 3 records.
      expect(find.text('33% attendance'), findsOneWidget);
    });

    testWidgets('typing in the search box filters the list', (tester) async {
      final f = _Fixture()..seed();
      final c = SchoolListController(loader: f.loader);

      await tester.pumpWidget(_wrap(SchoolListScreen(controller: c)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hill');
      await tester.pumpAndSettle();

      expect(find.text('Hilltop Academy'), findsOneWidget);
      expect(find.text('Greenwood High'), findsNothing);
    });

    testWidgets('tapping a school reports its id, not its name or position', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      final c = SchoolListController(loader: f.loader);
      String? selected;

      await tester.pumpWidget(
        _wrap(
          SchoolListScreen(
            controller: c,
            onSchoolSelected: (id) => selected = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search first, so the tapped row is no longer at its original
      // index — a position-based lookup would pick the wrong school.
      await tester.enterText(find.byType(TextField), 'hill');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hilltop Academy'));
      await tester.pumpAndSettle();

      expect(selected, 'school03');
    });

    testWidgets('a permission denial shows access denied, not an empty list', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;
      final c = SchoolListController(loader: f.loader);

      await tester.pumpWidget(_wrap(SchoolListScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });
  });

  group('SchoolDetailsController', () {
    test('loads the school named by its id', () async {
      final f = _Fixture()..seed();
      final c = f.detailsController;
      await c.load('school02');

      expect(c.state.status, ViewStatus.ready);
      expect(c.state.data!.school.schoolName, 'Riverside Public');
    });

    test('breaks attendance down and counts Leave separately', () async {
      final f = _Fixture()..seed();
      final c = f.detailsController;
      await c.load('school01');

      final d = c.state.data!;
      expect(d.attendance.present, 1);
      expect(d.attendance.absent, 1);
      expect(d.attendance.leave, 1);
      expect(d.attendancePercent, closeTo(33.3, 0.1));
    });

    test(
      'fee percentage is amount-weighted, breakdown counts records',
      () async {
        final f = _Fixture()..seed();
        final c = f.detailsController;
        await c.load('school01');

        final d = c.state.data!;
        expect(d.feePaidPercent, 75.0); // 1500 paid of 2000 due
        expect(d.fees.paid, 1);
        expect(d.fees.partial, 1);
      },
    );

    test('only upcoming exams are listed', () async {
      final f = _Fixture()..seed();
      final c = f.detailsController;
      await c.load('school01');

      expect(c.state.data!.upcomingExams.map((e) => e.examId), ['soon']);
    });

    test('a missing school is not-found, not an empty school', () async {
      final f = _Fixture()..seed();
      final c = f.detailsController;
      await c.load('does-not-exist');

      // Reporting this as empty would imply the school exists but holds
      // no data, which is a different and misleading claim.
      expect(c.state.status, ViewStatus.error);
      expect(c.state.message, contains('could not be found'));
    });

    test('a permission denial becomes unauthorized', () async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;
      final c = f.detailsController;
      await c.load('school01');

      expect(c.state.status, ViewStatus.unauthorized);
    });
  });

  group('SchoolDetailsScreen', () {
    testWidgets('opens on Overview and can switch tabs', (tester) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SchoolDetailsScreen(
            schoolId: 'school01',
            controller: f.detailsController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_tab('Overview'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);

      await tester.tap(_tab('Fees'));
      await tester.pumpAndSettle();
      expect(find.text('Fees collected'), findsOneWidget);

      await tester.tap(_tab('Exams'));
      await tester.pumpAndSettle();
      expect(find.text('Chemistry'), findsOneWidget);
    });

    testWidgets('a school with no records shows per-tab empty wording', (
      tester,
    ) async {
      final f = _Fixture();
      f.schools.schools.add(school('school09', name: 'Empty School'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SchoolDetailsScreen(
            schoolId: 'school09',
            controller: f.detailsController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_tab('Attendance'));
      await tester.pumpAndSettle();
      expect(
        find.text('No attendance has been recorded for this school yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a missing school shows an error rather than a blank screen', (
      tester,
    ) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: SchoolDetailsScreen(
            schoolId: 'nope',
            controller: f.detailsController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}

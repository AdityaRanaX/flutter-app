import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/district/controllers/district_dashboard_controller.dart';
import 'package:my_flutter_edulens/features/district/controllers/district_data_loader.dart';
import 'package:my_flutter_edulens/features/district/screens/district_dashboard_screen.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

/// Three schools with deliberately different attendance, so the
/// below-70% attention rule has exactly one school to flag.
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

  /// school01 100% attendance, school02 50% — one above the threshold and
  /// one below, with different record counts so district weighting shows.
  void seed() {
    schools.schools.addAll([
      school('school01', name: 'Greenwood High'),
      school('school02', name: 'Riverside Public'),
    ]);

    students.students.addAll([
      student('a', schoolId: 'school01'),
      student('b', schoolId: 'school01'),
      student('c', schoolId: 'school02'),
    ]);

    users.users.addAll([
      teacher('t1', schoolId: 'school01'),
      teacher('t2', schoolId: 'school01'),
      teacher('t3', schoolId: 'school02'),
    ]);

    attendanceRepo.records.addAll([
      attendance('1', schoolId: 'school01', status: 'Present'),
      attendance('2', schoolId: 'school01', status: 'Present'),
      attendance('3', schoolId: 'school01', status: 'Present'),
      attendance('4', schoolId: 'school02', status: 'Present'),
      attendance('5', schoolId: 'school02', status: 'Absent'),
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
        schoolId: 'school02',
        totalDue: 1000,
        paidAmount: 0,
        status: 'Outstanding',
      ),
    ]);

    examsRepo.exams.addAll([
      exam('past', schoolId: 'school01', date: '2026-10-06'),
      exam(
        'soon',
        schoolId: 'school01',
        date: '2026-10-16',
        subject: 'Science',
      ),
      exam(
        'edge',
        schoolId: 'school02',
        date: '2026-10-21',
        subject: 'English',
      ),
      exam('later', schoolId: 'school01', date: '2026-11-03', subject: 'Hindi'),
    ]);
  }
}

DateTime _fixedNow() => DateTime(2026, 10, 14);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  group('DistrictDashboardController', () {
    test(
      'counts schools and derives district metrics from pooled records',
      () async {
        final f = _Fixture()..seed();
        final c = DistrictDashboardController(
          loader: f.loader,
          clock: _fixedNow,
        );
        await c.load();

        expect(c.totalSchools, 2);

        // 4 Present out of 5 records across both schools. Averaging the
        // per-school percentages would give 75%, which would overstate the
        // smaller school's weight.
        expect(c.averageAttendance, 80.0);

        // 1000 paid of 2000 due.
        expect(c.feesPaidPercent, 50.0);
      },
    );

    test('upcoming exams are limited to the next seven days', () async {
      final f = _Fixture()..seed();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      // 'past' is behind us and 'later' is beyond the window.
      expect(c.upcomingExams.map((e) => e.examId), ['soon', 'edge']);
    });

    test('attention areas flag only schools below 70%', () async {
      final f = _Fixture()..seed();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      expect(c.attentionAreas.length, 1);
      expect(c.attentionAreas.first.schoolId, 'school02');
    });

    test('a school with no attendance records is not flagged', () async {
      final f = _Fixture();
      f.schools.schools.add(school('school09', name: 'Brand New School'));
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      // No records is missing data, not a performance problem.
      expect(c.attentionAreas, isEmpty);
      expect(c.state.data?.schools.first.attendancePercent, isNull);
    });

    test('no schools is an empty state, not an error', () async {
      final f = _Fixture();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      expect(c.state.status, ViewStatus.empty);
    });

    test('a permission denial becomes unauthorized, never empty', () async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      expect(c.state.status, ViewStatus.unauthorized);
    });

    test('any other failure becomes an error state', () async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.unavailable;
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);
      await c.load();

      expect(c.state.status, ViewStatus.error);
    });
  });

  group('DistrictDashboardScreen', () {
    testWidgets('renders the metric cards from repository data', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);

      await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Total Schools'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('80%'), findsOneWidget); // average attendance
      expect(find.text('50%'), findsOneWidget); // fees paid
    });

    testWidgets('greets the administrator by name when one is known', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);

      await tester.pumpWidget(
        _wrap(
          DistrictDashboardScreen(controller: c, administratorName: 'Aditya'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Aditya'), findsOneWidget);
    });

    testWidgets(
      'falls back to a neutral greeting rather than inventing a name',
      (tester) async {
        final f = _Fixture()..seed();
        final c = DistrictDashboardController(
          loader: f.loader,
          clock: _fixedNow,
        );

        await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
        await tester.pumpAndSettle();

        expect(find.text('Welcome back'), findsOneWidget);
      },
    );

    testWidgets('lists the school that is below the attendance threshold', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);

      await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
      await tester.pumpAndSettle();

      // Attention Areas sits below the fold, and the list builds lazily.
      await tester.scrollUntilVisible(find.text('Riverside Public'), 300);

      expect(find.text('Riverside Public'), findsOneWidget);
      // The school above the threshold is never listed, scrolled to or not.
      expect(find.text('Greenwood High'), findsNothing);
    });

    testWidgets(
      'shows a dash, not a number, when there is nothing to measure',
      (tester) async {
        final f = _Fixture();
        f.schools.schools.add(school('school09'));
        final c = DistrictDashboardController(
          loader: f.loader,
          clock: _fixedNow,
        );

        await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
        await tester.pumpAndSettle();

        expect(find.text('—'), findsWidgets);
        expect(find.text('0%'), findsNothing);
      },
    );

    testWidgets('a permission denial shows access denied with no retry', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);

      await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Access denied'), findsOneWidget);
      // Retrying cannot grant permission, so no button is offered.
      expect(find.text('Retry'), findsNothing);
      // No protected numbers leak through.
      expect(find.text('Total Schools'), findsNothing);
    });

    testWidgets('a failure shows an error with a working retry', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      f.schools.failWith = RepositoryErrorKind.unavailable;
      final c = DistrictDashboardController(loader: f.loader, clock: _fixedNow);

      await tester.pumpWidget(_wrap(DistrictDashboardScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Clear the fault and retry: the dashboard should recover.
      f.schools.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Total Schools'), findsOneWidget);
    });
  });
}

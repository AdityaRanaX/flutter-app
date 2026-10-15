import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_admin_dashboard_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/screens/school_admin_dashboard_screen.dart';
import 'package:my_flutter_edulens/models/user_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _SchoolAdminFixture {
  final schools = FakeSchoolRepository();
  final students = FakeStudentRepository();
  final users = FakeUserRepository();
  final attendanceRepo = FakeAttendanceRepository();
  final feesRepo = FakeFeeRepository();
  final examsRepo = FakeExamRepository();

  void seed() {
    schools.schools.addAll([
      school(
        'school01',
        name: 'Oakridge International',
        location: 'North Zone',
      ),
      school('school02', name: 'St. Mary School', location: 'South Zone'),
    ]);

    students.students.addAll([
      student('st1', schoolId: 'school01', name: 'Alice'),
      student('st2', schoolId: 'school01', name: 'Bob'),
      student('st3', schoolId: 'school02', name: 'Charlie'),
    ]);

    users.users.addAll([
      teacher('t1', schoolId: 'school01'),
      teacher('t2', schoolId: 'school01'),
      teacher('t3', schoolId: 'school02'),
    ]);

    attendanceRepo.records.addAll([
      attendance('a1', schoolId: 'school01', status: 'Present'),
      attendance('a2', schoolId: 'school01', status: 'Present'),
      attendance('a3', schoolId: 'school01', status: 'Absent'),
      attendance('a4', schoolId: 'school02', status: 'Present'),
    ]);

    feesRepo.fees.addAll([
      fee(
        'f1',
        schoolId: 'school01',
        totalDue: 1000,
        paidAmount: 800,
        status: 'Partial',
      ),
      fee(
        'f2',
        schoolId: 'school02',
        totalDue: 2000,
        paidAmount: 2000,
        status: 'Paid',
      ),
    ]);

    examsRepo.exams.addAll([
      exam('e1', schoolId: 'school01', date: '2026-10-16', subject: 'Physics'),
      exam(
        'e2',
        schoolId: 'school02',
        date: '2026-10-17',
        subject: 'Chemistry',
      ),
    ]);
  }
}

DateTime _fixedNow() => DateTime(2026, 10, 14);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  group('SchoolAdminDashboardController', () {
    test('loads school-scoped metrics for assigned school', () async {
      final f = _SchoolAdminFixture()..seed();
      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      const adminProfile = UserModel(
        uid: 'admin01',
        name: 'Sarah Connor',
        email: 'sarah@oakridge.edu',
        role: 'schoolAdmin',
        schoolId: 'school01',
      );

      await c.load(schoolId: 'school01', profile: adminProfile);

      expect(c.state.status, ViewStatus.ready);
      final data = c.state.data!;

      expect(data.school.schoolName, 'Oakridge International');
      expect(data.totalStudents, 2); // st1 and st2 belong to school01
      expect(data.totalTeachers, 2); // t1 and t2 belong to school01
      expect(data.attendancePercent, closeTo(66.67, 0.01)); // 2/3 present
      expect(data.feePaidPercent, 80.0); // 800/1000
      expect(data.upcomingExams.length, 1);
      expect(data.upcomingExams.first.subject, 'Physics');
    });

    test('handles missing or unassigned school cleanly with error', () async {
      final f = _SchoolAdminFixture()..seed();
      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      await c.load(schoolId: '');
      expect(c.state.status, ViewStatus.error);
    });

    test('handles non-existent school ID cleanly with error', () async {
      final f = _SchoolAdminFixture()..seed();
      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      await c.load(schoolId: 'non_existent_school');
      expect(c.state.status, ViewStatus.error);
    });

    test(
      'maps permission-denied repository failure to unauthorized state',
      () async {
        final f = _SchoolAdminFixture()..seed();
        f.schools.failWith = RepositoryErrorKind.permissionDenied;

        final c = SchoolAdminDashboardController(
          schoolRepository: f.schools,
          studentRepository: f.students,
          userRepository: f.users,
          attendanceRepository: f.attendanceRepo,
          feeRepository: f.feesRepo,
          examRepository: f.examsRepo,
          clock: _fixedNow,
        );

        await c.load(schoolId: 'school01');
        expect(c.state.status, ViewStatus.unauthorized);
      },
    );
  });

  group('SchoolAdminDashboardScreen', () {
    testWidgets('renders school admin metrics cleanly', (tester) async {
      final f = _SchoolAdminFixture()..seed();
      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      const adminProfile = UserModel(
        uid: 'admin01',
        name: 'Sarah Connor',
        email: 'sarah@oakridge.edu',
        role: 'schoolAdmin',
        schoolId: 'school01',
      );

      // Trigger load before building screen
      await c.load(schoolId: 'school01', profile: adminProfile);

      await tester.pumpWidget(
        _wrap(SchoolAdminDashboardScreen(controller: c, schoolId: 'school01')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back, Sarah Connor'), findsOneWidget);
      expect(find.text('Overview for Oakridge International'), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('Total Teachers'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Physics (Class 10)'), 300);
      expect(find.text('Physics (Class 10)'), findsOneWidget);
    });

    testWidgets('displays low attendance warning when attendance < 70%', (
      tester,
    ) async {
      final f = _SchoolAdminFixture()..seed();
      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      await c.load(schoolId: 'school01');

      await tester.pumpWidget(
        _wrap(SchoolAdminDashboardScreen(controller: c, schoolId: 'school01')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance Warning'), findsOneWidget);
    });

    testWidgets('renders unauthorized state on permission failure', (
      tester,
    ) async {
      final f = _SchoolAdminFixture()..seed();
      f.schools.failWith = RepositoryErrorKind.permissionDenied;

      final c = SchoolAdminDashboardController(
        schoolRepository: f.schools,
        studentRepository: f.students,
        userRepository: f.users,
        attendanceRepository: f.attendanceRepo,
        feeRepository: f.feesRepo,
        examRepository: f.examsRepo,
        clock: _fixedNow,
      );

      await tester.pumpWidget(
        _wrap(SchoolAdminDashboardScreen(controller: c, schoolId: 'school01')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access denied'), findsOneWidget);
      expect(find.text('Total Students'), findsNothing);
    });
  });
}

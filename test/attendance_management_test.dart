import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/app_button.dart';
import 'package:my_flutter_edulens/features/teacher/controllers/attendance_management_controller.dart';
import 'package:my_flutter_edulens/features/teacher/screens/attendance_management_screen.dart';
import 'package:my_flutter_edulens/models/attendance_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _AttendanceFixture {
  final students = FakeStudentRepository();
  final attendanceRepo = FakeAttendanceRepository();

  void seed() {
    students.students.addAll([
      const StudentModel(
        studentId: 'st1',
        name: 'Alice Smith',
        schoolId: 's1',
        className: '10',
        section: 'A',
        rollNumber: 'RN-101',
      ),
      const StudentModel(
        studentId: 'st2',
        name: 'Bob Jones',
        schoolId: 's1',
        className: '10',
        section: 'B',
        // rollNumber is null
      ),
      const StudentModel(
        studentId: 'st3',
        name: 'Charlie Brown',
        schoolId: 's2', // Other school
        className: '10',
        section: 'A',
      ),
    ]);

    attendanceRepo.records.addAll([
      const AttendanceModel(
        attendanceId: 'a1',
        studentId: 'st1',
        schoolId: 's1',
        teacherId: 't1',
        date: '2026-10-14',
        status: 'Present',
      ),
      const AttendanceModel(
        attendanceId: 'a2',
        studentId: 'st2',
        schoolId: 's1',
        teacherId: 't1',
        date: '2026-10-14',
        status: 'Absent',
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
  group('AttendanceManagementController Unit Tests', () {
    test(
      'loads classroom attendance register for specific school and date',
      () async {
        final f = _AttendanceFixture()..seed();
        final controller = AttendanceManagementController(
          studentRepository: f.students,
          attendanceRepository: f.attendanceRepo,
          clock: _fixedNow,
        );

        await controller.loadAttendance(schoolId: 's1', date: '2026-10-14');

        expect(controller.state.status, ViewStatus.ready);
        final data = controller.state.data!;
        expect(data.totalStudents, 2);
        expect(data.presentCount, 1);
        expect(data.absentCount, 1);
        expect(data.items[0].student.name, 'Alice Smith');
        expect(data.items[0].currentStatus, 'Present');
        expect(data.items[1].student.name, 'Bob Jones');
        expect(data.items[1].currentStatus, 'Absent');
      },
    );

    test('toggles student status and marks all present/absent', () async {
      final f = _AttendanceFixture()..seed();
      final controller = AttendanceManagementController(
        studentRepository: f.students,
        attendanceRepository: f.attendanceRepo,
        clock: _fixedNow,
      );

      await controller.loadAttendance(schoolId: 's1', date: '2026-10-14');

      // Toggle st2 to Present
      controller.updateItemStatus('st2', 'Present');
      expect(controller.state.data!.items[1].currentStatus, 'Present');

      // Mark All Absent
      controller.markAll('Absent');
      expect(controller.state.data!.items[0].currentStatus, 'Absent');
      expect(controller.state.data!.items[1].currentStatus, 'Absent');
    });

    test('saves attendance register batch to repository', () async {
      final f = _AttendanceFixture()..seed();
      final controller = AttendanceManagementController(
        studentRepository: f.students,
        attendanceRepository: f.attendanceRepo,
        clock: _fixedNow,
      );

      await controller.loadAttendance(schoolId: 's1', date: '2026-10-14');
      controller.markAll('Present');

      final success = await controller.saveAttendanceRegister(
        schoolId: 's1',
        teacherId: 't1',
        date: '2026-10-14',
      );

      expect(success, isTrue);
      expect(f.attendanceRepo.records.length, 2);
      expect(f.attendanceRepo.records[0].status, 'Present');
      expect(f.attendanceRepo.records[1].status, 'Present');
    });

    test('maps repository failure to error state', () async {
      final f = _AttendanceFixture()..seed();
      f.students.failWith = RepositoryErrorKind.permissionDenied;

      final controller = AttendanceManagementController(
        studentRepository: f.students,
        attendanceRepository: f.attendanceRepo,
        clock: _fixedNow,
      );

      await controller.loadAttendance(schoolId: 's1', date: '2026-10-14');

      expect(controller.state.status, ViewStatus.unauthorized);
    });
  });

  group('AttendanceManagementScreen Widget Tests', () {
    testWidgets(
      'renders attendance register, handles missing roll numbers, and saves register',
      (tester) async {
        final f = _AttendanceFixture()..seed();
        final controller = AttendanceManagementController(
          studentRepository: f.students,
          attendanceRepository: f.attendanceRepo,
          clock: _fixedNow,
        );

        await controller.loadAttendance(schoolId: 's1', date: '2026-10-14');

        await tester.pumpWidget(
          _wrap(
            AttendanceManagementScreen(
              controller: controller,
              schoolId: 's1',
              teacherId: 't1',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice Smith'), findsOneWidget);
        expect(find.text('Class 10-A • Roll No: RN-101'), findsOneWidget);
        expect(find.text('Bob Jones'), findsOneWidget);
        expect(find.text('Class 10-B • No Roll No.'), findsOneWidget);

        await tester.tap(find.text('Mark All Present'));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(const Key('save_attendance_button'));
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('Attendance register saved successfully.'),
          findsOneWidget,
        );
      },
    );
  });
}

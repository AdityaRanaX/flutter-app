import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/district/controllers/exam_overview_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_exam_schedule_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/screens/school_exam_schedule_screen.dart';
import 'package:my_flutter_edulens/models/exam_model.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _ExamScheduleFixture {
  final schools = FakeSchoolRepository();
  final exams = FakeExamRepository();

  void seed() {
    schools.schools.addAll([
      const SchoolModel(
        schoolId: 's1',
        schoolName: 'Greenwood High',
        location: 'North Zone',
      ),
      const SchoolModel(
        schoolId: 's2',
        schoolName: 'Riverside Academy',
        location: 'South Zone',
      ),
    ]);

    exams.exams.addAll([
      const ExamModel(
        examId: 'e1',
        schoolId: 's1',
        className: '10',
        subject: 'Physics',
        date: '2026-10-16',
        startTime: '09:00 AM',
        endTime: '12:00 PM',
        createdBy: 't1',
      ),
      const ExamModel(
        examId: 'e2',
        schoolId: 's1',
        className: '9',
        subject: 'History',
        date: '2026-10-05', // Past exam relative to fixed test date 2026-10-14
        startTime: '10:00 AM',
        endTime: '01:00 PM',
        createdBy: 't1',
      ),
      const ExamModel(
        examId: 'e3',
        schoolId: 's2', // Other school
        className: '10',
        subject: 'Chemistry',
        date: '2026-10-18',
        startTime: '10:00 AM',
        endTime: '01:00 PM',
        createdBy: 't2',
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
  group('SchoolExamScheduleController Unit Tests', () {
    test(
      'loads school-scoped exams and filters upcoming exams by default',
      () async {
        final f = _ExamScheduleFixture()..seed();
        final controller = SchoolExamScheduleController(
          examRepository: f.exams,
          schoolRepository: f.schools,
          clock: _fixedNow,
        );

        await controller.load(schoolId: 's1');

        expect(controller.state.status, ViewStatus.ready);
        final visible = controller.state.data!;
        expect(visible.length, 1);
        expect(visible.first.subject, 'Physics');

        // Switch filter to All
        controller.setFilter(ExamFilter.all);
        expect(controller.state.data!.length, 2);
      },
    );

    test('adds and persists new exam record for school', () async {
      final f = _ExamScheduleFixture()..seed();
      final controller = SchoolExamScheduleController(
        examRepository: f.exams,
        schoolRepository: f.schools,
        clock: _fixedNow,
      );

      await controller.load(schoolId: 's1');

      final success = await controller.addExam(
        schoolId: 's1',
        subject: 'Biology',
        className: '10',
        date: '2026-10-20',
        startTime: '02:00 PM',
        endTime: '05:00 PM',
        createdBy: 't1',
      );

      expect(success, isTrue);
      expect(f.exams.exams.length, 4);

      final added = f.exams.exams.firstWhere((e) => e.subject == 'Biology');
      expect(added.schoolId, 's1');
      expect(added.className, '10');
      expect(added.date, '2026-10-20');
    });

    test('maps repository failure to error state', () async {
      final f = _ExamScheduleFixture()..seed();
      f.exams.failWith = RepositoryErrorKind.permissionDenied;

      final controller = SchoolExamScheduleController(
        examRepository: f.exams,
        schoolRepository: f.schools,
        clock: _fixedNow,
      );

      await controller.load(schoolId: 's1');

      expect(controller.state.status, ViewStatus.unauthorized);
    });
  });

  group('SchoolExamScheduleScreen Widget Tests', () {
    testWidgets('renders upcoming exams list and filters correctly', (
      tester,
    ) async {
      final f = _ExamScheduleFixture()..seed();
      final controller = SchoolExamScheduleController(
        examRepository: f.exams,
        schoolRepository: f.schools,
        clock: _fixedNow,
      );

      await controller.load(schoolId: 's1');

      await tester.pumpWidget(
        _wrap(SchoolExamScheduleScreen(controller: controller, schoolId: 's1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Physics'), findsOneWidget);
      expect(
        find.text('History'),
        findsNothing,
      ); // Past exam filtered out in Upcoming

      // Switch to All Exams
      await tester.tap(find.text('All Exams'));
      await tester.pumpAndSettle();

      expect(find.text('Physics'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('schedules a new exam via dialog form', (tester) async {
      final f = _ExamScheduleFixture()..seed();
      final controller = SchoolExamScheduleController(
        examRepository: f.exams,
        schoolRepository: f.schools,
        clock: _fixedNow,
      );

      await controller.load(schoolId: 's1');

      await tester.pumpWidget(
        _wrap(
          SchoolExamScheduleScreen(
            controller: controller,
            schoolId: 's1',
            currentUserId: 't1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Schedule Exam').first);
      await tester.pumpAndSettle();

      expect(find.text('Schedule New Exam'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Computer Science');
      await tester.enterText(find.byType(TextField).at(1), 'Class 10');
      await tester.enterText(find.byType(TextField).at(2), '2026-10-22');

      final dialogSubmitButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Schedule Exam'),
      );

      await tester.tap(dialogSubmitButton);
      await tester.pumpAndSettle();

      expect(find.text('New exam scheduled successfully.'), findsOneWidget);
      expect(find.text('Computer Science'), findsOneWidget);
    });
  });
}

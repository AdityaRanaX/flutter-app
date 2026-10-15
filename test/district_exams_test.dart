import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/district/controllers/exam_details_controller.dart';
import 'package:my_flutter_edulens/features/district/controllers/exam_overview_controller.dart';
import 'package:my_flutter_edulens/features/district/screens/district_exam_overview_screen.dart';
import 'package:my_flutter_edulens/features/district/screens/exam_details_screen.dart';
import 'package:my_flutter_edulens/features/district/widgets/exam_list_tile.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _Fixture {
  final schools = FakeSchoolRepository();
  final students = FakeStudentRepository();
  final examsRepo = FakeExamRepository();

  ExamOverviewController overview() => ExamOverviewController(
    examRepository: examsRepo,
    schoolRepository: schools,
    clock: () => DateTime(2026, 10, 14),
  );

  ExamDetailsController details() => ExamDetailsController(
    examRepository: examsRepo,
    schoolRepository: schools,
    studentRepository: students,
  );

  void seed() {
    schools.schools.addAll([
      school('school01', name: 'Greenwood High'),
      school('school02', name: 'Riverside Public'),
    ]);

    students.students.addAll([
      student('a', schoolId: 'school01', className: 'Class 10', name: 'Ananya'),
      student('b', schoolId: 'school01', className: 'Class 10', name: 'Rohan'),
      // Same school, different class — must not be counted for a Class 10 exam.
      student('c', schoolId: 'school01', className: 'Class 9', name: 'Ishita'),
      // Same class, different school — likewise.
      student('d', schoolId: 'school02', className: 'Class 10', name: 'Vikram'),
    ]);

    examsRepo.exams.addAll([
      exam(
        'past',
        schoolId: 'school01',
        date: '2026-10-06',
        subject: 'Mathematics',
      ),
      exam(
        'today',
        schoolId: 'school01',
        date: '2026-10-14',
        subject: 'Science',
      ),
      exam(
        'soon',
        schoolId: 'school02',
        date: '2026-10-19',
        subject: 'English',
      ),
      // Same subject as 'past', at a different school — this is why the
      // details screen is reached by id rather than by subject.
      exam(
        'twin',
        schoolId: 'school02',
        date: '2026-11-03',
        subject: 'Mathematics',
      ),
    ]);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(TabBar), matching: find.text(label));

void main() {
  group('ExamOverviewController', () {
    test('Upcoming excludes the past and includes today', () async {
      final f = _Fixture()..seed();
      final c = f.overview();
      await c.load();

      expect(c.state.data!.map((e) => e.examId), ['today', 'soon', 'twin']);
    });

    test('All Exams includes past records, soonest first', () async {
      final f = _Fixture()..seed();
      final c = f.overview();
      await c.load();

      c.setFilter(ExamFilter.all);
      expect(c.state.data!.map((e) => e.examId), [
        'past',
        'today',
        'soon',
        'twin',
      ]);
    });

    test('switching the filter does not re-read the repository', () async {
      final f = _Fixture()..seed();
      final c = f.overview();
      await c.load();

      // The toggle changes the view, not the data. If it re-queried, this
      // induced failure would surface.
      f.examsRepo.failWith = RepositoryErrorKind.unavailable;
      c.setFilter(ExamFilter.all);
      expect(c.state.status, ViewStatus.ready);
    });

    test('school names are resolved from schoolId', () async {
      final f = _Fixture()..seed();
      final c = f.overview();
      await c.load();

      final soon = c.state.data!.firstWhere((e) => e.examId == 'soon');
      expect(c.schoolNameFor(soon), 'Riverside Public');
    });

    test(
      'an exam whose school is missing resolves to null, not a fake name',
      () async {
        final f = _Fixture()..seed();
        f.examsRepo.exams.add(
          exam('orphan', schoolId: 'school99', date: '2026-10-20'),
        );
        final c = f.overview();
        await c.load();

        final orphan = c.state.data!.firstWhere((e) => e.examId == 'orphan');
        // Null, so the row drops the school rather than printing an id.
        expect(c.schoolNameFor(orphan), isNull);
      },
    );

    test(
      'an empty Upcoming list is worded differently from no exams at all',
      () async {
        final f = _Fixture();
        f.schools.schools.add(school('school01'));
        f.examsRepo.exams.add(
          exam('old', schoolId: 'school01', date: '2026-01-01'),
        );
        final c = f.overview();
        await c.load();

        expect(c.state.status, ViewStatus.empty);
        expect(c.state.message, contains('from today onwards'));

        c.setFilter(ExamFilter.all);
        expect(c.state.status, ViewStatus.ready);
      },
    );

    test(
      'a permission denial becomes unauthorized, never an empty list',
      () async {
        final f = _Fixture()..seed();
        f.examsRepo.failWith = RepositoryErrorKind.permissionDenied;
        final c = f.overview();
        await c.load();

        expect(c.state.status, ViewStatus.unauthorized);
      },
    );

    test('toggling after a failure leaves the error in place', () async {
      final f = _Fixture()..seed();
      f.examsRepo.failWith = RepositoryErrorKind.unavailable;
      final c = f.overview();
      await c.load();

      expect(c.state.status, ViewStatus.error);
      c.setFilter(ExamFilter.all);
      expect(c.state.status, ViewStatus.error);
    });
  });

  group('DistrictExamOverviewScreen', () {
    testWidgets('lists upcoming exams with subject, date and school', (
      tester,
    ) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        _wrap(DistrictExamOverviewScreen(controller: f.overview())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Science'), findsOneWidget);
      expect(find.text('14 Oct 2026 · 10:00 · Greenwood High'), findsOneWidget);

      // Three of the four exams are upcoming. The past one is identified
      // by its date, not its subject — 'Mathematics' is also the subject
      // of a future exam at another school, which is the whole reason
      // exams are addressed by id.
      expect(find.byType(ExamListTile), findsNWidgets(3));
      expect(find.textContaining('6 Oct 2026'), findsNothing);
    });

    testWidgets('switching to All Exams reveals past exams', (tester) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        _wrap(DistrictExamOverviewScreen(controller: f.overview())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All Exams'));
      await tester.pumpAndSettle();

      expect(find.text('Mathematics'), findsWidgets);
    });

    testWidgets('tapping an exam reports its id', (tester) async {
      final f = _Fixture()..seed();
      String? selected;

      await tester.pumpWidget(
        _wrap(
          DistrictExamOverviewScreen(
            controller: f.overview(),
            onExamSelected: (id) => selected = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(selected, 'soon');
    });

    testWidgets('a permission denial shows access denied, not an empty list', (
      tester,
    ) async {
      final f = _Fixture()..seed();
      f.examsRepo.failWith = RepositoryErrorKind.permissionDenied;

      await tester.pumpWidget(
        _wrap(DistrictExamOverviewScreen(controller: f.overview())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Access denied'), findsOneWidget);
      expect(find.byType(ExamListTile), findsNothing);
    });
  });

  group('ExamDetailsController', () {
    test('loads the exam named by its id, not by its subject', () async {
      final f = _Fixture()..seed();
      final c = f.details();

      // Two exams share the subject 'Mathematics'. The id decides.
      await c.load('twin');
      expect(c.state.data!.exam.schoolId, 'school02');
      expect(c.state.data!.schoolName, 'Riverside Public');
    });

    test('students are narrowed by school AND class', () async {
      final f = _Fixture()..seed();
      final c = f.details();
      await c.load('today'); // school01, Class 10

      expect(c.state.data!.totalStudents, 2);
      expect(
        c.state.data!.students.map((s) => s.name),
        containsAll(['Ananya', 'Rohan']),
      );
    });

    test('search filters students without discarding the full list', () async {
      final f = _Fixture()..seed();
      final c = f.details();
      await c.load('today');

      c.search('anan');
      expect(c.visibleStudents.map((s) => s.name), ['Ananya']);

      c.search('');
      expect(c.visibleStudents.length, 2);
    });

    test('a missing exam is not-found, not an empty exam', () async {
      final f = _Fixture()..seed();
      final c = f.details();
      await c.load('does-not-exist');

      expect(c.state.status, ViewStatus.error);
      expect(c.state.message, contains('could not be found'));
    });

    test('a missing school leaves the exam usable', () async {
      final f = _Fixture()..seed();
      f.examsRepo.exams.add(
        exam('orphan', schoolId: 'school99', date: '2026-10-20'),
      );
      final c = f.details();
      await c.load('orphan');

      // The exam still loads; only the school name is absent.
      expect(c.state.status, ViewStatus.ready);
      expect(c.state.data!.schoolName, isNull);
    });

    test('a failed load does not leave the previous exam on screen', () async {
      final f = _Fixture()..seed();
      final c = f.details();
      await c.load('today');
      expect(c.state.data!.exam.subject, 'Science');

      f.examsRepo.failWith = RepositoryErrorKind.unavailable;
      await c.load('soon');

      expect(c.state.status, ViewStatus.error);
      expect(c.state.data, isNull);
    });

    test('a permission denial becomes unauthorized', () async {
      final f = _Fixture()..seed();
      f.examsRepo.failWith = RepositoryErrorKind.permissionDenied;
      final c = f.details();
      await c.load('today');

      expect(c.state.status, ViewStatus.unauthorized);
    });
  });

  group('ExamDetailsScreen', () {
    testWidgets('shows the exam, its class and its students', (tester) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExamDetailsScreen(examId: 'today', controller: f.details()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Greenwood High · Class 10'), findsOneWidget);
      expect(find.text('Ananya'), findsOneWidget);
      expect(find.text('Rohan'), findsOneWidget);
      // Wrong class and wrong school are excluded.
      expect(find.text('Ishita'), findsNothing);
      expect(find.text('Vikram'), findsNothing);
    });

    testWidgets('never shows a Present or Absent status', (tester) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExamDetailsScreen(examId: 'today', controller: f.details()),
        ),
      );
      await tester.pumpAndSettle();

      // Exam attendance does not exist in the model, so pairing a name
      // with a status would be fabricating data.
      expect(find.text('Present'), findsNothing);
      expect(find.text('Absent'), findsNothing);
      expect(find.textContaining('not recorded yet'), findsOneWidget);
    });

    testWidgets('the Details tab lists the approved fields only', (
      tester,
    ) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExamDetailsScreen(examId: 'today', controller: f.details()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_tab('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Total students'), findsOneWidget);
      expect(find.text('14 Oct 2026'), findsOneWidget);
      // No status row — the model has no status field.
      expect(find.text('Status'), findsNothing);
      expect(find.textContaining('Exam status is not shown'), findsOneWidget);
    });

    testWidgets('searching students filters the list', (tester) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExamDetailsScreen(examId: 'today', controller: f.details()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'rohan');
      await tester.pumpAndSettle();

      expect(find.text('Rohan'), findsOneWidget);
      expect(find.text('Ananya'), findsNothing);
    });

    testWidgets('a missing exam shows an error rather than a blank screen', (
      tester,
    ) async {
      final f = _Fixture()..seed();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ExamDetailsScreen(examId: 'nope', controller: f.details()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}

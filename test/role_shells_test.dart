import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/placeholder_destination.dart';
import 'package:my_flutter_edulens/features/district/screens/district_shell.dart';
import 'package:my_flutter_edulens/features/school_admin/screens/school_admin_shell.dart';
import 'package:my_flutter_edulens/features/student/screens/student_shell.dart';
import 'package:my_flutter_edulens/features/teacher/screens/teacher_shell.dart';

/// Wraps a role shell in a themed app so it can be pumped in a test.
Widget wrapShell(Widget shell) {
  return MaterialApp(theme: AppTheme.lightTheme, home: shell);
}

void main() {
  group('PlaceholderDestination', () {
    testWidgets('shows its title, icon and default note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PlaceholderDestination(
              title: 'Schools',
              icon: Icons.apartment_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Schools'), findsOneWidget);
      expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
      expect(find.text('This screen has not been built yet.'), findsOneWidget);
    });

    testWidgets('a custom note replaces the default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PlaceholderDestination(
              title: 'Exams',
              icon: Icons.assignment_outlined,
              note: 'Coming in a later PR.',
            ),
          ),
        ),
      );

      expect(find.text('Coming in a later PR.'), findsOneWidget);
      expect(find.text('This screen has not been built yet.'), findsNothing);
    });
  });

  group('Role tab sets', () {
    // Each role gets the tab set the approved UX defines for it.
    testWidgets('District shows Home / Schools / Exams / Profile', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(const DistrictShell()));

      expect(find.text('Schools'), findsWidgets);
      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Attendance'), findsNothing);
    });

    testWidgets('School Admin shows Students / School / Profile', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(const SchoolAdminShell()));

      expect(find.text('Students'), findsWidgets);
      expect(find.text('School'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Exams'), findsNothing);
    });

    testWidgets('Teacher shows Home / Attendance / Exams / Profile', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(const TeacherShell()));

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Schools'), findsNothing);
    });

    testWidgets('Student shows Home / Exams / Profile', (tester) async {
      await tester.pumpWidget(wrapShell(const StudentShell()));

      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Schools'), findsNothing);
    });
  });

  group('Switching tabs', () {
    testWidgets('tapping a tab swaps the placeholder behind it', (
      tester,
    ) async {
      await tester.pumpWidget(wrapShell(const DistrictShell()));

      // Starts on Home.
      expect(find.text('District Home'), findsOneWidget);

      await tester.tap(find.text('Schools'));
      await tester.pump();

      // Home placeholder gone, Schools placeholder shown.
      expect(find.text('District Home'), findsNothing);
      expect(find.byIcon(Icons.apartment_outlined), findsWidgets);
    });

    testWidgets('every Student tab can be opened', (tester) async {
      await tester.pumpWidget(wrapShell(const StudentShell()));

      expect(find.text('Student Home'), findsOneWidget);

      await tester.tap(find.text('Exams'));
      await tester.pump();
      expect(find.text('Student Home'), findsNothing);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.byIcon(Icons.person_outline), findsWidgets);
    });
  });
}

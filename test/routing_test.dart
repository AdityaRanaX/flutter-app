import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/app.dart';
import 'package:my_flutter_edulens/routes/app_routes.dart';

void main() {
  group('EduLens Routing Tests', () {
    testWidgets('Initial route renders LoginScreen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      expect(find.text('EduLens'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('Navigates to Forgot Password route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.forgotPassword);
      await tester.pumpAndSettle();

      expect(find.text('Reset Your Password'), findsOneWidget);
    });

    testWidgets('Navigates to District Dashboard route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.districtDashboard);
      await tester.pumpAndSettle();

      // Home is the real dashboard now, so this asserts the District
      // tab set rather than a placeholder's title.
      expect(find.text('Schools'), findsWidgets);
      expect(find.text('Exams'), findsOneWidget);
    });

    testWidgets('Navigates to School Admin Dashboard route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.schoolAdminDashboard);
      await tester.pumpAndSettle();

      expect(find.text('Students'), findsWidgets);
    });

    testWidgets('Navigates to Teacher Dashboard route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.teacherDashboard);
      await tester.pumpAndSettle();

      expect(find.text('Teacher Home'), findsOneWidget);
    });

    testWidgets('Navigates to Student Dashboard route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.studentDashboard);
      await tester.pumpAndSettle();

      expect(find.text('Student Home'), findsOneWidget);
    });

    testWidgets('Navigates to Profile route', (WidgetTester tester) async {
      await tester.pumpWidget(const EduLensApp());
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(Scaffold));
      Navigator.pushNamed(context, AppRoutes.profile);
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsNWidgets(2));
    });
  });
}

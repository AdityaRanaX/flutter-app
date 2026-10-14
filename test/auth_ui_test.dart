import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/auth/screens/forgot_password_screen.dart';
import 'package:my_flutter_edulens/features/auth/screens/login_screen.dart';
import 'package:my_flutter_edulens/features/auth/screens/reset_password_screen.dart';

void main() {
  group('Authentication UI Tests', () {
    testWidgets('LoginScreen renders branding, email, password, and buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
      );

      expect(find.text('EduLens'), findsOneWidget);
      expect(find.text('District School Management System'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Remember Me'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets(
      'ForgotPasswordScreen renders title, email field and send button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ForgotPasswordScreen(),
          ),
        );

        expect(find.text('Reset Your Password'), findsOneWidget);
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Send Reset Link'), findsOneWidget);
        expect(find.text('Back to Login'), findsOneWidget);
      },
    );

    testWidgets('ResetPasswordScreen renders new and confirm password fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ResetPasswordScreen(),
        ),
      );

      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Reset Password'), findsNWidgets(2));
    });
  });
}

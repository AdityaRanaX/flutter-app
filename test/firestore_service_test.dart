import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/district/screens/district_shell.dart';

void main() {
  group('Firestore Integration & Test Button Tests', () {
    testWidgets('DistrictShell displays Test Firestore action icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DistrictShell(),
        ),
      );

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    });
  });
}

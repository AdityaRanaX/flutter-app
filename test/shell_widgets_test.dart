import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/app_screen_bar.dart';
import 'package:my_flutter_edulens/core/widgets/app_shell.dart';
import 'package:my_flutter_edulens/core/widgets/placeholder_destination.dart';
import 'package:my_flutter_edulens/core/widgets/state_message.dart';

void main() {
  group('Shared Visual Shell Widgets Tests', () {
    testWidgets('AppShell renders body and bottom navigation bar', (
      WidgetTester tester,
    ) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            items: const [
              AppNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
              ),
              AppNavItem(
                label: 'Profile',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
              ),
            ],
            currentIndex: selectedIndex,
            onItemSelected: (index) {
              selectedIndex = index;
            },
            body: const Text('Shell Body Content'),
          ),
        ),
      );

      expect(find.text('Shell Body Content'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      expect(selectedIndex, 1);
    });

    testWidgets('AppScreenBar renders title and back button', (
      WidgetTester tester,
    ) async {
      bool backTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppScreenBar.back(
              title: 'Student Details',
              onBack: () {
                backTapped = true;
              },
            ),
            body: const SizedBox(),
          ),
        ),
      );

      expect(find.text('Student Details'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(backTapped, isTrue);
    });

    testWidgets('PlaceholderDestination renders title and icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlaceholderDestination(
              title: 'Attendance',
              icon: Icons.fact_check_outlined,
            ),
          ),
        ),
      );

      expect(find.text('Attendance'), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    });

    testWidgets('StateMessage renders loading, empty, and error states', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StateMessage(type: StateMessageType.loading),
                StateMessage(
                  type: StateMessageType.empty,
                  title: 'No Data Available',
                ),
                StateMessage(
                  type: StateMessageType.error,
                  title: 'Error Loading',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('No Data Available'), findsOneWidget);
      expect(find.text('Error Loading'), findsOneWidget);
    });
  });
}

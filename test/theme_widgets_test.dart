import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/theme/app_colors.dart';
import 'package:my_flutter_edulens/core/theme/app_spacing.dart';
import 'package:my_flutter_edulens/core/theme/app_text_styles.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/app_buttons.dart';
import 'package:my_flutter_edulens/core/widgets/app_card.dart';
import 'package:my_flutter_edulens/core/widgets/app_list_tile.dart';
import 'package:my_flutter_edulens/core/widgets/app_screen_bar.dart';
import 'package:my_flutter_edulens/core/widgets/app_shell.dart';
import 'package:my_flutter_edulens/core/widgets/app_text_field.dart';
import 'package:my_flutter_edulens/core/widgets/stat_card.dart';
import 'package:my_flutter_edulens/core/widgets/state_message.dart';
import 'package:my_flutter_edulens/core/widgets/status_chip.dart';

/// Wraps a widget in a themed app so it can be pumped in a test.
Widget wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Theme tokens', () {
    test('light theme uses the EduLens tokens', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.error, AppColors.danger);
      // ThemeData merges the platform font into every style, so compare
      // the properties we set rather than the whole TextStyle.
      expect(
        theme.textTheme.titleMedium?.fontSize,
        AppTextStyles.cardTitle.fontSize,
      );
      expect(
        theme.textTheme.titleMedium?.fontWeight,
        AppTextStyles.cardTitle.fontWeight,
      );
      expect(
        theme.textTheme.headlineLarge?.fontSize,
        AppTextStyles.screenTitle.fontSize,
      );
    });

    test('light is the same theme as lightTheme', () {
      expect(
        AppTheme.light.colorScheme.primary,
        AppTheme.lightTheme.colorScheme.primary,
      );
    });

    test('every sub-theme the design needs is configured', () {
      final theme = AppTheme.lightTheme;

      expect(theme.appBarTheme.backgroundColor, AppColors.surface);
      expect(theme.cardTheme.color, AppColors.surface);
      expect(
        theme.bottomNavigationBarTheme.selectedItemColor,
        AppColors.primary,
      );
      expect(theme.inputDecorationTheme.fillColor, AppColors.surface);
      expect(theme.dialogTheme.backgroundColor, AppColors.surface);
      expect(theme.switchTheme.trackColor, isNotNull);
      expect(theme.checkboxTheme.fillColor, isNotNull);
      expect(theme.radioTheme.fillColor, isNotNull);
    });

    test('spacing and radius values match the design tokens', () {
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.ms, 12.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppRadius.md, 12.0);
      expect(AppRadius.button, 10.0);
      expect(AppRadius.input, 10.0);
    });
  });

  group('Buttons', () {
    testWidgets('all three render their label and fire onPressed', (
      tester,
    ) async {
      var primaryTaps = 0;
      var secondaryTaps = 0;
      var dangerTaps = 0;

      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              PrimaryButton(label: 'Save', onPressed: () => primaryTaps++),
              SecondaryButton(
                label: 'Cancel',
                onPressed: () => secondaryTaps++,
              ),
              DangerButton(label: 'Delete', onPressed: () => dangerTaps++),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Delete'));
      await tester.pump();

      expect(primaryTaps, 1);
      expect(secondaryTaps, 1);
      expect(dangerTaps, 1);
    });

    testWidgets('a loading button shows a spinner and ignores taps', (
      tester,
    ) async {
      var taps = 0;

      await tester.pumpWidget(
        wrap(
          PrimaryButton(
            label: 'Save',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('AppTextField', () {
    testWidgets('shows its label, hint and error', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppTextField(
            label: 'Email',
            hint: 'you@school.edu',
            errorText: 'Email is required',
            prefixIcon: Icons.mail_outline,
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@school.edu'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    });

    testWidgets('the password eye toggles visibility', (tester) async {
      await tester.pumpWidget(
        wrap(const AppTextField(label: 'Password', isPassword: true)),
      );

      // Starts hidden.
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      // Now visible.
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('StatusChip', () {
    testWidgets('each status renders its default label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const Wrap(
            children: [
              StatusChip(type: StatusChipType.paid),
              StatusChip(type: StatusChipType.partial),
              StatusChip(type: StatusChipType.outstanding),
              StatusChip(type: StatusChipType.present),
              StatusChip(type: StatusChipType.absent),
            ],
          ),
        ),
      );

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
    });

    testWidgets('a custom label wins over the default', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusChip(type: StatusChipType.absent, label: 'Absent (2)'),
        ),
      );

      expect(find.text('Absent (2)'), findsOneWidget);
      expect(find.text('Absent'), findsNothing);
    });
  });

  group('Cards and rows', () {
    testWidgets('AppCard shows its child and can be tapped', (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        wrap(AppCard(onTap: () => taps++, child: const Text('Inside'))),
      );

      await tester.tap(find.text('Inside'));
      await tester.pump();

      expect(find.text('Inside'), findsOneWidget);
      expect(taps, 1);
    });

    testWidgets('AppListTile shows icon, title, subtitle and chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const AppListTile(
            icon: Icons.school_outlined,
            title: 'Greenwood High',
            subtitle: '412 students',
          ),
        ),
      );

      expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      expect(find.text('Greenwood High'), findsOneWidget);
      expect(find.text('412 students'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('AppListTile hides the chevron when trailing is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const AppListTile(
            icon: Icons.person_outline,
            title: 'Riya Sharma',
            trailing: StatusChip(type: StatusChipType.present),
          ),
        ),
      );

      expect(find.text('Present'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('StatCard shows its label and number', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatCard(
            icon: Icons.groups_outlined,
            label: 'Total Students',
            value: '1,284',
          ),
        ),
      );

      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('1,284'), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    });
  });

  group('StateMessage', () {
    testWidgets('loading shows a spinner and no retry', (tester) async {
      await tester.pumpWidget(
        wrap(StateMessage(type: StateMessageType.loading, onRetry: () {})),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('error shows a working Retry button', (tester) async {
      var retries = 0;

      await tester.pumpWidget(
        wrap(
          StateMessage(type: StateMessageType.error, onRetry: () => retries++),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('empty and unauthorized show their own defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const StateMessage(type: StateMessageType.empty)),
      );
      expect(find.text('Nothing here yet'), findsOneWidget);

      await tester.pumpWidget(
        wrap(const StateMessage(type: StateMessageType.unauthorized)),
      );
      expect(find.text('Access denied'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('custom title and message override the defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const StateMessage(
            type: StateMessageType.empty,
            title: 'No students yet',
            message: 'Add your first student.',
          ),
        ),
      );

      expect(find.text('No students yet'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);
    });
  });

  group('AppScreenBar', () {
    testWidgets('large style shows the title and no back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            appBar: AppScreenBar.large(
              title: 'Dashboard',
              subtitle: 'District',
            ),
            body: SizedBox(),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('District'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('back style shows a chevron that fires onBack', (tester) async {
      var backs = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppScreenBar.back(
              title: 'Student Details',
              onBack: () => backs++,
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(find.text('Student Details'), findsOneWidget);
      expect(backs, 1);
    });
  });

  group('AppShell', () {
    // The shell must not know about roles, so the same widget is built
    // with each role's tab set.
    const districtTabs = [
      AppNavItem(label: 'Home', icon: Icons.home_outlined),
      AppNavItem(label: 'Schools', icon: Icons.apartment_outlined),
      AppNavItem(label: 'Exams', icon: Icons.assignment_outlined),
      AppNavItem(label: 'Profile', icon: Icons.person_outline),
    ];

    const studentTabs = [
      AppNavItem(label: 'Home', icon: Icons.home_outlined),
      AppNavItem(label: 'Exams', icon: Icons.assignment_outlined),
      AppNavItem(label: 'Profile', icon: Icons.person_outline),
    ];

    testWidgets('renders any list of tabs it is given', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            items: districtTabs,
            currentIndex: 0,
            onItemSelected: (_) {},
            body: const Text('District body'),
          ),
        ),
      );

      expect(find.text('District body'), findsOneWidget);
      for (final tab in districtTabs) {
        expect(find.text(tab.label), findsOneWidget);
      }

      // The same shell, a different role's tabs.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            items: studentTabs,
            currentIndex: 0,
            onItemSelected: (_) {},
            body: const Text('Student body'),
          ),
        ),
      );

      expect(find.text('Schools'), findsNothing);
      expect(find.text('Exams'), findsOneWidget);
    });

    testWidgets('reports the tapped index to its caller', (tester) async {
      var tapped = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            items: districtTabs,
            currentIndex: 0,
            onItemSelected: (index) => tapped = index,
            body: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.text('Exams'));
      await tester.pump();

      expect(tapped, 2);
    });

    testWidgets('hides the bar when there are fewer than two tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            items: const [AppNavItem(label: 'Home', icon: Icons.home_outlined)],
            currentIndex: 0,
            onItemSelected: (_) {},
            body: const Text('Only body'),
          ),
        ),
      );

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('Only body'), findsOneWidget);
    });
  });
}

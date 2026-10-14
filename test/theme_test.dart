import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/constants/app_colors.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/app_button.dart';
import 'package:my_flutter_edulens/core/widgets/app_card.dart';
import 'package:my_flutter_edulens/core/widgets/app_text_field.dart';
import 'package:my_flutter_edulens/core/widgets/status_badge.dart';

void main() {
  testWidgets('AppTheme configuration test', (WidgetTester tester) async {
    final theme = AppTheme.lightTheme;
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
  });

  testWidgets('Core UI components render correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              const StatusBadge(label: 'Active', type: StatusType.success),
              const AppCard(child: Text('Card Content')),
              AppButton(label: 'Submit', onPressed: () {}),
              const AppTextField(label: 'Email', hint: 'enter email'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Card Content'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
  });
}

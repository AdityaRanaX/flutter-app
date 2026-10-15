import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// One labelled fact on a details screen: a label on the left, its value
/// on the right.
///
/// Used for the exam's date, time, class and student count, so those rows
/// line up and read consistently.
class ExamInfoRow extends StatelessWidget {
  final String label;

  /// The value to show. When null or blank the row renders a dash, so a
  /// missing fact is visibly missing rather than silently absent.
  final String? value;

  const ExamInfoRow({super.key, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final shown = (value == null || value!.trim().isEmpty) ? '—' : value!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              shown,
              style: AppTextStyles.body,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

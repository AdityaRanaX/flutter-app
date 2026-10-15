import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../models/exam_model.dart';

/// One exam in a list: subject, when it is, and which school holds it.
///
/// Shared by the District Exam Overview and anywhere else exams are
/// listed, so an exam row looks and reads the same throughout.
///
/// It takes a model and renders it. It never queries Firestore, and it
/// never resolves the school name itself — the caller passes a name it has
/// already looked up, because a widget that fetched per row would issue
/// one read per visible item.
class ExamListTile extends StatelessWidget {
  final ExamModel exam;

  /// The school's display name, already resolved from [ExamModel.schoolId].
  ///
  /// Null when the school could not be found. The row then simply omits
  /// the school rather than showing an id or inventing a name.
  final String? schoolName;

  /// Called with this exam's id. Nothing else identifies an exam: several
  /// schools and classes can run the same subject on the same day.
  final void Function(String examId)? onTap;

  const ExamListTile({
    super.key,
    required this.exam,
    this.schoolName,
    this.onTap,
  });

  /// `16 Oct 2026 · 10:00 · Greenwood High`, dropping any part that is
  /// missing rather than leaving a stray separator behind.
  String get _subtitle {
    final parts = <String>[
      AppDate.formatWithTime(exam.date, exam.startTime),
      if (schoolName != null && schoolName!.trim().isNotEmpty) schoolName!,
    ];
    return parts.where((p) => p.trim().isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      icon: Icons.event_outlined,
      iconColor: AppColors.warning,
      iconBackground: AppColors.warningSoft,
      title: exam.subject,
      subtitle: _subtitle,
      showChevron: onTap != null,
      onTap: onTap == null ? null : () => onTap!(exam.examId),
    );
  }
}

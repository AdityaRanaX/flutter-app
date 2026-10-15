import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/exam_details_controller.dart';
import '../widgets/exam_info_row.dart';

/// One examination, reached from the District Exam Overview.
///
/// A pushed route with its own Scaffold, rather than a tab in the shell.
///
/// The approved wireframe marks each student Present or Absent. That is
/// **not** shown here, and the omission is deliberate: `AttendanceModel`
/// has no link to an exam, so a daily attendance record cannot say whether
/// a student sat this exam. Pairing names with guessed statuses would be
/// inventing data. The screen says so rather than leaving a silent gap.
class ExamDetailsScreen extends StatefulWidget {
  /// Which exam to load. An id, never a subject — several schools and
  /// classes can hold an exam in the same subject.
  final String examId;

  final ExamDetailsController controller;

  const ExamDetailsScreen({
    super.key,
    required this.examId,
    required this.controller,
  });

  @override
  State<ExamDetailsScreen> createState() => _ExamDetailsScreenState();
}

class _ExamDetailsScreenState extends State<ExamDetailsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.examId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final title = state.data?.exam.subject ?? 'Exam';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppScreenBar.back(
              title: title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            body: ViewStateBuilder<ExamDetails>(
              state: state,
              onRetry: () => widget.controller.load(widget.examId),
              builder: (context, details) => _buildBody(context, details),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ExamDetails details) {
    return Column(
      children: [
        _header(details),
        const TabBar(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Students'),
            Tab(text: 'Details'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [_studentsTab(details), _detailsTab(details)],
          ),
        ),
      ],
    );
  }

  Widget _header(ExamDetails details) {
    final exam = details.exam;
    final school = details.schoolName;

    return Padding(
      padding: AppSpacing.paddingScreen,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exam.subject, style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              // The school is dropped when unknown rather than shown as an
              // id or a made-up name.
              [
                if (school != null && school.trim().isNotEmpty) school,
                exam.className,
              ].join(' · '),
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppDate.formatWithTime(exam.date, exam.startTime),
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------- students

  Widget _studentsTab(ExamDetails details) {
    final students = widget.controller.visibleStudents;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: AppTextField(
            controller: _searchController,
            hint: 'Search students',
            prefixIcon: Icons.search,
            onChanged: widget.controller.search,
          ),
        ),
        Expanded(
          child: students.isEmpty
              ? _emptyMessage(
                  widget.controller.query.trim().isEmpty
                      ? 'No students are registered for this class.'
                      : 'No students match "${widget.controller.query.trim()}".',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemCount: students.length + 1,
                  itemBuilder: (context, i) {
                    if (i == students.length) return _attendanceGapNote();
                    final s = students[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppListTile(
                        icon: Icons.person_outline,
                        title: s.name,
                        subtitle: 'Section ${s.section}',
                        showChevron: false,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// States plainly why there is no Present/Absent column, so the gap is
  /// visible to anyone using the screen rather than looking like an
  /// oversight.
  Widget _attendanceGapNote() {
    return const Padding(
      padding: EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        child: Text(
          'Per-exam attendance is not recorded yet. Attendance records are '
          'daily and are not linked to an exam, so no Present or Absent '
          'status is shown here.',
          style: AppTextStyles.caption,
        ),
      ),
    );
  }

  // ------------------------------------------------------------ details

  Widget _detailsTab(ExamDetails details) {
    final exam = details.exam;

    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        AppCard(
          child: Column(
            children: [
              ExamInfoRow(label: 'Subject', value: exam.subject),
              ExamInfoRow(label: 'School', value: details.schoolName),
              ExamInfoRow(label: 'Class', value: exam.className),
              ExamInfoRow(label: 'Date', value: AppDate.formatLong(exam.date)),
              ExamInfoRow(label: 'Start time', value: exam.startTime),
              ExamInfoRow(label: 'End time', value: exam.endTime),
              ExamInfoRow(
                label: 'Total students',
                value: '${details.totalStudents}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        // The wireframe shows a "Scheduled" status. Nothing in the
        // approved model stores one, and deriving it from the date would
        // be inventing a lifecycle the project never agreed, so the row is
        // left out and the reason recorded.
        const AppCard(
          child: Text(
            'Exam status is not shown. The approved exam model has no '
            'status field, and no rule has been agreed for deriving one.',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }

  Widget _emptyMessage(String message) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Text(
          message,
          style: AppTextStyles.bodySecondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

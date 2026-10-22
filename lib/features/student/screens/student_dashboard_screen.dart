import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../../../models/exam_model.dart';
import '../../../models/fee_model.dart';
import '../controllers/student_dashboard_controller.dart';

/// The Student's own dashboard: their attendance, their fee status and
/// their upcoming exams.
///
/// The screen is **read-only by construction**. It offers no action that
/// writes attendance, fees or exams, because the approved student role is
/// to view their own academic information. That is a UX decision and not
/// a security control — Firestore rules refuse student writes
/// independently, and would still refuse them if this screen were
/// bypassed entirely.
class StudentDashboardScreen extends StatefulWidget {
  final StudentDashboardController controller;

  const StudentDashboardScreen({super.key, required this.controller});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Only the first load is started here. Keying on the initial loading
    // state rather than on "not ready" matters twice over: a rebuild after
    // a failure must not silently re-issue the request, and a controller a
    // caller has already driven must be left as it is. Retry and
    // pull-to-refresh remain the ways to ask again.
    if (widget.controller.state.isLoading) {
      widget.controller.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ViewStateBuilder(
          state: widget.controller.state,
          onRetry: () => widget.controller.load(),
          emptyTitle: 'Nothing to show yet',
          builder: (context, data) => _buildDashboard(context, data),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, StudentDashboardData data) {
    return RefreshIndicator(
      onRefresh: () => widget.controller.load(),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _header(data),
          const SizedBox(height: AppSpacing.lg),
          _attendanceCard(data),
          const SizedBox(height: AppSpacing.lg),
          _feeCard(data),
          const SizedBox(height: AppSpacing.lg),
          _upcomingExams(data),
        ],
      ),
    );
  }

  Widget _header(StudentDashboardData data) {
    final student = data.student;
    final name = student.name.trim();
    final roll = student.rollNumber?.trim();

    // A legacy record without a roll number is shown without one rather
    // than with a placeholder standing in for a real value.
    final subtitle = [
      student.className,
      if (student.section.isNotEmpty) 'Section ${student.section}',
      if (roll != null && roll.isNotEmpty) 'Roll $roll',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
          style: AppTextStyles.screenTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTextStyles.bodySecondary),
      ],
    );
  }

  // ------------------------------------------------------------ attendance

  Widget _attendanceCard(StudentDashboardData data) {
    final percent = data.attendancePercent;
    final isLow = percent != null && percent < Metrics.attentionThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Attendance', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // Renders an em dash when there is nothing to
                          // measure, never 0%.
                          Metrics.formatPercent(percent),
                          style: AppTextStyles.statNumber.copyWith(
                            color: percent == null
                                ? AppColors.textMuted
                                : (isLow
                                      ? AppColors.danger
                                      : AppColors.success),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          data.hasNoAttendance
                              ? 'No attendance has been recorded for you yet'
                              : 'Based on ${data.attendanceRecordCount} '
                                    'recorded ${data.attendanceRecordCount == 1 ? "day" : "days"}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (isLow)
                    const StatusBadge(
                      label: 'Below 70%',
                      type: StatusType.error,
                    ),
                ],
              ),
              if (!data.hasNoAttendance) ...[
                const SizedBox(height: AppSpacing.sm),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                _breakdownRow(data),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _breakdownRow(StudentDashboardData data) {
    final b = data.attendanceBreakdown;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _breakdownItem('Present', b.present, AppColors.success),
        _breakdownItem('Absent', b.absent, AppColors.danger),
        _breakdownItem('Leave', b.leave, AppColors.warning),
      ],
    );
  }

  Widget _breakdownItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: AppTextStyles.cardTitle.copyWith(color: color)),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  // ------------------------------------------------------------------ fees

  Widget _feeCard(StudentDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Fees', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        if (data.fee == null)
          const AppCard(
            child: Text(
              'No fee record has been raised for you yet.',
              style: AppTextStyles.bodySecondary,
            ),
          )
        else
          _feeDetails(data.fee!),
      ],
    );
  }

  Widget _feeDetails(FeeModel fee) {
    final outstanding = fee.totalDue - fee.paidAmount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fee Status', style: AppTextStyles.cardTitle),
              StatusBadge(
                // The stored status is shown as written. This screen does
                // not recompute it from the amounts.
                label: fee.status.isEmpty ? 'Unknown' : fee.status,
                type: _feeStatusType(fee.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _amountRow('Total due', fee.totalDue),
          const SizedBox(height: AppSpacing.xs),
          _amountRow('Paid so far', fee.paidAmount),
          if (outstanding > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _amountRow('Outstanding', outstanding, emphasise: true),
          ],
          if (fee.remarks != null && fee.remarks!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            Text(fee.remarks!.trim(), style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool emphasise = false}) {
    final style = emphasise
        ? AppTextStyles.bodySecondary.copyWith(
            color: AppColors.danger,
            fontWeight: FontWeight.w600,
          )
        : AppTextStyles.bodySecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(_formatAmount(amount), style: style),
      ],
    );
  }

  /// Amounts are rendered without a currency symbol, because the fee model
  /// stores no currency and inventing one here could misstate the figure.
  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.round().toString();
    return amount.toStringAsFixed(2);
  }

  StatusType _feeStatusType(String status) {
    switch (status.trim().toLowerCase()) {
      case Metrics.feePaid:
        return StatusType.success;
      case Metrics.feePartial:
        return StatusType.warning;
      case Metrics.feeOutstanding:
        return StatusType.error;
      default:
        return StatusType.info;
    }
  }

  // ----------------------------------------------------------------- exams

  Widget _upcomingExams(StudentDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Exams', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        // Its own ViewState, so a denied exam read shows as a denial here
        // while attendance and fees above stay on screen.
        ViewStateBuilder<List<ExamModel>>(
          state: data.exams,
          emptyTitle: 'No upcoming exams',
          builder: (context, exams) =>
              Column(children: exams.map(_examTile).toList()),
        ),
      ],
    );
  }

  Widget _examTile(ExamModel exam) {
    final times = [
      if (exam.startTime.trim().isNotEmpty) exam.startTime.trim(),
      if (exam.endTime.trim().isNotEmpty) exam.endTime.trim(),
    ].join(' – ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppListTile(
        icon: Icons.event_outlined,
        iconColor: AppColors.warning,
        iconBackground: AppColors.warningSoft,
        title: exam.subject,
        subtitle: times.isEmpty
            ? AppDate.formatLong(exam.date)
            : '${AppDate.formatLong(exam.date)} · $times',
        showChevron: false,
      ),
    );
  }
}

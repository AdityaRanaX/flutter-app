import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/district_dashboard_controller.dart';
import '../models/school_summary.dart';

/// The District Administrator's home screen.
///
/// It sits inside [DistrictShell], which supplies the app bar and bottom
/// navigation, so this builds the body only.
///
/// Every number shown comes from the controller. There are no Firestore
/// queries here and no arithmetic — a widget that calculated its own
/// metric would be a second, untested definition of it.
class DistrictDashboardScreen extends StatefulWidget {
  final DistrictDashboardController controller;

  /// Shown in the greeting. Null falls back to a neutral wording rather
  /// than inventing a name.
  final String? administratorName;

  /// Opens the School List, used by the attention-areas section.
  final VoidCallback? onViewSchools;

  const DistrictDashboardScreen({
    super.key,
    required this.controller,
    this.administratorName,
    this.onViewSchools,
  });

  @override
  State<DistrictDashboardScreen> createState() =>
      _DistrictDashboardScreenState();
}

class _DistrictDashboardScreenState extends State<DistrictDashboardScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ViewStateBuilder(
          state: widget.controller.state,
          onRetry: widget.controller.load,
          emptyTitle: 'No schools yet',
          builder: (context, _) => _buildDashboard(context),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final c = widget.controller;

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _greeting(),
          const SizedBox(height: AppSpacing.lg),
          _statGrid(c),
          const SizedBox(height: AppSpacing.lg),
          _upcomingExams(c),
          const SizedBox(height: AppSpacing.lg),
          _attentionAreas(c),
        ],
      ),
    );
  }

  Widget _greeting() {
    final name = widget.administratorName?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
          style: AppTextStyles.screenTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Here is how your district is doing today.',
          style: AppTextStyles.bodySecondary,
        ),
      ],
    );
  }

  Widget _statGrid(DistrictDashboardController c) {
    // A fixed two-column grid, sized by its children rather than a fixed
    // aspect ratio, so a long label does not clip on a narrow phone.
    final cards = [
      StatCard(
        icon: Icons.apartment_outlined,
        label: 'Total Schools',
        value: '${c.totalSchools}',
        iconColor: AppColors.info,
        iconBackground: AppColors.infoSoft,
      ),
      StatCard(
        icon: Icons.fact_check_outlined,
        label: 'Average Attendance',
        value: Metrics.formatPercent(c.averageAttendance),
        iconColor: AppColors.success,
        iconBackground: AppColors.successSoft,
      ),
      StatCard(
        icon: Icons.payments_outlined,
        label: 'Fees Paid',
        value: Metrics.formatPercent(c.feesPaidPercent),
        iconColor: AppColors.purple,
        iconBackground: AppColors.purpleSoft,
      ),
      StatCard(
        icon: Icons.event_note_outlined,
        label: 'Exams (next 7 days)',
        value: '${c.upcomingExams.length}',
        iconColor: AppColors.warning,
        iconBackground: AppColors.warningSoft,
      ),
    ];

    return Column(
      children: [
        _cardRow(cards[0], cards[1]),
        const SizedBox(height: AppSpacing.ms),
        _cardRow(cards[2], cards[3]),
      ],
    );
  }

  /// Two cards side by side at equal height.
  ///
  /// [IntrinsicHeight] is what makes `stretch` legal here: inside a
  /// scrolling list the row's height is unbounded, and stretching against
  /// an unbounded constraint is an error. Measuring the taller card first
  /// gives both a real height to stretch to, so a card with a longer
  /// label does not leave its neighbour short.
  Widget _cardRow(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: AppSpacing.ms),
          Expanded(child: right),
        ],
      ),
    );
  }

  Widget _upcomingExams(DistrictDashboardController c) {
    final exams = c.upcomingExams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Exams', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        if (exams.isEmpty)
          const AppCard(
            child: Text(
              'No exams are scheduled in the next 7 days.',
              style: AppTextStyles.bodySecondary,
            ),
          )
        else
          ...exams.map(
            (exam) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppListTile(
                icon: Icons.event_outlined,
                iconColor: AppColors.warning,
                iconBackground: AppColors.warningSoft,
                title: exam.subject,
                subtitle: AppDate.formatWithTime(exam.date, exam.startTime),
                showChevron: false,
              ),
            ),
          ),
      ],
    );
  }

  Widget _attentionAreas(DistrictDashboardController c) {
    final flagged = c.attentionAreas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attention Areas', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Schools below ${Metrics.attentionThreshold.round()}% attendance.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (flagged.isEmpty)
          const AppCard(
            child: Text(
              'Every school is at or above the attendance threshold.',
              style: AppTextStyles.bodySecondary,
            ),
          )
        else
          ...flagged.map(_attentionTile),
      ],
    );
  }

  Widget _attentionTile(SchoolSummary summary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppListTile(
        icon: Icons.warning_amber_outlined,
        iconColor: AppColors.danger,
        iconBackground: AppColors.dangerSoft,
        title: summary.schoolName,
        subtitle:
            '${Metrics.formatPercent(summary.attendancePercent)} attendance',
        showChevron: widget.onViewSchools != null,
        onTap: widget.onViewSchools,
      ),
    );
  }
}

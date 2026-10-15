import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/school_admin_dashboard_controller.dart';

/// The School Administrator's dashboard screen.
///
/// Displays school-scoped metrics, including total students, total teachers,
/// overall attendance rate, fees paid percentage, upcoming exams, and school contact details.
class SchoolAdminDashboardScreen extends StatefulWidget {
  final SchoolAdminDashboardController controller;
  final String? schoolId;

  const SchoolAdminDashboardScreen({
    super.key,
    required this.controller,
    this.schoolId,
  });

  @override
  State<SchoolAdminDashboardScreen> createState() =>
      _SchoolAdminDashboardScreenState();
}

class _SchoolAdminDashboardScreenState
    extends State<SchoolAdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.state.isReady) {
      widget.controller.load(schoolId: widget.schoolId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ViewStateBuilder(
          state: widget.controller.state,
          onRetry: () => widget.controller.load(schoolId: widget.schoolId),
          emptyTitle: 'No School Data',
          builder: (context, data) => _buildDashboard(context, data),
        );
      },
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    SchoolAdminDashboardData data,
  ) {
    return RefreshIndicator(
      onRefresh: () => widget.controller.load(schoolId: widget.schoolId),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _greetingHeader(data),
          const SizedBox(height: AppSpacing.lg),
          _schoolInfoCard(data),
          const SizedBox(height: AppSpacing.lg),
          _statGrid(data),
          const SizedBox(height: AppSpacing.lg),
          _attendanceAlertIfLow(data),
          _upcomingExams(data),
        ],
      ),
    );
  }

  Widget _greetingHeader(SchoolAdminDashboardData data) {
    final name = data.administratorProfile.name.trim();
    final displayName = name.isEmpty ? 'Administrator' : name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $displayName',
          style: AppTextStyles.screenTitle,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Overview for ${data.school.schoolName}',
          style: AppTextStyles.bodySecondary,
        ),
      ],
    );
  }

  Widget _schoolInfoCard(SchoolAdminDashboardData data) {
    final school = data.school;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  school.schoolName,
                  style: AppTextStyles.cardTitle,
                ),
              ),
              const StatusBadge(
                label: 'Active',
                type: StatusType.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  school.location,
                  style: AppTextStyles.bodySecondary,
                ),
              ),
            ],
          ),
          if (school.address != null && school.address!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              school.address!,
              style: AppTextStyles.caption,
            ),
          ],
          if ((school.contactNumber != null && school.contactNumber!.isNotEmpty) ||
              (school.email != null && school.email!.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                if (school.contactNumber != null &&
                    school.contactNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        school.contactNumber!,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                if (school.email != null && school.email!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        school.email!,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statGrid(SchoolAdminDashboardData data) {
    final cards = [
      StatCard(
        icon: Icons.groups_outlined,
        label: 'Total Students',
        value: '${data.totalStudents}',
        iconColor: AppColors.info,
        iconBackground: AppColors.infoSoft,
      ),
      StatCard(
        icon: Icons.badge_outlined,
        label: 'Total Teachers',
        value: '${data.totalTeachers}',
        iconColor: AppColors.purple,
        iconBackground: AppColors.purpleSoft,
      ),
      StatCard(
        icon: Icons.fact_check_outlined,
        label: 'Attendance Rate',
        value: Metrics.formatPercent(data.attendancePercent),
        iconColor: AppColors.success,
        iconBackground: AppColors.successSoft,
      ),
      StatCard(
        icon: Icons.payments_outlined,
        label: 'Fees Paid',
        value: Metrics.formatPercent(data.feePaidPercent),
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

  Widget _attendanceAlertIfLow(SchoolAdminDashboardData data) {
    final percent = data.attendancePercent;
    if (percent == null || percent >= Metrics.attentionThreshold) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        AppCard(
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: AppColors.danger,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Warning',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'School attendance is currently ${Metrics.formatPercent(percent)}, which is below the ${Metrics.attentionThreshold.round()}% threshold.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _upcomingExams(SchoolAdminDashboardData data) {
    final exams = data.upcomingExams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upcoming Exams', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        if (exams.isEmpty)
          const AppCard(
            child: Text(
              'No exams scheduled in the next 7 days for this school.',
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
                title: '${exam.subject} (${exam.className})',
                subtitle: AppDate.formatWithTime(exam.date, exam.startTime),
                showChevron: false,
              ),
            ),
          ),
      ],
    );
  }
}

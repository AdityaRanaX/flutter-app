import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/school_details_controller.dart';

/// One school, reached by tapping a row in the School List.
///
/// Unlike the dashboard and the list, this is a pushed route with its own
/// Scaffold rather than a tab inside the shell.
class SchoolDetailsScreen extends StatefulWidget {
  /// Which school to load. Passed as an id, never a name — see
  /// [SchoolDetailsController].
  final String schoolId;

  final SchoolDetailsController controller;

  const SchoolDetailsScreen({
    super.key,
    required this.schoolId,
    required this.controller,
  });

  @override
  State<SchoolDetailsScreen> createState() => _SchoolDetailsScreenState();
}

class _SchoolDetailsScreenState extends State<SchoolDetailsScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        final title = state.data?.school.schoolName ?? 'School';

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppScreenBar.back(
              title: title,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            body: ViewStateBuilder<SchoolDetails>(
              state: state,
              onRetry: () => widget.controller.load(widget.schoolId),
              builder: (context, details) => _buildTabs(context, details),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs(BuildContext context, SchoolDetails details) {
    return Column(
      children: [
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Attendance'),
            Tab(text: 'Fees'),
            Tab(text: 'Exams'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _overview(details),
              _attendance(details),
              _fees(details),
              _exams(details),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- overview

  Widget _overview(SchoolDetails d) {
    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.school.schoolName, style: AppTextStyles.cardTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(d.school.location, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        _metricRow('Students', '${d.studentCount}'),
        _metricRow('Attendance', Metrics.formatPercent(d.attendancePercent)),
        _metricRow('Fees paid', Metrics.formatPercent(d.feePaidPercent)),
        _metricRow('Upcoming exams', '${d.upcomingExams.length}'),
        const SizedBox(height: AppSpacing.md),
        // Address, contact number and email appear on the School
        // Information wireframe but are not in the approved model. They
        // are named here rather than faked, so the gap stays visible.
        const AppCard(
          child: Text(
            'Address, contact number and email are not yet part of the '
            'approved school model, so they are not shown.',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.body),
            Text(value, style: AppTextStyles.cardTitle),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------- attendance

  Widget _attendance(SchoolDetails d) {
    final a = d.attendance;

    if (a.isEmpty) {
      return _emptyTab('No attendance has been recorded for this school yet.');
    }

    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _breakdownCard(
          title: 'Attendance',
          value: Metrics.formatPercent(d.attendancePercent),
          rows: [
            ('Present', a.present, AppColors.success),
            ('Absent', a.absent, AppColors.danger),
            ('Leave', a.leave, AppColors.warning),
          ],
          total: a.total,
        ),
        const SizedBox(height: AppSpacing.ms),
        if (a.leave == 0)
          const AppCard(
            child: Text(
              'Leave is shown for completeness. It is not yet an approved '
              'attendance status, so no records use it.',
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- fees

  Widget _fees(SchoolDetails d) {
    final f = d.fees;

    if (f.isEmpty) {
      return _emptyTab('No fee records exist for this school yet.');
    }

    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        _breakdownCard(
          title: 'Fees collected',
          value: Metrics.formatPercent(d.feePaidPercent),
          rows: [
            ('Paid', f.paid, AppColors.success),
            ('Partial', f.partial, AppColors.warning),
            ('Outstanding', f.outstanding, AppColors.danger),
          ],
          total: f.total,
        ),
        const SizedBox(height: AppSpacing.ms),
        const AppCard(
          child: Text(
            'The percentage is weighted by amount, while the breakdown '
            'counts records. They answer different questions.',
            style: AppTextStyles.caption,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- exams

  Widget _exams(SchoolDetails d) {
    if (d.upcomingExams.isEmpty) {
      return _emptyTab('No upcoming exams are scheduled for this school.');
    }

    return ListView(
      padding: AppSpacing.paddingScreen,
      children: [
        for (final exam in d.upcomingExams)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppListTile(
              icon: Icons.event_outlined,
              iconColor: AppColors.warning,
              iconBackground: AppColors.warningSoft,
              title: exam.subject,
              subtitle:
                  '${exam.className} · ${AppDate.formatWithTime(exam.date, exam.startTime)}',
              showChevron: false,
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- shared

  Widget _breakdownCard({
    required String title,
    required String value,
    required List<(String, int, Color)> rows,
    required int total,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.cardTitle),
              Text(value, style: AppTextStyles.statNumber),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          for (final (label, count, color) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(label, style: AppTextStyles.body)),
                  Text('$count of $total', style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyTab(String message) {
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

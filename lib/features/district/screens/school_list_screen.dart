import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/school_list_controller.dart';
import '../models/school_summary.dart';

/// The District Administrator's searchable list of schools.
///
/// Sits inside [DistrictShell], so it builds the body only.
///
/// The wireframe also shows a filter icon beside the search field. It is
/// not implemented here: the UX document does not define what the filters
/// are, and shipping an enabled control that does nothing is worse than
/// leaving it out. Recorded as an open UX decision in the PR.
class SchoolListScreen extends StatefulWidget {
  final SchoolListController controller;

  /// Called with the tapped school's id. The id is passed rather than the
  /// name or the row index, so the details screen loads the right record
  /// even after the list has been searched.
  final void Function(String schoolId)? onSchoolSelected;

  const SchoolListScreen({
    super.key,
    required this.controller,
    this.onSchoolSelected,
  });

  @override
  State<SchoolListScreen> createState() => _SchoolListScreenState();
}

class _SchoolListScreenState extends State<SchoolListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.load();
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
        return Column(
          children: [
            Padding(
              padding: AppSpacing.paddingScreen,
              child: AppTextField(
                controller: _searchController,
                hint: 'Search schools',
                prefixIcon: Icons.search,
                onChanged: widget.controller.search,
              ),
            ),
            Expanded(
              child: ViewStateBuilder<List<SchoolSummary>>(
                state: widget.controller.state,
                onRetry: widget.controller.load,
                emptyTitle: widget.controller.query.trim().isEmpty
                    ? 'No schools yet'
                    : 'No matches',
                builder: (context, schools) => RefreshIndicator(
                  onRefresh: widget.controller.load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    itemCount: schools.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.ms),
                      child: _SchoolCard(
                        summary: schools[i],
                        onTap: widget.onSchoolSelected == null
                            ? null
                            : () =>
                                  widget.onSchoolSelected!(schools[i].schoolId),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One school's row: name, location, and the five derived figures the
/// wireframe lists.
class _SchoolCard extends StatelessWidget {
  final SchoolSummary summary;
  final VoidCallback? onTap;

  const _SchoolCard({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.schoolName,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      summary.school.location,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.ms),
          // Wrap rather than a Row: five figures do not fit across a
          // narrow phone, and they should reflow instead of clipping.
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _Figure(
                icon: Icons.groups_outlined,
                label: '${summary.studentCount} students',
              ),
              _Figure(
                icon: Icons.person_outline,
                label: '${summary.teacherCount} teachers',
              ),
              _Figure(
                icon: Icons.fact_check_outlined,
                label:
                    '${Metrics.formatPercent(summary.attendancePercent)} attendance',
              ),
              _Figure(
                icon: Icons.payments_outlined,
                label: '${Metrics.formatPercent(summary.feePaidPercent)} fees',
              ),
              _Figure(
                icon: Icons.event_note_outlined,
                label: '${summary.examCount} exams',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Figure({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

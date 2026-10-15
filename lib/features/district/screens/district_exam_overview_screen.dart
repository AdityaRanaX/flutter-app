import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../../../models/exam_model.dart';
import '../controllers/exam_overview_controller.dart';
import '../widgets/exam_list_tile.dart';

/// Examinations across every school the District Administrator may see.
///
/// Sits inside [DistrictShell], so it builds the body only.
class DistrictExamOverviewScreen extends StatefulWidget {
  final ExamOverviewController controller;

  /// Called with the tapped exam's id.
  final void Function(String examId)? onExamSelected;

  const DistrictExamOverviewScreen({
    super.key,
    required this.controller,
    this.onExamSelected,
  });

  @override
  State<DistrictExamOverviewScreen> createState() =>
      _DistrictExamOverviewScreenState();
}

class _DistrictExamOverviewScreenState
    extends State<DistrictExamOverviewScreen> {
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
        return Column(
          children: [
            Padding(
              padding: AppSpacing.paddingScreen,
              child: SegmentedButton<ExamFilter>(
                segments: const [
                  ButtonSegment(
                    value: ExamFilter.upcoming,
                    label: Text('Upcoming'),
                  ),
                  ButtonSegment(
                    value: ExamFilter.all,
                    label: Text('All Exams'),
                  ),
                ],
                selected: {widget.controller.filter},
                onSelectionChanged: (selection) =>
                    widget.controller.setFilter(selection.first),
              ),
            ),
            Expanded(
              child: ViewStateBuilder<List<ExamModel>>(
                state: widget.controller.state,
                onRetry: widget.controller.load,
                emptyTitle: 'No exams',
                builder: (context, exams) => RefreshIndicator(
                  onRefresh: widget.controller.load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    itemCount: exams.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ExamListTile(
                        exam: exams[i],
                        schoolName: widget.controller.schoolNameFor(exams[i]),
                        onTap: widget.onExamSelected,
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

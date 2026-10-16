import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../../../models/exam_model.dart';
import '../../../routes/app_routes.dart';
import '../../district/controllers/exam_overview_controller.dart';
import '../../district/widgets/exam_list_tile.dart';
import '../controllers/school_exam_schedule_controller.dart';

/// Screen displaying and managing the school-scoped exam schedule.
class SchoolExamScheduleScreen extends StatefulWidget {
  final SchoolExamScheduleController controller;
  final String? schoolId;
  final String? currentUserId;
  final ValueChanged<ExamModel>? onExamSelected;

  const SchoolExamScheduleScreen({
    super.key,
    required this.controller,
    this.schoolId,
    this.currentUserId,
    this.onExamSelected,
  });

  @override
  State<SchoolExamScheduleScreen> createState() =>
      _SchoolExamScheduleScreenState();
}

class _SchoolExamScheduleScreenState extends State<SchoolExamScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (!widget.controller.state.isReady) {
      widget.controller.load(schoolId: widget.schoolId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExamModel> _filterExams(List<ExamModel> exams) {
    if (_searchQuery.isEmpty) return exams;
    return exams.where((e) {
      final q = _searchQuery.toLowerCase();
      return e.subject.toLowerCase().contains(q) ||
          e.className.toLowerCase().contains(q);
    }).toList();
  }

  void _openScheduleDialog(String schoolId) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ScheduleExamDialog(
        schoolId: schoolId,
        currentUserId: widget.currentUserId ?? 'admin',
        controller: widget.controller,
        onSaved: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New exam scheduled successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ViewStateBuilder(
          state: widget.controller.state,
          onRetry: () => widget.controller.load(schoolId: widget.schoolId),
          emptyTitle: 'No Exams Scheduled',
          builder: (context, exams) => _buildBody(context, exams),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, List<ExamModel> exams) {
    final filtered = _filterExams(exams);
    final schoolName = widget.controller.school?.schoolName;
    final activeSchoolId = widget.controller.targetSchoolId ?? widget.schoolId;

    return RefreshIndicator(
      onRefresh: () => widget.controller.load(schoolId: widget.schoolId),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _filterAndActionHeader(activeSchoolId),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _searchController,
            hint: 'Search by subject or class',
            prefixIcon: Icons.search_outlined,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
          const SizedBox(height: AppSpacing.md),
          if (filtered.isEmpty)
            const AppCard(
              child: Text(
                'No exams match your search criteria.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          else
            ...filtered.map(
              (exam) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ExamListTile(
                  exam: exam,
                  schoolName: schoolName,
                  onTap: (_) {
                    if (widget.onExamSelected != null) {
                      widget.onExamSelected!(exam);
                    } else {
                      Navigator.of(context).pushNamed(
                        AppRoutes.examDetails,
                        arguments: exam.examId,
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterAndActionHeader(String? activeSchoolId) {
    final c = widget.controller;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            ChoiceChip(
              label: const Text('Upcoming'),
              selected: c.filter == ExamFilter.upcoming,
              onSelected: (selected) {
                if (selected) c.setFilter(ExamFilter.upcoming);
              },
            ),
            const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              label: const Text('All Exams'),
              selected: c.filter == ExamFilter.all,
              onSelected: (selected) {
                if (selected) c.setFilter(ExamFilter.all);
              },
            ),
          ],
        ),
        if (activeSchoolId != null && activeSchoolId.isNotEmpty)
          AppButton(
            label: 'Schedule Exam',
            icon: Icons.add,
            onPressed: () => _openScheduleDialog(activeSchoolId),
          ),
      ],
    );
  }
}

/// Modal dialog for scheduling a new exam.
class _ScheduleExamDialog extends StatefulWidget {
  final String schoolId;
  final String currentUserId;
  final SchoolExamScheduleController controller;
  final VoidCallback onSaved;

  const _ScheduleExamDialog({
    required this.schoolId,
    required this.currentUserId,
    required this.controller,
    required this.onSaved,
  });

  @override
  State<_ScheduleExamDialog> createState() => _ScheduleExamDialogState();
}

class _ScheduleExamDialogState extends State<_ScheduleExamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _classController = TextEditingController();
  final _dateController = TextEditingController(text: '2026-10-25');
  final _startTimeController = TextEditingController(text: '09:00 AM');
  final _endTimeController = TextEditingController(text: '12:00 PM');

  String? _formError;

  @override
  void dispose() {
    _subjectController.dispose();
    _classController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_subjectController.text.trim().isEmpty ||
        _classController.text.trim().isEmpty ||
        _dateController.text.trim().isEmpty ||
        _startTimeController.text.trim().isEmpty ||
        _endTimeController.text.trim().isEmpty) {
      setState(() => _formError = 'Please fill out all required exam fields.');
      return false;
    }
    setState(() => _formError = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final success = await widget.controller.addExam(
      schoolId: widget.schoolId,
      subject: _subjectController.text,
      className: _classController.text,
      date: _dateController.text,
      startTime: _startTimeController.text,
      endTime: _endTimeController.text,
      createdBy: widget.currentUserId,
    );

    if (mounted && success) {
      Navigator.of(context).pop();
      widget.onSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = widget.controller.isSaving;

    return AlertDialog(
      title: Text('Schedule New Exam', style: AppTextStyles.cardTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: _subjectController,
                label: 'Subject',
                hint: 'e.g. Mathematics',
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _classController,
                label: 'Class Name',
                hint: 'e.g. Class 10',
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _dateController,
                label: 'Date (yyyy-MM-dd)',
                hint: 'e.g. 2026-10-25',
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _startTimeController,
                      label: 'Start Time',
                      hint: '09:00 AM',
                      enabled: !isSaving,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _endTimeController,
                      label: 'End Time',
                      hint: '12:00 PM',
                      enabled: !isSaving,
                    ),
                  ),
                ],
              ),
              if (_formError != null ||
                  widget.controller.saveError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _formError ?? widget.controller.saveError!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Schedule Exam',
          isLoading: isSaving,
          onPressed: isSaving ? null : _submit,
        ),
      ],
    );
  }
}

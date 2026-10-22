import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/metrics.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../controllers/attendance_management_controller.dart';

/// Classroom daily attendance marking screen for Teachers and Admins.
class AttendanceManagementScreen extends StatefulWidget {
  final AttendanceManagementController controller;
  final String? schoolId;
  final String? teacherId;

  const AttendanceManagementScreen({
    super.key,
    required this.controller,
    this.schoolId,
    this.teacherId,
  });

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClassFilter = 'All';

  @override
  void initState() {
    super.initState();
    if (!widget.controller.state.isReady) {
      widget.controller.loadAttendance(schoolId: widget.schoolId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentAttendanceItem> _filterItems(List<StudentAttendanceItem> items) {
    return items.where((item) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          item.student.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (item.student.rollNumber != null &&
              item.student.rollNumber!.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ));

      final matchesClass =
          _selectedClassFilter == 'All' ||
          item.student.className == _selectedClassFilter;

      return matchesSearch && matchesClass;
    }).toList();
  }

  Set<String> _extractClasses(List<StudentAttendanceItem> items) {
    return {'All', ...items.map((e) => e.student.className)};
  }

  Future<void> _submitRegister(AttendanceManagementData data) async {
    final success = await widget.controller.saveAttendanceRegister(
      schoolId: data.schoolId,
      teacherId: widget.teacherId ?? 'teacher',
      date: data.date,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance register saved successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (widget.controller.saveError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.controller.saveError!),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return ViewStateBuilder(
          state: widget.controller.state,
          onRetry: () =>
              widget.controller.loadAttendance(schoolId: widget.schoolId),
          emptyTitle: 'No Students Found',
          builder: (context, data) => _buildBody(context, data),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AttendanceManagementData data) {
    final filteredItems = _filterItems(data.items);
    final allClasses = _extractClasses(data.items);
    final isSaving = widget.controller.isSaving;

    return RefreshIndicator(
      onRefresh: () => widget.controller.loadAttendance(
        schoolId: widget.schoolId,
        date: data.date,
      ),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _summaryGrid(data),
          const SizedBox(height: AppSpacing.lg),
          _searchAndFilterRow(allClasses),
          const SizedBox(height: AppSpacing.md),
          _quickMarkRow(),
          const SizedBox(height: AppSpacing.md),
          if (filteredItems.isEmpty)
            const AppCard(
              child: Text(
                'No students match the current search or filter criteria.',
                style: AppTextStyles.bodySecondary,
              ),
            )
          else
            ...filteredItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _studentAttendanceCard(item),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            key: const Key('save_attendance_button'),
            label: 'Save Attendance Register',
            icon: Icons.check_circle_outline,
            isLoading: isSaving,
            onPressed: isSaving ? null : () => _submitRegister(data),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _summaryGrid(AttendanceManagementData data) {
    final cards = [
      StatCard(
        icon: Icons.groups_outlined,
        label: 'Total Students',
        value: '${data.totalStudents}',
        iconColor: AppColors.info,
        iconBackground: AppColors.infoSoft,
      ),
      StatCard(
        icon: Icons.fact_check_outlined,
        label: 'Attendance Rate',
        value: Metrics.formatPercent(data.attendanceRate),
        iconColor: AppColors.success,
        iconBackground: AppColors.successSoft,
      ),
    ];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Daily Register', style: AppTextStyles.sectionHeading),
            StatusBadge(label: 'Date: ${data.date}', type: StatusType.info),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: AppSpacing.ms),
              Expanded(child: cards[1]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchAndFilterRow(Set<String> allClasses) {
    return Column(
      children: [
        AppTextField(
          controller: _searchController,
          hint: 'Search by student name or roll number',
          prefixIcon: Icons.search_outlined,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text('Class:', style: AppTextStyles.caption),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allClasses.map((cls) {
                    final isSelected = cls == _selectedClassFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(cls),
                        selected: isSelected,
                        onSelected: (selected) => setState(() {
                          if (selected) _selectedClassFilter = cls;
                        }),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickMarkRow() {
    final c = widget.controller;

    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: 'Mark All Present',
            isOutlined: true,
            onPressed: () => c.markAll('Present'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppButton(
            label: 'Mark All Absent',
            isOutlined: true,
            onPressed: () => c.markAll('Absent'),
          ),
        ),
      ],
    );
  }

  Widget _studentAttendanceCard(StudentAttendanceItem item) {
    final student = item.student;
    final rollNoText =
        student.rollNumber != null && student.rollNumber!.isNotEmpty
        ? 'Roll No: ${student.rollNumber}'
        : 'No Roll No.';

    final isPresent = item.currentStatus.toLowerCase() == 'present';

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Class ${student.className}-${student.section} • $rollNoText',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'Present',
                label: Text('Present'),
                icon: Icon(Icons.check_circle_outline, size: 16),
              ),
              ButtonSegment<String>(
                value: 'Absent',
                label: Text('Absent'),
                icon: Icon(Icons.cancel_outlined, size: 16),
              ),
            ],
            selected: {isPresent ? 'Present' : 'Absent'},
            onSelectionChanged: (Set<String> newSelection) {
              if (newSelection.isNotEmpty) {
                widget.controller.updateItemStatus(
                  student.studentId,
                  newSelection.first,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

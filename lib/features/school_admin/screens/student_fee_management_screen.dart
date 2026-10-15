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
import '../../../models/fee_model.dart';
import '../../../models/student_model.dart';
import '../controllers/student_fee_management_controller.dart';

/// Screen for managing school students and fee payment statuses.
class StudentFeeManagementScreen extends StatefulWidget {
  final StudentFeeManagementController controller;
  final String? schoolId;

  const StudentFeeManagementScreen({
    super.key,
    required this.controller,
    this.schoolId,
  });

  @override
  State<StudentFeeManagementScreen> createState() =>
      _StudentFeeManagementScreenState();
}

class _StudentFeeManagementScreenState
    extends State<StudentFeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClassFilter = 'All';

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

  List<StudentFeeListItem> _filterItems(List<StudentFeeListItem> items) {
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

  Set<String> _extractClasses(List<StudentFeeListItem> items) {
    return {'All', ...items.map((e) => e.student.className)};
  }

  void _openEditFeeDialog(StudentFeeListItem item) {
    final student = item.student;
    final fee =
        item.fee ??
        FeeModel(
          feeId: 'fee_${student.studentId}',
          studentId: student.studentId,
          schoolId: student.schoolId,
          totalDue: 1000.0,
          paidAmount: 0.0,
          status: 'Outstanding',
          updatedAt: DateTime.now().toIso8601String(),
        );

    showDialog(
      context: context,
      builder: (dialogContext) => _EditFeeDialog(
        student: student,
        fee: fee,
        controller: widget.controller,
        onSaved: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fee record updated successfully.'),
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
          emptyTitle: 'No Students Found',
          builder: (context, data) => _buildBody(context, data),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, StudentFeeData data) {
    final filteredItems = _filterItems(data.items);
    final allClasses = _extractClasses(data.items);

    return RefreshIndicator(
      onRefresh: () => widget.controller.load(schoolId: widget.schoolId),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _summaryGrid(data),
          const SizedBox(height: AppSpacing.lg),
          _searchAndFilterRow(allClasses),
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
                child: _studentFeeCard(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryGrid(StudentFeeData data) {
    final cards = [
      StatCard(
        icon: Icons.groups_outlined,
        label: 'Total Students',
        value: '${data.totalStudents}',
        iconColor: AppColors.info,
        iconBackground: AppColors.infoSoft,
      ),
      StatCard(
        icon: Icons.payments_outlined,
        label: 'Fees Paid Rate',
        value: Metrics.formatPercent(data.feePaidPercent),
        iconColor: AppColors.success,
        iconBackground: AppColors.successSoft,
      ),
    ];

    return Column(
      children: [
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
        const SizedBox(height: AppSpacing.sm),
        _feeBreakdownRow(data.feeBreakdown),
      ],
    );
  }

  Widget _feeBreakdownRow(FeeBreakdown breakdown) {
    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _breakdownItem('Paid', breakdown.paid, AppColors.success),
          _breakdownItem('Partial', breakdown.partial, AppColors.warning),
          _breakdownItem(
            'Outstanding',
            breakdown.outstanding,
            AppColors.danger,
          ),
        ],
      ),
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

  Widget _studentFeeCard(StudentFeeListItem item) {
    final student = item.student;
    final fee = item.fee;

    final rollNoText =
        student.rollNumber != null && student.rollNumber!.isNotEmpty
        ? 'Roll No: ${student.rollNumber}'
        : 'No Roll No.';

    final status = fee?.status ?? 'Outstanding';
    final paidAmount = fee?.paidAmount ?? 0.0;
    final totalDue = fee?.totalDue ?? 0.0;

    StatusType statusType;
    switch (status.toLowerCase()) {
      case 'paid':
        statusType = StatusType.success;
        break;
      case 'partial':
        statusType = StatusType.warning;
        break;
      default:
        statusType = StatusType.error;
        break;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              StatusBadge(label: status, type: statusType),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid: \$${paidAmount.toStringAsFixed(0)} / \$${totalDue.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySecondary,
                  ),
                  if (fee?.remarks != null && fee!.remarks!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Note: ${fee.remarks}',
                      style: AppTextStyles.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              AppButton(
                label: 'Edit Fee',
                isOutlined: true,
                onPressed: () => _openEditFeeDialog(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog for editing fee status, paid amount, and remarks notes.
class _EditFeeDialog extends StatefulWidget {
  final StudentModel student;
  final FeeModel fee;
  final StudentFeeManagementController controller;
  final VoidCallback onSaved;

  const _EditFeeDialog({
    required this.student,
    required this.fee,
    required this.controller,
    required this.onSaved,
  });

  @override
  State<_EditFeeDialog> createState() => _EditFeeDialogState();
}

class _EditFeeDialogState extends State<_EditFeeDialog> {
  late String _selectedStatus;
  late final TextEditingController _paidAmountController;
  late final TextEditingController _remarksController;

  String? _paidAmountError;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.fee.status;
    _paidAmountController = TextEditingController(
      text: widget.fee.paidAmount.toStringAsFixed(0),
    );
    _remarksController = TextEditingController(text: widget.fee.remarks ?? '');
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String? newStatus) {
    if (newStatus == null) return;
    setState(() {
      _selectedStatus = newStatus;
      if (newStatus == 'Paid') {
        _paidAmountController.text = widget.fee.totalDue.toStringAsFixed(0);
      } else if (newStatus == 'Outstanding') {
        _paidAmountController.text = '0';
      }
    });
  }

  bool _validate() {
    String? err;
    final amountText = _paidAmountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount < 0) {
      err = 'Please enter a valid positive paid amount';
    } else if (amount > widget.fee.totalDue) {
      err =
          'Paid amount cannot exceed total due (\$${widget.fee.totalDue.toStringAsFixed(0)})';
    }

    setState(() => _paidAmountError = err);
    return err == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final newPaidAmount = double.parse(_paidAmountController.text.trim());

    final success = await widget.controller.updateFeeRecord(
      currentFee: widget.fee,
      newStatus: _selectedStatus,
      newPaidAmount: newPaidAmount,
      newRemarks: _remarksController.text,
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
      title: Text('Edit Fee Status', style: AppTextStyles.cardTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: ${widget.student.name}',
              style: AppTextStyles.bodySecondary,
            ),
            Text(
              'Total Due: \$${widget.fee.totalDue.toStringAsFixed(0)}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Fee Status', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              items: const [
                DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                DropdownMenuItem(value: 'Partial', child: Text('Partial')),
                DropdownMenuItem(
                  value: 'Outstanding',
                  child: Text('Outstanding'),
                ),
              ],
              onChanged: isSaving ? null : _onStatusChanged,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _paidAmountController,
              label: 'Paid Amount (\$)',
              hint: 'Enter paid amount',
              keyboardType: TextInputType.number,
              errorText: _paidAmountError,
              enabled: !isSaving,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _remarksController,
              label: 'Remarks / Notes',
              hint: 'Enter payment remarks or receipt notes',
              maxLines: 2,
              enabled: !isSaving,
            ),
            if (widget.controller.saveError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.controller.saveError!,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Update Fee Status',
          isLoading: isSaving,
          onPressed: isSaving ? null : _submit,
        ),
      ],
    );
  }
}

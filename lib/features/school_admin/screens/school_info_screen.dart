import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_tile.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state_builder.dart';
import '../../../models/school_model.dart';
import '../controllers/school_info_controller.dart';

/// The School Information view and edit screen for School Administrators.
class SchoolInfoScreen extends StatefulWidget {
  final SchoolInfoController controller;
  final String? schoolId;

  const SchoolInfoScreen({super.key, required this.controller, this.schoolId});

  @override
  State<SchoolInfoScreen> createState() => _SchoolInfoScreenState();
}

class _SchoolInfoScreenState extends State<SchoolInfoScreen> {
  bool _isEditing = false;

  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  String? _phoneError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();

    if (!widget.controller.state.isReady) {
      widget.controller.load(schoolId: widget.schoolId);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startEditing(SchoolModel school) {
    setState(() {
      _isEditing = true;
      _phoneError = null;
      _emailError = null;
      _addressController.text = school.address ?? '';
      _phoneController.text = school.contactNumber ?? '';
      _emailController.text = school.email ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _phoneError = null;
      _emailError = null;
    });
  }

  bool _validateForm() {
    String? phoneErr;
    String? emailErr;

    final phoneVal = _phoneController.text.trim();
    if (phoneVal.isNotEmpty) {
      final cleanPhone = phoneVal.replaceAll(RegExp(r'[\s\-()+]'), '');
      if (cleanPhone.length < 7 || int.tryParse(cleanPhone) == null) {
        phoneErr = 'Please enter a valid contact number (at least 7 digits)';
      }
    }

    final emailVal = _emailController.text.trim();
    if (emailVal.isNotEmpty) {
      final emailRegExp = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegExp.hasMatch(emailVal)) {
        emailErr = 'Please enter a valid email address';
      }
    }

    setState(() {
      _phoneError = phoneErr;
      _emailError = emailErr;
    });

    return phoneErr == null && emailErr == null;
  }

  Future<void> _submitForm(SchoolModel school) async {
    if (!_validateForm()) return;

    final success = await widget.controller.saveSchoolInfo(
      schoolId: school.schoolId,
      address: _addressController.text,
      contactNumber: _phoneController.text,
      email: _emailController.text,
    );

    if (mounted) {
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School details updated successfully.'),
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
          onRetry: () => widget.controller.load(schoolId: widget.schoolId),
          emptyTitle: 'School Not Found',
          builder: (context, school) => _buildBody(context, school),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, SchoolModel school) {
    return RefreshIndicator(
      onRefresh: () => widget.controller.load(schoolId: widget.schoolId),
      child: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _headerCard(school),
          const SizedBox(height: AppSpacing.lg),
          if (_isEditing) _buildEditForm(school) else _buildViewDetails(school),
        ],
      ),
    );
  }

  Widget _headerCard(SchoolModel school) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(school.schoolName, style: AppTextStyles.cardTitle),
              ),
              const StatusBadge(label: 'Active', type: StatusType.success),
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
        ],
      ),
    );
  }

  Widget _buildViewDetails(SchoolModel school) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact & Location Details', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        AppListTile(
          icon: Icons.map_outlined,
          title: 'Address',
          subtitle: school.address ?? 'Not provided',
          showChevron: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListTile(
          icon: Icons.phone_outlined,
          title: 'Contact Number',
          subtitle: school.contactNumber ?? 'Not provided',
          showChevron: false,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppListTile(
          icon: Icons.email_outlined,
          title: 'Email Address',
          subtitle: school.email ?? 'Not provided',
          showChevron: false,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Edit Information',
          icon: Icons.edit_outlined,
          onPressed: () => _startEditing(school),
        ),
      ],
    );
  }

  Widget _buildEditForm(SchoolModel school) {
    final isSaving = widget.controller.isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit School Details', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _addressController,
          label: 'Address',
          hint: 'Enter school street address',
          prefixIcon: Icons.map_outlined,
          enabled: !isSaving,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _phoneController,
          label: 'Contact Number',
          hint: 'Enter official phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          errorText: _phoneError,
          enabled: !isSaving,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'Enter school contact email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          enabled: !isSaving,
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Cancel',
                isOutlined: true,
                onPressed: isSaving ? null : _cancelEditing,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: 'Save Changes',
                isLoading: isSaving,
                onPressed: isSaving ? null : () => _submitForm(school),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

enum StatusType { success, warning, error, info }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusType.info,
  });

  @override
  Widget build(BuildContext context) {
    final Color fgColor;
    final Color bgColor;

    switch (type) {
      case StatusType.success:
        fgColor = AppColors.success;
        bgColor = AppColors.successBg;
        break;
      case StatusType.warning:
        fgColor = AppColors.warning;
        bgColor = AppColors.warningBg;
        break;
      case StatusType.error:
        fgColor = AppColors.error;
        bgColor = AppColors.errorBg;
        break;
      case StatusType.info:
        fgColor = AppColors.info;
        bgColor = AppColors.infoBg;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderCircular,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

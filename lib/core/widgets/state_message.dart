import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_buttons.dart';

/// The four whole-screen states a screen can be in instead of showing
/// content.
enum StateMessageType {
  /// Still fetching. Shows a spinner.
  loading,

  /// Fetch worked, but there is nothing to show.
  empty,

  /// Something went wrong. Normally paired with a Retry button.
  error,

  /// The signed-in user is not allowed to see this screen.
  unauthorized,
}

/// One widget covering loading, empty, error and unauthorized, so every
/// screen handles these the same way.
///
/// Each variant has a sensible default icon, title and message, and any
/// of them can be overridden.
///
/// Example:
/// ```dart
/// // While waiting
/// StateMessage(type: StateMessageType.loading)
///
/// // Nothing found
/// StateMessage(
///   type: StateMessageType.empty,
///   title: 'No students yet',
///   message: 'Add your first student to get started.',
/// )
///
/// // Failed, with a retry
/// StateMessage(
///   type: StateMessageType.error,
///   onRetry: () {},
/// )
/// ```
class StateMessage extends StatelessWidget {
  /// Which of the four states to show.
  final StateMessageType type;

  /// Optional replacement for the default heading.
  final String? title;

  /// Optional replacement for the default explanation line.
  final String? message;

  /// Optional replacement for the default icon.
  final IconData? icon;

  /// Shows a Retry button when given. Ignored while loading, since
  /// there is nothing to retry yet.
  final VoidCallback? onRetry;

  const StateMessage({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.icon,
    this.onRetry,
  });

  /// Default heading per state.
  String get _defaultTitle {
    switch (type) {
      case StateMessageType.loading:
        return 'Loading';
      case StateMessageType.empty:
        return 'Nothing here yet';
      case StateMessageType.error:
        return 'Something went wrong';
      case StateMessageType.unauthorized:
        return 'Access denied';
    }
  }

  /// Default explanation per state.
  String get _defaultMessage {
    switch (type) {
      case StateMessageType.loading:
        return 'Please wait a moment.';
      case StateMessageType.empty:
        return 'There is nothing to show here right now.';
      case StateMessageType.error:
        return 'We could not load this. Check your connection and try again.';
      case StateMessageType.unauthorized:
        return 'You do not have permission to view this page.';
    }
  }

  /// Default icon per state. Loading has none; it shows a spinner.
  IconData get _defaultIcon {
    switch (type) {
      case StateMessageType.loading:
        return Icons.hourglass_empty;
      case StateMessageType.empty:
        return Icons.inbox_outlined;
      case StateMessageType.error:
        return Icons.error_outline;
      case StateMessageType.unauthorized:
        return Icons.lock_outline;
    }
  }

  /// Icon colour per state.
  Color get _iconColor {
    switch (type) {
      case StateMessageType.loading:
        return AppColors.primary;
      case StateMessageType.empty:
        return AppColors.textMuted;
      case StateMessageType.error:
        return AppColors.danger;
      case StateMessageType.unauthorized:
        return AppColors.warning;
    }
  }

  /// Pale circle behind the icon, matching [_iconColor].
  Color get _iconBackground {
    switch (type) {
      case StateMessageType.loading:
        return AppColors.infoSoft;
      case StateMessageType.empty:
        return AppColors.divider;
      case StateMessageType.error:
        return AppColors.dangerSoft;
      case StateMessageType.unauthorized:
        return AppColors.warningSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = type == StateMessageType.loading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadge(isLoading),
            const SizedBox(height: AppSpacing.md),
            Text(
              title ?? _defaultTitle,
              style: AppTextStyles.sectionHeading,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? _defaultMessage,
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            // No point offering Retry while a load is already running.
            if (onRetry != null && !isLoading) ...[
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The round badge at the top: a spinner while loading, otherwise a
  /// large icon on a pale circle.
  Widget _buildBadge(bool isLoading) {
    if (isLoading) {
      return const SizedBox(
        width: AppSizes.iconXl,
        height: AppSizes.iconXl,
        child: Center(
          child: SizedBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.spinnerStroke,
            ),
          ),
        ),
      );
    }

    return Container(
      width: AppSizes.iconXl + AppSpacing.md,
      height: AppSizes.iconXl + AppSpacing.md,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _iconBackground, shape: BoxShape.circle),
      child: Icon(
        icon ?? _defaultIcon,
        size: AppSizes.iconXl / 2,
        color: _iconColor,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// The two app bar styles used in the Figma file.
///
/// Both are white with a thin bottom border and no shadow.
///
/// Use the named constructors rather than the default one:
///
/// ```dart
/// // Big left-aligned title. Used on top-level tab screens.
/// AppScreenBar.large(title: 'Dashboard')
///
/// // Back chevron with a centered title. Used on pushed screens.
/// AppScreenBar.back(title: 'Student Details', onBack: () {})
/// ```
class AppScreenBar extends StatelessWidget implements PreferredSizeWidget {
  /// Text shown in the bar.
  final String title;

  /// Whether the title is centered (back style) or left-aligned and
  /// larger (large style).
  final bool centered;

  /// Whether to draw the back chevron on the left.
  final bool showBack;

  /// What the back chevron does. Defaults to popping the current route.
  final VoidCallback? onBack;

  /// Optional buttons on the right, e.g. a search or filter icon.
  final List<Widget>? actions;

  /// Optional second line under the title, used by the large style.
  final String? subtitle;

  const AppScreenBar({
    super.key,
    required this.title,
    this.centered = false,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.subtitle,
  });

  /// Back chevron on the left, title centered. For a pushed screen.
  const AppScreenBar.back({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
  }) : centered = true,
       showBack = true,
       subtitle = null;

  /// Large left-aligned title, no back button. For a tab root screen.
  const AppScreenBar.large({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  }) : centered = false,
       showBack = false,
       onBack = null;

  /// Height of the bar itself, without the border line.
  /// A taller bar is needed when there is a subtitle under the title.
  double get _toolbarHeight =>
      subtitle == null ? kToolbarHeight : kToolbarHeight + 20;

  /// Total height Flutter should reserve: the bar plus the 1px border.
  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + AppSizes.borderWidth);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centered,
      toolbarHeight: _toolbarHeight,
      // Flutter adds a back button on its own; this keeps full control.
      automaticallyImplyLeading: false,
      titleSpacing: showBack ? 0 : AppSpacing.md,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.chevron_left, size: AppSizes.iconLg),
              color: AppColors.textPrimary,
              tooltip: 'Back',
              onPressed: onBack ?? () => Navigator.maybePop(context),
            )
          : null,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            // The centered style is a smaller heading; the large style
            // is the big screen title.
            style: centered
                ? AppTextStyles.cardTitle
                : AppTextStyles.screenTitle,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs / 2),
            Text(
              subtitle!,
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: actions,
      // The thin grey line under the bar.
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(AppSizes.borderWidth),
        child: Divider(height: AppSizes.borderWidth),
      ),
    );
  }
}

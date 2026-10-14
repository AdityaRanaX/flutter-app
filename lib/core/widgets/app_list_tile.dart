import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';
import 'app_icon_tile.dart';

/// One row in a list: a coloured icon tile, a title, an optional
/// subtitle, and a chevron on the right.
///
/// This is the row used for schools, students, exams, settings and menu
/// items throughout the Figma file.
///
/// Example:
/// ```dart
/// AppListTile(
///   icon: Icons.school_outlined,
///   iconColor: AppColors.info,
///   iconBackground: AppColors.infoSoft,
///   title: 'Greenwood High',
///   subtitle: '412 students',
///   onTap: () {},
/// )
/// ```
class AppListTile extends StatelessWidget {
  /// Icon drawn in the coloured tile on the left.
  final IconData icon;

  /// Colour of that icon.
  final Color iconColor;

  /// Pale colour behind that icon.
  final Color iconBackground;

  /// Main line of text.
  final String title;

  /// Optional smaller grey line under the title.
  final String? subtitle;

  /// Optional widget on the right instead of the chevron, e.g. a
  /// [StatusChip] or a [Switch].
  final Widget? trailing;

  /// Whether to show the chevron. Ignored when [trailing] is given.
  final bool showChevron;

  /// What happens on tap. Null makes the row non-tappable.
  final VoidCallback? onTap;

  /// Whether to wrap the row in its own white [AppCard].
  ///
  /// Use `true` for standalone rows, and `false` when stacking several
  /// rows inside one shared card.
  final bool wrapInCard;

  const AppListTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.infoSoft,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.wrapInCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        AppIconTile(icon: icon, color: iconColor, background: iconBackground),
        const SizedBox(width: AppSpacing.ms),
        // Expanded lets the text take the leftover width and wrap or
        // ellipsis instead of overflowing the row.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySecondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ] else if (showChevron) ...[
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textMuted,
            size: AppSizes.iconMd,
          ),
        ],
      ],
    );

    if (wrapInCard) return AppCard(onTap: onTap, child: row);

    // Not in a card: still make it tappable, with its own padding.
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
        child: row,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The white rounded box with a thin border that holds almost every
/// piece of content in EduLens.
///
/// The colour, radius and border come from `cardTheme` in [AppTheme],
/// so this widget only adds padding and an optional tap.
///
/// Example:
/// ```dart
/// AppCard(
///   onTap: () {},
///   child: const Text('Anything'),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// What goes inside the card.
  final Widget child;

  /// Inner padding. Defaults to 16 on all sides.
  final EdgeInsetsGeometry? padding;

  /// If given, the whole card becomes tappable with a ripple.
  final VoidCallback? onTap;

  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? AppSpacing.paddingCard,
      child: child,
    );

    return Card(
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              borderRadius: AppRadius.borderMd,
              child: content,
            ),
    );
  }
}

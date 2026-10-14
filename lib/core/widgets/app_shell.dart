import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// One tab in the bottom navigation bar.
///
/// Just a label and an icon. It holds no role information and no
/// navigation logic, so the same class works for every role.
class AppNavItem {
  /// Text under the icon, e.g. 'Home'.
  final String label;

  /// Icon shown when the tab is NOT selected.
  final IconData icon;

  /// Icon shown when the tab IS selected. Defaults to [icon].
  ///
  /// The usual pattern is an outlined icon for [icon] and the filled
  /// version here, e.g. `Icons.home_outlined` and `Icons.home`.
  final IconData? activeIcon;

  const AppNavItem({required this.label, required this.icon, this.activeIcon});
}

/// The frame every logged-in screen sits inside: a page background, a
/// body, and a bottom navigation bar.
///
/// It knows nothing about roles. Whoever uses it passes the tabs it
/// should show, which tab is selected, and what to do on a tap. That is
/// why the same shell can serve all four roles:
///
/// - District:     Home / Schools / Exams / Profile
/// - School Admin: Students / School / Profile
/// - Teacher:      Home / Attendance / Exams / Profile
/// - Student:      Home / Exams / Profile
///
/// Example:
/// ```dart
/// AppShell(
///   items: const [
///     AppNavItem(label: 'Home', icon: Icons.home_outlined,
///         activeIcon: Icons.home),
///     AppNavItem(label: 'Profile', icon: Icons.person_outline,
///         activeIcon: Icons.person),
///   ],
///   currentIndex: 0,
///   onItemSelected: (index) {},
///   body: const Text('Page content'),
/// )
/// ```
class AppShell extends StatelessWidget {
  /// The tabs to show. Needs at least two for a bottom bar to appear.
  final List<AppNavItem> items;

  /// Index of the selected tab, counting from 0.
  final int currentIndex;

  /// Called with the tapped index. The caller decides what happens;
  /// the shell never changes screens by itself.
  final ValueChanged<int> onItemSelected;

  /// The page content.
  final Widget body;

  /// Optional app bar, normally an `AppScreenBar`.
  final PreferredSizeWidget? appBar;

  /// Optional floating action button.
  final Widget? floatingActionButton;

  /// Whether to add the standard 16px padding around [body].
  /// Turn it off for a full-width list that supplies its own padding.
  final bool padBody;

  const AppShell({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.padBody = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: padBody
            ? Padding(padding: AppSpacing.paddingScreen, child: body)
            : body,
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget? _buildBottomBar() {
    // A BottomNavigationBar needs two or more items. With fewer, there
    // is nothing meaningful to show, so the bar is left out entirely.
    if (items.length < 2) return null;

    return Container(
      // The thin line that separates the white bar from the page.
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          // Clamped so an out-of-range index cannot crash the bar.
          currentIndex: currentIndex.clamp(0, items.length - 1),
          onTap: onItemSelected,
          items: items
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon ?? item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

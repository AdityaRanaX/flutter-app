import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_screen_bar.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/placeholder_destination.dart';
import '../../../services/firestore_service.dart';

/// The District Administrator navigation container.
///
/// Supplies the District tab set to the shared [AppShell] and
/// handles testing Firestore actions for authenticated District Admins.
class DistrictShell extends StatefulWidget {
  const DistrictShell({super.key});

  @override
  State<DistrictShell> createState() => _DistrictShellState();
}

class _DistrictShellState extends State<DistrictShell> {
  int _currentIndex = 0;
  bool _isTestingFirestore = false;

  static const List<AppNavItem> _tabs = [
    AppNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    AppNavItem(
      label: 'Schools',
      icon: Icons.apartment_outlined,
      activeIcon: Icons.apartment,
    ),
    AppNavItem(
      label: 'Exams',
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment,
    ),
    AppNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  static const List<Widget> _destinations = [
    PlaceholderDestination(title: 'District Home', icon: Icons.home_outlined),
    PlaceholderDestination(title: 'Schools', icon: Icons.apartment_outlined),
    PlaceholderDestination(title: 'Exams', icon: Icons.assignment_outlined),
    PlaceholderDestination(title: 'Profile', icon: Icons.person_outline),
  ];

  Future<void> _handleTestFirestore() async {
    if (_isTestingFirestore) return;

    setState(() {
      _isTestingFirestore = true;
    });

    try {
      await FirestoreService().addDemoSchool();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firestore write success: Demo School added!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firestore write failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingFirestore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      items: _tabs,
      currentIndex: _currentIndex,
      onItemSelected: (index) => setState(() => _currentIndex = index),
      appBar: AppScreenBar.large(
        title: _tabs[_currentIndex].label,
        actions: [
          IconButton(
            icon: _isTestingFirestore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Test Firestore',
            onPressed: _isTestingFirestore ? null : _handleTestFirestore,
          ),
        ],
      ),
      body: _destinations[_currentIndex],
    );
  }
}

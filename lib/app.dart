import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'routes/role_router.dart';

class EduLensApp extends StatelessWidget {
  const EduLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RoleRouter(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}

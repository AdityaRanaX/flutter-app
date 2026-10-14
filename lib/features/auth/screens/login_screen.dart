import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../repositories/firestore_user_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_bootstrap_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;
  final UserRepository? userRepository;

  const LoginScreen({
    super.key,
    this.authService,
    this.userRepository,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _authService;
  late final UserRepository _userRepository;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _userRepository = widget.userRepository ?? FirestoreUserRepository();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    debugPrint('[LoginScreen] Starting login flow for email: $email');

    try {
      final credential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final user = credential.user ?? _authService.currentUser;
      if (user == null) {
        throw const AuthException('Authentication succeeded but user session is null.');
      }

      debugPrint('[LoginScreen] Auth successful. User UID: ${user.uid}');

      // Validate user profile and role in Firestore
      final bootstrapService = UserBootstrapService(
        authService: _authService,
        userRepository: _userRepository,
      );

      final bootstrapState = await bootstrapService.bootstrapUser(user);
      debugPrint('[LoginScreen] Profile lookup status: ${bootstrapState.status}');

      if (!mounted) return;

      if (bootstrapState.status == UserBootstrapStatus.profileNotFound) {
        setState(() {
          _errorMessage =
              'No user profile document found at users/${user.uid}. Please check Firestore configuration.';
        });
        return;
      }

      if (bootstrapState.status == UserBootstrapStatus.invalidProfile) {
        setState(() {
          _errorMessage =
              'User profile has an invalid or unassigned role. Please contact support.';
        });
        return;
      }

      if (bootstrapState.status == UserBootstrapStatus.error) {
        setState(() {
          _errorMessage =
              bootstrapState.errorMessage ?? 'Failed to load user profile.';
        });
        return;
      }

      if (bootstrapState.status == UserBootstrapStatus.profileFound) {
        final role = bootstrapState.userModel?.role;
        final route = AppRoutes.getDashboardRouteForRole(role);

        debugPrint('[LoginScreen] Role "$role" mapped to route: $route');

        if (route == null) {
          setState(() {
            _errorMessage =
                'Your user profile role ("$role") is unauthorized or unrecognized.';
          });
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login successful! Welcome, ${bootstrapState.userModel?.name ?? 'User'}'),
            backgroundColor: AppColors.secondary,
          ),
        );

        // Perform navigation to the role dashboard
        Navigator.pushReplacementNamed(context, route);
      }
    } on AuthException catch (e) {
      debugPrint('[LoginScreen] Auth error: ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('[LoginScreen] Unexpected login error: $e');
      setState(() {
        _errorMessage = 'An unexpected error occurred during login. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingScreen,
            child: AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Branding Header
                    Center(
                      child: Container(
                        padding: AppSpacing.paddingSm,
                        decoration: const BoxDecoration(
                          color: AppColors.infoBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'EduLens',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'District School Management System',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Error Message Display
                    if (_errorMessage != null) ...[
                      Container(
                        padding: AppSpacing.paddingSm,
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Email Field
                    AppTextField(
                      label: 'Email Address',
                      hint: 'admin@edulens.org',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Password Field
                    AppTextField(
                      label: 'Password',
                      hint: '••••••••',
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock_outline,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Remember Me & Forgot Password Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Remember Me',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.forgotPassword);
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Sign In Button
                    AppButton(
                      label: 'Sign In',
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Divider
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Google Sign-In Button (Disabled per PRD UX guidelines)
                    AppButton(
                      label: 'Continue with Google',
                      isOutlined: true,
                      icon: Icons.g_mobiledata,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Google Sign-In is disabled.'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

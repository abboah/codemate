import 'dart:async';
import 'dart:developer';

import 'package:codemate/auth/login_page.dart';
import 'package:codemate/auth/services/auth_service.dart';
import 'package:codemate/home/homepage.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:codemate/themes/dark_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late AnimationController _floatingController;
  late AnimationController _pulseController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _pulseAnimation;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _showNameError = false;
  bool _showEmailError = false;
  bool _showPasswordError = false;

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _cardSlideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.elasticOut),
    );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_backgroundController);

    _floatingAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start entrance animation
    Future.delayed(const Duration(milliseconds: 500), () {
      _cardController.forward();
    });
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String description,
    TextTheme textTheme,
  ) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_floatingAnimation.value * 0.2, 0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    _floatingController.dispose();
    _pulseController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    final authService = ref.read(authServiceProvider);

    // 1. Form validation with haptic feedback
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.selectionClick();
      return;
    }

    // 2. Terms check with improved snackbar
    if (!_agreeToTerms) {
      HapticFeedback.heavyImpact(); // Strong feedback for important miss
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final email = _emailController.text.trim();
      final password = _confirmPasswordController.text;

      // 3. Input validation
      if (password.length < 8) {
        throw 'Password must be at least 8 characters';
      }

      // 4. Secure signup process
      await authService.signUpWithEmailAndPassword(email, password);

      // 5. Post-signup actions before navigation
      log("SignUp Success: $email");
      // await _sendWelcomeEmail(email);

      // 6. Safe navigation with route clearing
      if (!mounted) return;

      // 7. Post-navigation feedback
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      // 8. Comprehensive error handling
      log("SignUp Error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', ''), // Clean error message
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );

      unawaited(HapticFeedback.vibrate());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = Theme.of(context).extension<DarkGradientColors>()!;
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,

                    colors: [
                      Color.lerp(
                        gradientColors.black,
                        gradientColors.black,
                        // gradientColors.dark1,
                        (math.sin(_backgroundAnimation.value) + 1) / 2,
                      )!,
                      Color.lerp(
                        gradientColors.black,
                        gradientColors.black,
                        // gradientColors.dark1,
                        // gradientColors.dark2,
                        (math.cos(_backgroundAnimation.value) + 1) / 2,
                      )!,
                      Color.lerp(
                        //gradientColors.dark2,
                        gradientColors.black,
                        gradientColors.black,
                        (math.sin(_backgroundAnimation.value + math.pi) + 1) /
                            2,
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // Floating geometric shapes
          ...List.generate(6, (index) {
            return AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Positioned(
                  left: size.width * (0.1 + index * 0.15),
                  top:
                      size.height * (0.1 + index * 0.12) +
                      _floatingAnimation.value * (index % 2 == 0 ? 1 : -1),
                  child: Transform.rotate(
                    angle: _backgroundAnimation.value + index,
                    child: Container(
                      width: 40 + index * 10,
                      height: 40 + index * 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main content - Responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              if (isDesktop) {
                // Desktop: Split screen layout
                return Row(
                  children: [
                    // Left side - Hero section with branding
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(50),
                        child: AnimatedBuilder(
                          animation: _floatingAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_floatingAnimation.value * 0.5, 0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 30,
                                          offset: const Offset(0, 15),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.flutter_dash,
                                      size: 60,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  Text(
                                    "Join the Future\nwith Robin",
                                    style: textTheme.displayLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.1,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    "Create your account and unlock the power of next-generation productivity tools designed for ambitious professionals.",
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w300,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  // Feature highlights
                                  Column(
                                    children: [
                                      _buildFeatureItem(
                                        Icons.person_add_rounded,
                                        "Easy Setup",
                                        "Get started in under 2 minutes with our streamlined onboarding",
                                        textTheme,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildFeatureItem(
                                        Icons.workspace_premium_rounded,
                                        "Premium Features",
                                        "Access advanced tools and integrations from day one",
                                        textTheme,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildFeatureItem(
                                        Icons.groups_rounded,
                                        "Join Community",
                                        "Connect with thousands of professionals worldwide",
                                        textTheme,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Right side - Login form
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _cardController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _cardSlideAnimation.value),
                                child: Opacity(
                                  opacity: _cardFadeAnimation.value,
                                  child: Container(
                                    width: math.min(
                                      constraints.maxWidth * 0.4,
                                      480,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 780,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 15,
                                          sigmaY: 15,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 30,
                                                offset: const Offset(0, 15),
                                              ),
                                            ],
                                          ),
                                          child: _buildSignUpForm(
                                            textTheme,
                                            isDesktop: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile: Full screen login
                return SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: AnimatedBuilder(
                        animation: _cardController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _cardSlideAnimation.value),
                            child: Opacity(
                              opacity: _cardFadeAnimation.value,
                              child: Container(
                                width: math.min(size.width * 0.95, 400),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 15,
                                      sigmaY: 15,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          ),
                                        ],
                                      ),
                                      child: _buildSignUpForm(
                                        textTheme,
                                        isDesktop: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(TextTheme textTheme, {required bool isDesktop}) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 40.0 : 30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo and title (only show on mobile, desktop has it on the left)
            if (!isDesktop) ...[
              _buildHeader(textTheme),
              const SizedBox(height: 30),
            ] else ...[
              // Desktop header - more compact
              Text(
                "Create Account",
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Join us today! Create your account to get started",
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
            ],

            // Name field
            _buildNameField(),
            const SizedBox(height: 18),

            // Email field
            _buildEmailField(),
            const SizedBox(height: 18),

            // Password field
            _buildPasswordField(),

            const SizedBox(height: 8),
            _buildPasswordStrengthIndicator(Theme.of(context).colorScheme),
            const SizedBox(height: 18),

            // Confirm Password field
            _buildConfirmPasswordField(),
            const SizedBox(height: 18),

            // Terms and conditions
            _buildTermsCheckbox(textTheme),
            SizedBox(height: isDesktop ? 18 : 28),

            // Sign up button
            _buildSignUpButton(textTheme),
            SizedBox(height: isDesktop ? 14 : 18),

            // Google sign up
            _buildGoogleSignUpButton(textTheme),
            SizedBox(height: isDesktop ? 18 : 23),

            // Sign in link
            _buildSignInLink(textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(TextTheme textTheme) {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnimation.value * 0.3),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flutter_dash,
                  size: 40,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Create Your Account",
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Join thousands of professionals today",
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNameField() {
    final color = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: 0.95 + (animation * 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Full Name",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                prefixIcon: Icon(
                  Icons.person_outlined,
                  color: Colors.white.withOpacity(0.8),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: color.error, width: 2),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your full name';
                }
                if (value!.trim().split(' ').length < 2) {
                  return 'Please enter your first and last name';
                }
                return null;
              },
              onChanged: (value) {
                if (_showNameError) {
                  setState(() {
                    _showNameError = false;
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailField() {
    final color = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: 0.95 + (animation * 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Email",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: Colors.white.withOpacity(0.8),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: color.error, width: 2),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value!)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
              onChanged: (value) {
                if (_showEmailError) {
                  setState(() {
                    _showEmailError = false;
                  });
                }
              },
            ),
          ),
        );
      },
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('weak password')) {
      return 'Password is too weak. Please choose a stronger password';
    } else if (error.contains('same password')) {
      return 'New password must be different from your current password';
    }
    return 'Failed to update password. Please try again';
  }

  String? _validatePassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please enter a password';
    }
    if (value!.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  int _getPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'\d').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    return strength;
  }

  Color _getStrengthColor(int strength, ColorScheme colorScheme) {
    switch (strength) {
      case 0:
      case 1:
        return colorScheme.error;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
      case 5:
        return Colors.green;
      default:
        return colorScheme.outline;
    }
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
      case 5:
        return 'Strong';
      default:
        return '';
    }
  }

  Widget _buildPasswordStrengthIndicator(ColorScheme colorScheme) {
    final password = _passwordController.text;
    final strength = _getPasswordStrength(password);
    final strengthColor = _getStrengthColor(strength, colorScheme);
    final strengthText = _getStrengthText(strength);

    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength / 5,
                backgroundColor: colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strengthText,
              style: TextStyle(
                color: strengthColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Password should contain uppercase, lowercase, numbers, and symbols",
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final color = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: 0.95 + (animation * 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              onChanged: (_) {
                setState(() {}); // Rebuild for strength indicator
              },
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Password",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                prefixIcon: Icon(
                  Icons.lock_outlined,
                  color: Colors.white.withOpacity(0.8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: color.error, width: 2),
                ),
              ),
              validator: _validatePassword,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    final color = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animation, child) {
        return Transform.scale(
          scale: 0.95 + (animation * 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Confirm Password",
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.white.withOpacity(0.8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: color.error, width: 2),
                ),
              ),
              validator: _validateConfirmPassword,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTermsCheckbox(TextTheme textTheme) {
    final color = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (value) {
              setState(() {
                _agreeToTerms = value ?? false;
              });
              HapticFeedback.selectionClick();
            },
            activeColor: Colors.white,
            checkColor: color.surface,
            side: BorderSide(color: Colors.white.withOpacity(0.8)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(),
            child: RichText(
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "I agree to the "),
                  TextSpan(
                    text: "Terms and Conditions",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(text: " and "),
                  TextSpan(
                    text: "Privacy Policy",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(TextTheme textTheme) {
    final gradientColors = Theme.of(context).extension<DarkGradientColors>()!;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isLoading ? 1.0 : _pulseAnimation.value,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.lightBlue, Colors.blueAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue,
                  blurRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLoading ? null : _handleSignUp,
                child: Center(
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Sign Up",
                                style: textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper method for loading overlay
  OverlayEntry _showLoadingOverlay(BuildContext context) {
    final overlay = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              ModalBarrier(
                color: Colors.black.withOpacity(0.5),
                dismissible: false,
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Signing in with Google...'),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(overlay);
    return overlay;
  }

  Widget _buildGoogleSignUpButton(TextTheme textTheme) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: handleGoogleAuth,

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 35,
                decoration: const BoxDecoration(),
                child: Image.asset("images/google.png", fit: BoxFit.contain),
              ),
              const SizedBox(width: 10),
              Text(
                "Sign up with Google",
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void handleGoogleAuth() async {
    final authService = ref.read(authServiceProvider);
    HapticFeedback.selectionClick();

    OverlayEntry? overlay;

    try {
      overlay = _showLoadingOverlay(context);

      await authService.continueWithGoogle();

      overlay.remove();

      if (!mounted) return;

      // Success feedback
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      // Clean up loading on error
      overlay?.remove();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red[900],
        ),
      );
      unawaited(HapticFeedback.vibrate());
    }
  }

  Widget _buildSignInLink(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) {
                  return LoginPage();
                },
              ),
            );
          },
          child: Text(
            "Sign In",
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

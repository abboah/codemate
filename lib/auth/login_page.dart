import 'dart:async';
import 'dart:developer';

import 'package:codemate/auth/components/new_password.dart';
import 'package:codemate/auth/components/reset_password.dart';
import 'package:codemate/auth/services/auth_service.dart';
import 'package:codemate/auth/signup_page.dart';
import 'package:codemate/home/homepage.dart';
import 'package:codemate/layouts/dashboard_page.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:codemate/reload.dart';
import 'package:codemate/themes/dark_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  // Initialize Auth Service

  // Initialize Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _showEmailError = false;
  bool isForgotPasswordDialogVisible = false;
  bool isNewPasswordDialogVisible = false;

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

    _setupAuthListener();
    // _checkInitialState();
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    //Auth Service
    final authService = ref.read(authServiceProvider);

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.selectionClick();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      await authService.loginWithEmailAndPassword(email, password);

      log("Login Success: $email");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RobinDashboardMinimal()),
      );
      unawaited(HapticFeedback.lightImpact());
      if (!mounted) return;
    } catch (e) {
      log("Login Error: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade900,
          content: const Text('Login failed. Check credentials'),
          duration: const Duration(seconds: 2),
        ),
      );

      unawaited(HapticFeedback.vibrate());
      reloadPage();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery &&
          data.session != null) {
        setState(() {
          isForgotPasswordDialogVisible = false; // Hide forgot password dialog
          isNewPasswordDialogVisible = true; // Show new password dialog
        });
      }
    });
  }

  // Future<void> _checkInitialState() async {
  //   // Check if user came from password reset link
  //   final session = Supabase.instance.client.auth.currentSession;
  //   if (session != null) {
  //     // This might be a password recovery session
  //     setState(() {
  //       isNewPasswordDialogVisible = true;
  //     });
  //   }
  // }

  Widget blurBackground() {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Container(
        color: Colors.black.withOpacity(0.3),
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    final gradientColors = Theme.of(context).extension<DarkGradientColors>()!;

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
                                    "Welcome to\nRobin",
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
                                    "Experience the future of productivity with our next-generation platform designed for modern professionals.",
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
                                        Icons.security_rounded,
                                        "Bank-level Security",
                                        "Your data is protected with enterprise-grade encryption",
                                        textTheme,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildFeatureItem(
                                        Icons.speed_rounded,
                                        "Lightning Fast",
                                        "Optimized performance for seamless user experience",
                                        textTheme,
                                      ),
                                      const SizedBox(height: 20),
                                      _buildFeatureItem(
                                        Icons.cloud_sync_rounded,
                                        "Cloud Sync",
                                        "Access your work from anywhere, anytime",
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
                                      maxHeight: 700,
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
                                          child: _buildLoginForm(
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
                                      child: _buildLoginForm(
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
          if (isForgotPasswordDialogVisible) ...[
            blurBackground(),
            Center(
              child: ForgotPasswordDialog(
                onClose:
                    () => setState(() => isForgotPasswordDialogVisible = false),
              ),
            ),
          ],
          // New password dialog
          if (isNewPasswordDialogVisible) ...[
            blurBackground(),
            // Container(
            //   color: Colors.black.withOpacity(0.5),
            //   child: const SizedBox.expand(),
            // ),
            NewPasswordDialog(
              onClose: () => setState(() => isNewPasswordDialogVisible = false),
              onSuccess: () {
                setState(() => isNewPasswordDialogVisible = false);
                // Handle success - maybe show a success message or navigate
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginForm(TextTheme textTheme, {required bool isDesktop}) {
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
              const SizedBox(height: 40),
            ] else ...[
              // Desktop header - more compact
              Text(
                "Sign In",
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Welcome back! Please sign in to continue",
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],

            // Email field
            _buildEmailField(),
            const SizedBox(height: 24),

            // Password field
            _buildPasswordField(),
            const SizedBox(height: 24),

            // Remember me and forgot password
            _buildRememberForgotRow(textTheme),
            SizedBox(height: isDesktop ? 30 : 40),

            // Login button
            _buildLoginButton(textTheme),
            SizedBox(height: isDesktop ? 16 : 20),

            // Google sign in
            _buildGoogleButton(textTheme),
            SizedBox(height: isDesktop ? 20 : 30),

            // Sign up link
            _buildSignUpLink(textTheme),
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
                "Robin",
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
                "Welcome back to the future",
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
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please enter your password';
                }
                if (value!.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildRememberForgotRow(TextTheme textTheme) {
    final color = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                  HapticFeedback.selectionClick();
                },
                activeColor: Colors.white,
                checkColor: color.surface,
                side: BorderSide(color: Colors.white.withOpacity(0.8)),
              ),
            ),
            Text(
              "Remember Me",
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => isForgotPasswordDialogVisible = true);
          },
          child: Text(
            "Forgot Password?",
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(TextTheme textTheme) {
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
                onTap: _isLoading ? null : _handleLogin,
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
                                "Sign In",
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
  } // Helper method for loading overlay

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

  Widget _buildGoogleButton(TextTheme textTheme) {
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
              const SizedBox(width: 12),
              Text(
                "Continue with Google",
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

  Widget _buildSignUpLink(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
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
                  return SignUpPage();
                },
              ),
            );
          },
          child: Text(
            "Sign Up",
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

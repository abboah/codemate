import 'dart:math' as math;
import 'dart:ui';
import 'package:codemate/themes/dark_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordDialog extends StatefulWidget {
  final VoidCallback onClose;
  const ForgotPasswordDialog({super.key, required this.onClose});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  String? _statusMessage;
  bool _isSuccess = false;
  late AnimationController _cardController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _cardSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start the entrance animation
    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'your-app://reset-password', // Replace with your deep link
      );

      setState(() {
        _isSending = false;
        _isSuccess = true;
        _statusMessage = 'Password reset link sent to your email!';
      });

      // Auto close after 3 seconds on success
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) widget.onClose();
      });
    } catch (e) {
      setState(() {
        _isSending = false;
        _isSuccess = false;
        _statusMessage = _getErrorMessage(e.toString());
      });
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Invalid email')) {
      return 'Please enter a valid email address';
    } else if (error.contains('not found')) {
      return 'No account found with this email address';
    } else if (error.contains('rate limit')) {
      return 'Too many requests. Please try again later';
    }
    return 'Something went wrong. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final gradientColors = theme.extension<DarkGradientColors>()!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _cardController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _cardSlideAnimation.value),
              child: Opacity(
                opacity: _cardFadeAnimation.value,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 480,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,

                            colors: [
                              gradientColors.black,
                              gradientColors.dark1,
                              gradientColors.dark2,
                            ],
                          ),
                          color: gradientColors.dark1,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildHeader(colorScheme),
                                const SizedBox(height: 32),
                                _buildEmailField(colorScheme),
                                const SizedBox(height: 24),
                                _buildActionButtons(colorScheme),
                                if (_statusMessage != null) ...[
                                  const SizedBox(height: 16),
                                  _buildStatusMessage(colorScheme),
                                ],
                              ],
                            ),
                          ),
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
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.onSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.lock_reset_outlined,
                color: colorScheme.surface,
                weight: 10,
                size: 24,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.close, color: colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Forgot Password?",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "No worries! Enter your account's email address and we'll send you a link to reset your password.",
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _sendResetLink(),
      decoration: InputDecoration(
        labelText: "Email",
        labelStyle: TextStyle(color: colorScheme.onSurface),
        hintText: "Enter your email",
        prefixIcon: Icon(Icons.email_outlined, color: colorScheme.onSurface),
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.onSurface),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.onSurface),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.onSurface, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Please enter your email address';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSending ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child:
                _isSending
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onSurface,
                        ),
                      ),
                    )
                    : const Text(
                      "Send Reset Link",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, size: 18, color: colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                "Back to Sign In",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // color:
        //     _isSuccess
        //         ? colorScheme.primaryContainer
        //         : colorScheme.errorContainer,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // color:
          //     _isSuccess
          //         ? colorScheme.primary.withOpacity(0.2)
          //         : colorScheme.error.withOpacity(0.2),
          color: Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_outline_outlined : Icons.error,
            color: _isSuccess ? colorScheme.onSurface : colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color:
                    _isSuccess
                        ? colorScheme.onSurface
                        : colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

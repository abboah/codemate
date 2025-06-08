import 'dart:ui';
import 'package:codemate/themes/dark_theme_extension.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewPasswordDialog extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onSuccess;
  const NewPasswordDialog({
    super.key,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<NewPasswordDialog>
    with TickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isUpdating = false;
  String? _statusMessage;
  bool _isSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
      _statusMessage = null;
    });

    final password = _passwordController.text;

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      setState(() {
        _isUpdating = false;
        _isSuccess = true;
        _statusMessage = 'Password updated successfully!';
      });

      // Auto close and trigger success callback after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          widget.onSuccess();
          widget.onClose();
        }
      });
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _isSuccess = false;
        _statusMessage = _getErrorMessage(e.toString());
      });
    }
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
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                                _buildPasswordField(colorScheme),
                                const SizedBox(height: 8),
                                _buildPasswordStrengthIndicator(colorScheme),
                                const SizedBox(height: 24),
                                _buildConfirmPasswordField(colorScheme),
                                const SizedBox(height: 32),
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
                Icons.security,
                color: colorScheme.surface,
                size: 24,
                weight: 10,
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
          "Create New Password",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Please create a strong password for your account. Make sure it's something you'll remember!",
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.next,
      onChanged: (_) => setState(() {}), // Rebuild for strength indicator
      decoration: InputDecoration(
        labelText: "New Password",
        labelStyle: TextStyle(color: colorScheme.onSurface),
        hintText: "Enter your new password",
        prefixIcon: Icon(Icons.lock_outline, color: colorScheme.onSurface),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: colorScheme.onSurface,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
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
      validator: _validatePassword,
    );
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

  Widget _buildConfirmPasswordField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _updatePassword(),
      decoration: InputDecoration(
        labelText: "Confirm Password",
        labelStyle: TextStyle(color: colorScheme.onSurface),
        hintText: "Confirm your new password",
        prefixIcon: Icon(Icons.lock_outline, color: colorScheme.onSurface),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: colorScheme.onSurface,
          ),
          onPressed:
              () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
        ),
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
      validator: _validateConfirmPassword,
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updatePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child:
                _isUpdating
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                    : const Text(
                      "Update Password",
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
          child: const Text(
            "Cancel",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
          //        : colorScheme.error.withOpacity(0.2),
          color: Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle : Icons.error,
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

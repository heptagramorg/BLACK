// lib/screens/verify_otp_reset_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For AuthException
import '../services/auth_service.dart';
import 'login_screen.dart'; // To navigate back to login

class VerifyOtpAndResetScreen extends StatefulWidget {
  final String email;

  const VerifyOtpAndResetScreen({Key? key, required this.email})
      : super(key: key);

  @override
  State<VerifyOtpAndResetScreen> createState() =>
      _VerifyOtpAndResetScreenState();
}

class _VerifyOtpAndResetScreenState extends State<VerifyOtpAndResetScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  void _showFeedback(String message,
      {bool isError = true, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 4)),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.verifyRecoveryOtpAndResetPassword(
        email: widget.email,
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (mounted) {
        _showFeedback(
            "Password reset successful! Please log in with your new password.",
            isError: false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _showFeedback(_errorMessage, isError: true);
    } catch (e) {
      _errorMessage = "An unexpected error occurred: ${e.toString()}";
      _showFeedback(_errorMessage, isError: true);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set New Password"),
        elevation: 0.5,
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset_rounded,
                  size: 60, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                "Create Your New Password",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "An OTP (One-Time Password / Token) has been sent to ${widget.email}. Enter it below.",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty && !_isLoading)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _otpController,
                decoration: _inputDecoration(
                    "OTP from Email", Icons.pin_outlined, theme),
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return "Please enter the OTP from your email.";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                decoration: _inputDecoration(
                    "New Password", Icons.lock_outline, theme,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isNewPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: theme.hintColor),
                      onPressed: () => setState(
                          () => _isNewPasswordVisible = !_isNewPasswordVisible),
                    )),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Please enter a new password.";
                  if (value.length < 6)
                    return "Password must be at least 6 characters.";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                // *** CORRECTED ICON HERE ***
                decoration: _inputDecoration(
                    "Confirm New Password",
                    Icons.lock_outline,
                    theme, // Changed from lock_check_outlined
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: theme.hintColor),
                      onPressed: () => setState(() =>
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible),
                    )),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Please confirm your new password.";
                  if (value != _newPasswordController.text)
                    return "Passwords do not match.";
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text("Set New Password",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, ThemeData theme,
      {Widget? suffixIcon}) {
    return InputDecoration(
        labelText: label,
        hintText: "Enter $label",
        prefixIcon: Icon(icon, color: theme.hintColor),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorStyle: TextStyle(color: theme.colorScheme.error));
  }
}

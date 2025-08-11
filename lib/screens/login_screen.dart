import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'user_selection_screen.dart';
import 'verify_otp_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;
  String errorMessage = '';
  bool needsEmailVerification = false;

  @override
  void initState() {
    super.initState();
    // The auth state listener in main.dart handles checking for an existing session on app start.
  }

  void _showFeedback(String message,
      {bool isError = true, Color? backgroundColor, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? (backgroundColor ?? Colors.red.shade600)
            : (backgroundColor ?? Colors.green.shade600),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      needsEmailVerification = false;
    });
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Please enter both email and password.';
        isLoading = false;
      });
      return;
    }
    try {
      final user = await _authService.signInWithEmail(
          emailController.text.trim(), passwordController.text.trim());
      if (!mounted) return;

      final userRole = await _authService.getUserRole(user.id);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => HomeScreen(
                    userId: user.id, userRole: userRole ?? 'Student')),
            (route) => false);
      }
    } on AuthException catch (e) {
      String messageToDisplay = e.message;
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        messageToDisplay = 'Invalid email or password. Please try again.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        messageToDisplay = 'Please verify your email before logging in.';
        setState(() => needsEmailVerification = true);
        _showResendVerificationDialog(emailController.text.trim());
      }
      setState(() {
        errorMessage = messageToDisplay;
      });
    } catch (e) {
      setState(() {
        errorMessage = "An unexpected error occurred: ${e.toString()}";
      });
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _resendVerificationEmail(String email) async {
    if (email.isEmpty) {
      _showFeedback("Please enter your email address first.", isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
      _showFeedback(
          "Verification email resent to $email. Please check your inbox.",
          isError: false);
    } on AuthException catch (e) {
      _showFeedback("Error resending verification email: ${e.message}",
          isError: true);
    } catch (e) {
      _showFeedback("An unexpected error occurred: ${e.toString()}",
          isError: true);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showResendVerificationDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Email Verification Required"),
        content: Text(
            "Your email address ($email) needs to be verified. Would you like us to resend the verification email?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resendVerificationEmail(email);
            },
            child: const Text("Resend Email"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        errorMessage =
            "Please enter your email address to receive a recovery OTP.";
      });
      return;
    }
    setState(() => isLoading = true);
    errorMessage = '';

    try {
      await _authService.sendPasswordRecoveryOtp(email);
      if (mounted) {
        _showFeedback(
            "An OTP will be sent to $email if an account exists. Check your inbox (and spam folder), then enter the OTP on the next screen.",
            isError: false,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withAlpha(204),
            duration: const Duration(seconds: 6));
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => VerifyOtpAndResetScreen(email: email)),
        );
      }
    } on AuthException {
      errorMessage =
          "Could not send OTP. Please check the email or try again later.";
    } catch (e) {
      errorMessage = "An unexpected error occurred. Please try again.";
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (provider != 'Google') {
      _showFeedback("$provider login coming soon!",
          isError: false, backgroundColor: Colors.blueAccent);
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        // Check if the user has a profile (i.e., they are an existing user)
        final userRole = await _authService.getUserRole(user.id);

        if (!mounted) return;

        if (userRole == null) {
          // New user, navigate to role selection
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => UserSelectionScreen(
                uid: user.id,
                name: user.userMetadata?['full_name'] ?? user.email ?? '',
                email: user.email!,
                profilePictureUrl: user.userMetadata?['picture'],
              ),
            ),
            (route) => false,
          );
        } else {
          // Existing user, navigate to home
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(userId: user.id, userRole: userRole),
            ),
            (route) => false,
          );
        }
      } else if (user == null) {
        // Handle case where sign-in was cancelled or failed silently
        setState(() {
          errorMessage = "Google sign-in was cancelled.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "Google sign-in failed. Please try again.";
        });
      }
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text("Login",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(height: 24),
                  if (errorMessage.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(top: 16, bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200)),
                      child: Text(
                        errorMessage,
                        style:
                            TextStyle(color: Colors.red.shade800, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (needsEmailVerification &&
                      errorMessage.contains('verify your email'))
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mark_email_unread_outlined,
                                  color: Colors.orange.shade800),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text("Email Verification Needed",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              "Please check your email inbox for a verification link.",
                              style: TextStyle(color: Colors.orange.shade800)),
                          TextButton(
                            onPressed: () => _resendVerificationEmail(
                                emailController.text.trim()),
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft),
                            child: const Text("Resend verification email",
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildTextField(
                      emailController, "Email", Icons.email_outlined, false),
                  _buildTextField(
                      passwordController, "Password", Icons.lock_outline, true,
                      trailing: _togglePassword()),
                  _buildForgotPassword(),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 24),
                  _buildSocialButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      IconData icon, bool obscure,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        obscureText: obscure ? !isPasswordVisible : false,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          suffixIcon: trailing,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(color: Colors.black),
        keyboardType: hint.toLowerCase() == "email"
            ? TextInputType.emailAddress
            : TextInputType.visiblePassword,
      ),
    );
  }

  Widget _togglePassword() {
    return IconButton(
      icon: Icon(
          isPasswordVisible
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: Colors.grey.shade600),
      onPressed: () {
        setState(() {
          isPasswordVisible = !isPasswordVisible;
        });
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: isLoading ? null : _handleForgotPassword,
        child: const Text("Forgot Password?",
            style: TextStyle(
                color: Colors.purple,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: Colors.purple,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          icon: const Icon(Icons.arrow_forward, color: Colors.white),
          label: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Text("Login",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        const Text("Or continue with",
            style: TextStyle(color: Colors.black, fontSize: 14)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialButtonImage("assets/images/google_icon.png",
                () => _handleSocialLogin("Google")),
            const SizedBox(width: 24),
            _socialButtonImage("assets/images/facebook_icon.png",
                () => _handleSocialLogin("Facebook")),
            const SizedBox(width: 24),
            _socialButtonImage("assets/images/apple_icon.png",
                () => _handleSocialLogin("Apple")),
          ],
        ),
      ],
    );
  }

  Widget _socialButtonImage(String imagePath, VoidCallback onTap) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Image.asset(
            imagePath,
            width: 24,
            height: 24,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error), // Fallback icon
          ),
        ),
      ),
    );
  }
}

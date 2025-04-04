import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_wrapper.dart';
import '../services/firestore_service.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _unverifiedEmail;
  User? _unverifiedUser;

  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      if (!credential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut();

        setState(() {
          _unverifiedEmail = credential.user!.email;
          _unverifiedUser = credential.user;
          _isLoading = false;
        });

        _showMessage('Please verify your email before logging in.');
        return;
      }

      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
      );

      _navigateToApp();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (e.code == 'user-not-found') {
        _showMessage('No account found for that email.');
      } else if (e.code == 'wrong-password') {
        _showMessage('Incorrect password.');
      } else {
        _showMessage('Login failed: ${e.message}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('An unexpected error occurred: $e');
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    final credential = await _authService.signInWithGoogle();

    if (credential != null) {
      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
      );
      _navigateToApp();
    } else {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Google sign-in failed');
    }
  }

  void _navigateToApp() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BottomNavWrapper()),
    );
  }

  void _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent to $email.');
    } catch (e) {
      _showMessage('Error sending reset email: $e');
    }
  }

  void _resendVerificationEmail() async {
    try {
      await _unverifiedUser?.sendEmailVerification();
      _showMessage('Verification email resent to $_unverifiedEmail');
    } catch (e) {
      _showMessage('Error resending verification: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      icon: Image.asset(
        'assets/images/google_icon.png',
        height: 20,
        width: 20,
      ),
      label: const Text(
        'Continue with Google',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white30
              : Colors.black12,
          width: 1,
        ),
      ),
      onPressed: _loginWithGoogle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.air_outlined,
                    size: 60,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dust Allergy Tracker',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your symptoms and cleaning habits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton(
                              onPressed: _loginWithEmail,
                              child: const Text('Sign In'),
                            ),
                            const SizedBox(height: 16),
                            _buildGoogleButton(),
                          ],
                        ),
                  if (_unverifiedUser != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextButton(
                        onPressed: _resendVerificationEmail,
                        child: const Text('Resend Verification Email'),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

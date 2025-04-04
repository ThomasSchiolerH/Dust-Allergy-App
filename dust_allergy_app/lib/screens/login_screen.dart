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

  String? _unverifiedEmail;
  User? _unverifiedUser;

  void _loginWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

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
        });

        _showError('Please verify your email before logging in.');
        return;
      }

      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
      );

      _navigateToApp();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showError('No account found for that email.');
      } else if (e.code == 'wrong-password') {
        _showError('Incorrect password.');
      } else {
        _showError('Login failed: ${e.message}');
      }
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    }
  }

  void _registerWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

    try {
      final credential = await _authService.registerWithEmail(
        email: email,
        password: password,
      );

      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
      );

      _navigateToApp();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _loginWithGoogle() async {
    final credential = await _authService.signInWithGoogle();
    if (credential != null) {
      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: credential.user!.email,
        name: credential.user!.displayName,
      );
      _navigateToApp();
    } else {
      _showError('Google sign-in failed');
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
      _showError('Please enter your email first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showError('Password reset email sent to $email.');
    } catch (e) {
      _showError('Error sending reset email: $e');
    }
  }

  void _resendVerificationEmail() async {
    try {
      await _unverifiedUser?.sendEmailVerification();
      _showError('Verification email resent to $_unverifiedEmail');
    } catch (e) {
      _showError('Error resending verification: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildGoogleButton() {
    return ElevatedButton.icon(
      icon: Image.asset(
        'assets/images/google_icon.png',
        height: 20,
        width: 20,
      ),
      label: const Text(
        'Sign in with Google',
        style: TextStyle(color: Colors.black87),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.grey),
        ),
      ),
      onPressed: _loginWithGoogle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loginWithEmail,
              style: ElevatedButton.styleFrom(
                elevation: 2,
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Login with Email',
                style: TextStyle(fontSize: 16),
              ),
            ),
            if (_unverifiedUser != null)
              TextButton(
                onPressed: _resendVerificationEmail,
                child: const Text('Resend Verification Email',
                    style: TextStyle(color: Colors.blue)),
              ),
            const SizedBox(height: 16),
            _buildGoogleButton(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
              child: const Text(
                "Don't have an account? Sign up",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: _forgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

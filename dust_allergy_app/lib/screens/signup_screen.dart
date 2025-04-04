import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/bottom_nav_wrapper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hasStartedTyping = false;
  Color _strengthColor = Colors.red;
  String _strengthLabel = 'Too Weak';
  double _passwordStrength = 0;

  void _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    try {
      final credential = await _authService.registerWithEmail(
        email: email,
        password: password,
      );

      await credential.user!.sendEmailVerification();

      await FirestoreService().createUserProfile(
        userId: credential.user!.uid,
        email: email,
        name: name,
      );

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verify Your Email'),
            content: Text(
              'A verification email has been sent to $email. '
              'Please check your inbox and verify before logging in.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

    } catch (e) {
      _showError(e.toString());
    }
  }

  double _calculatePasswordStrength(String password) {
    double strength;
    if (password.length < 6) {
      strength = 0.2;
      _strengthColor = Colors.red;
      _strengthLabel = 'Too Weak';
    } else if (password.length < 8) {
      strength = 0.4;
      _strengthColor = Colors.orange;
      _strengthLabel = 'Weak';
    } else if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#\$&*~]'))) {
      strength = 1.0;
      _strengthColor = Colors.purple;
      _strengthLabel = 'Strong';
    } else {
      strength = 0.7;
      _strengthColor = Colors.green;
      _strengthLabel = 'Okay';
    }
    return strength;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              onChanged: (value) {
                setState(() {
                  _hasStartedTyping = value.isNotEmpty;
                  _passwordStrength = _calculatePasswordStrength(value);
                });
              },
            ),
            if (_hasStartedTyping) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _passwordStrength,
                backgroundColor: Colors.grey.shade300,
                color: _strengthColor,
              ),
              const SizedBox(height: 8),
              Text(
                _strengthLabel,
                style: TextStyle(
                    color: _strengthColor, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _register,
              child: const Text('Sign Up'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_nav_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _registerWithEmail() async {
    try {
      await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _navigateToApp();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _loginWithEmail() async {
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _navigateToApp();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _loginWithGoogle() async {
    try {
      await _authService.signInWithGoogle();
      _navigateToApp();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _navigateToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BottomNavWrapper()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
              child: const Text('Login with Email'),
            ),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                iconSize: 40,
                icon: Image.asset('assets/images/google_icon.png'),
                onPressed: () async {
                  final credential = await _authService.signInWithGoogle();
                  if (credential != null) {
                    _navigateToApp();
                  } else {
                    _showError('Google sign-in failed');
                  }
                },
              ),
            ),
            ElevatedButton(
              onPressed: _registerWithEmail,
              child: const Text('Register with Email'),
            ),
          ],
        ),
      ),
    );
  }
}

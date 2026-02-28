import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String getFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  void login() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = userCred.user!;
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Email not verified! Verification link has been sent. Check your inbox.')));
        await _auth.signOut();
        setState(() => _isLoading = false);
        return;
      }

      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(getFirebaseAuthError(e))));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
      debugPrint('Login error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 15),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Login Button
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: login, child: const Text('Login')),

            const SizedBox(height: 20),

            // Navigate to Sign Up
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
              child: const Text('Don’t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

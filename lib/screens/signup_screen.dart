import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // -------------------- Firebase Auth Error Mapping --------------------
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
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  // -------------------- Sign Up Method --------------------
  void signUp() async {
    setState(() => _isLoading = true);
    final password = _passwordController.text.trim();

    // Password validation
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters.')));
      setState(() => _isLoading = false);
      return;
    }

    final regex = RegExp(r'^(?=.*[A-Z])(?=.*\d).+$');
    if (!regex.hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Password must contain at least 1 uppercase letter and 1 number.')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Create user in Firebase Auth
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: password,
      );

      // Save user info to Firestore
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'uid': userCred.user!.uid,
      });

      // Send verification email
      await userCred.user!.sendEmailVerification();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Account created! A verification email has been sent. Please verify your email before logging in.')));

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(getFirebaseAuthError(e))));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      debugPrint('Sign-up error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Username
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 15),

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

            // Sign Up Button
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: signUp, child: const Text('Sign Up')),

            const SizedBox(height: 20),

            // Navigate to Login
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}

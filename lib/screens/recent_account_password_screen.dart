import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/recent_accounts_service.dart';

class RecentAccountPasswordScreen extends StatefulWidget {
  final String email;
  final String username;
  final String photoUrl;

  const RecentAccountPasswordScreen({
    super.key,
    required this.email,
    required this.username,
    this.photoUrl = '',
  });

  @override
  State<RecentAccountPasswordScreen> createState() =>
      _RecentAccountPasswordScreenState();
}

class _RecentAccountPasswordScreenState
    extends State<RecentAccountPasswordScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
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

  Future<void> loginWithRecentAccount() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: widget.email,
        password: _passwordController.text,
      );

      final user = userCred.user!;
      await user.reload();

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email not verified. A new verification link has been sent.',
            ),
          ),
        );
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      final username = (doc.data()?['username'] ?? widget.username).toString();
      final photoUrl = (doc.data()?['photoUrl'] ?? widget.photoUrl).toString();

      await RecentAccountsService.saveAccount(
        uid: user.uid,
        email: widget.email,
        username: username,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(getFirebaseAuthError(e))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget buildAvatar() {
    if (widget.photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundImage: NetworkImage(widget.photoUrl),
      );
    }

    return CircleAvatar(
      radius: 34,
      backgroundColor: Colors.green[200],
      child: Text(
        widget.username.isNotEmpty
            ? widget.username[0].toUpperCase()
            : "?",
        style: GoogleFonts.montserrat(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sign in',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            buildAvatar(),
            const SizedBox(height: 16),
            Text(
              widget.username,
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.email,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loginWithRecentAccount,
                      child: const Text('Continue'),
                    ),
                  ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Use another account'),
            ),
          ],
        ),
      ),
    );
  }
}
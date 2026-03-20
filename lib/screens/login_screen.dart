import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import '../services/recent_accounts_service.dart';
import 'recent_account_password_screen.dart';

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

  List<Map<String, dynamic>> recentAccounts = [];

  @override
  void initState() {
    super.initState();
    loadRecentAccounts();
  }

  Future<void> loadRecentAccounts() async {
    final accounts = await RecentAccountsService.getAccounts();
    setState(() {
      recentAccounts = accounts;
    });
  }

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

  Future<void> login() async {
    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
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
      final username = (doc.data()?['username'] ?? '').toString();
      final photoUrl = (doc.data()?['photoUrl'] ?? '').toString();

      await RecentAccountsService.saveAccount(
        uid: user.uid,
        email: _emailController.text.trim(),
        username: username,
        photoUrl: photoUrl,
      );

      await loadRecentAccounts();

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

  Future<void> removeRecentAccount(String email) async {
    await RecentAccountsService.removeAccount(email);
    await loadRecentAccounts();
  }

  Widget buildRecentAvatar(String username, String photoUrl) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.green[200],
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : "?",
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget buildRecentAccountCard(Map<String, dynamic> account) {
    final username = (account['username'] ?? '').toString();
    final email = (account['email'] ?? '').toString();
    final photoUrl = (account['photoUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        elevation: 2,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecentAccountPasswordScreen(
                  email: email,
                  username: username,
                  photoUrl: photoUrl,
                ),
              ),
            ).then((_) {
              loadRecentAccounts();
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                buildRecentAvatar(username, photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => removeRecentAccount(email),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRecentAccountsSection() {
    if (recentAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose an account",
            style: GoogleFonts.montserrat(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Continue with a recently used account.",
            style: GoogleFonts.montserrat(
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ...recentAccounts.map(buildRecentAccountCard),
        ],
      ),
    );
  }

  Widget buildDividerLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "Use another account",
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget buildManualLoginSection() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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
        const SizedBox(height: 24),
        _isLoading
            ? const CircularProgressIndicator()
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Login'),
                ),
              ),
      ],
    );
  }

  Widget buildHeader() {
    return Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Colors.white,
          child: const Icon(
            Icons.person_outline_rounded,
            size: 34,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Welcome back',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue using MindaPrice ZW',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecentAccounts = recentAccounts.isNotEmpty;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            'Login',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              buildHeader(),
            const SizedBox(height: 28),
            buildRecentAccountsSection(),
            if (hasRecentAccounts) buildDividerLabel(),
            if (hasRecentAccounts) const SizedBox(height: 12),
            buildManualLoginSection(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/signup'),
              child: const Text('Don’t have an account? Sign Up'),
            ),
          ],
        ),
      ),
    ),
  );
}
}
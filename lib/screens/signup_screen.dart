import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/recent_accounts_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';

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
  String _accountType = 'Farmer'; // Default value

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
        'accountType': _accountType.toLowerCase(), // 'farmer' or 'buyer'
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send verification email
      await userCred.user!.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Account created! A verification email has been sent. Please verify your email before logging in.')));

      // Navigate to login screen
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(getFirebaseAuthError(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
      debugPrint('Sign-up error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoogleSignInAccount? googleUser;
      
      if (kIsWeb) {
        googleUser = await GoogleSignIn.instance.authenticate();
      } else {
        googleUser = await GoogleSignIn.instance.authenticate();
      }

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;
      if (user == null) throw Exception("Failed to sign in with Google.");

      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) {
        String actType = 'farmer';
        
        if (mounted) {
          final selectedType = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: Text("Welcome to MindaPrice!", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Are you joining us as a Farmer or a Product Buyer?", style: GoogleFonts.montserrat(fontSize: 14)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, 'farmer'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                        child: const Text("I am a Farmer"),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'buyer'),
                        child: const Text("I am a Buyer"),
                      ),
                    ),
                  ],
                ),
              );
            }
          );
          if (selectedType != null) {
            actType = selectedType;
          }
        }

        await _firestore.collection('users').doc(user.uid).set({
          'username': user.displayName ?? 'New User',
          'email': user.email,
          'uid': user.uid,
          'accountType': actType,
          'role': 'user',
          'photoUrl': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final username = user.displayName ?? 'Google User';
      final photoUrl = user.photoURL ?? '';
      await RecentAccountsService.saveAccount(
        uid: user.uid,
        email: user.email ?? '',
        username: username,
        photoUrl: photoUrl,
        authProvider: 'google',
      );
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(getFirebaseAuthError(e))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
      }
      debugPrint('Google Sign-In Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 2,
          foregroundColor: Colors.black87,
          title: Text(
            'Create Account',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Username
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                labelText: 'Username',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.transparent,
              ),
            ),
            const SizedBox(height: 15),

            // Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.transparent,
              ),
            ),
            const SizedBox(height: 15),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.transparent,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Account Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _accountType,
              decoration: InputDecoration(
                labelText: 'I am a...',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.transparent,
              ),
              items: ['Farmer', 'Product Buyer'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: GoogleFonts.montserrat()),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _accountType = newValue!;
                });
              },
            ),
            const SizedBox(height: 30),

            // Sign Up Button
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: signUp,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Sign Up')
                    )
                  ),
            const SizedBox(height: 16),
            _isLoading
                ? const SizedBox.shrink()
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: signInWithGoogle,
                      icon: const Icon(Icons.account_circle, color: Colors.blueAccent),
                      label: Text('Continue with Google', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.black87)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),

            const SizedBox(height: 20),

            // Navigate to Login
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    ),
  );
}
}

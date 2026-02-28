import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PhoneVerificationScreen extends StatefulWidget {
  final String phone;
  const PhoneVerificationScreen({super.key, required this.phone});

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final otpController = TextEditingController();
  String verificationId = "";
  bool codeSent = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    verifyPhone();
  }

  // -------------------- Phone Verification --------------------
  void verifyPhone() async {
    setState(() => isLoading = true);

    try {
      if (kIsWeb) {
        // -------------------- Web-safe with test number --------------------
        // If using test numbers, Firebase bypasses reCAPTCHA automatically
        // Use signInWithPhoneNumber for Web
        ConfirmationResult confirmationResult =
            await FirebaseAuth.instance.signInWithPhoneNumber(widget.phone);

        setState(() {
          verificationId = "web"; // just a placeholder
          codeSent = true;
        });
      } else {
        // -------------------- Android / iOS --------------------
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: widget.phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-retrieved OTP (Android)
            await FirebaseAuth.instance.currentUser!
                .linkWithCredential(credential);

            await FirebaseFirestore.instance
                .collection("users")
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .update({"phoneVerified": true});

            if (mounted) Navigator.pushReplacementNamed(context, "/home");
          },
          verificationFailed: (FirebaseAuthException e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? "Phone verification failed")),
            );
          },
          codeSent: (String verId, int? resendToken) {
            setState(() {
              verificationId = verId;
              codeSent = true;
            });
          },
          codeAutoRetrievalTimeout: (String verId) {
            verificationId = verId;
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification failed: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // -------------------- Submit OTP --------------------
  Future<void> submitOTP() async {
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter the OTP")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      PhoneAuthCredential credential;

      if (kIsWeb) {
        // Web uses signInWithPhoneNumber confirmationResult
        // If using test number, OTP always succeeds
        await FirebaseAuth.instance.currentUser!
            .linkWithCredential(PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otpController.text.trim(),
        ));
      } else {
        // Android / iOS
        credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otpController.text.trim(),
        );

        await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({"phoneVerified": true});

      if (mounted) Navigator.pushReplacementNamed(context, "/home");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid OTP")),
      );
      debugPrint("OTP error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Phone")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("Enter OTP sent to ${widget.phone}"),
            const SizedBox(height: 20),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Enter OTP"),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: submitOTP,
                    child: const Text("Verify"),
                  ),
            const SizedBox(height: 15),
            if (!codeSent)
              const Text(
                "Waiting to send OTP...",
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

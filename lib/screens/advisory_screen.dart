import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/notification_service.dart';

class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  // IMPORTANT: emulator uses 10.0.2.2 instead of localhost
  final String baseUrl = "https://mindaprice-backend.onrender.com";


  Future<void> sendAdvisory() async {
    final message = _controller.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message cannot be empty")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Get Firebase ID token for authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final idToken = await user.getIdToken(true);

      // Call YOUR backend
      final response = await http.post(
        Uri.parse("$baseUrl/advisories/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode != 200) {
        throw Exception("Server error: ${response.body}");
      }

      // Show local notification instantly for sender
      await NotificationService.showNotification(
        title: "Farming Advisory",
        body: message,
      );

      _controller.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Advisory sent successfully 🚀")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send advisory: $e")),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Advisory")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Advisory Message",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isSending
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: sendAdvisory,
                    child: const Text("Send Advisory"),
                  ),
          ],
        ),
      ),
    );
  }
}

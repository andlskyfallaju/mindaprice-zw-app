import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String baseUrl = "https://mindaprice-backend.onrender.com";

  String getConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  @override
  void initState() {
    super.initState();
    markMessagesAsRead();
  }

  Future<void> markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final conversationId =
        getConversationId(currentUser.uid, widget.otherUserId);

    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .set({
      'participants': [currentUser.uid, widget.otherUserId],
      'unreadCounts.${currentUser.uid}': 0,
    }, SetOptions(merge: true));
  }

  Future<String> getMyUsername() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return "New message";

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return (doc.data()?['username'] ?? "New message").toString();
  }

  Future<void> sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final conversationId =
        getConversationId(currentUser.uid, widget.otherUserId);

    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);

    final messageRef = conversationRef.collection('messages').doc();

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      conversationRef,
      {
        'participants': [currentUser.uid, widget.otherUserId],
        'lastMessage': text,
        'lastUpdated': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.otherUserId}': FieldValue.increment(1),
        'unreadCounts.${currentUser.uid}': 0,
      },
      SetOptions(merge: true),
    );

    batch.set(messageRef, {
      'senderId': currentUser.uid,
      'text': text,
      'sentAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    final myUsername = await getMyUsername();

    try {
      await http.post(
        Uri.parse("$baseUrl/messages/notify"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "recipientUid": widget.otherUserId,
          "senderUid": currentUser.uid,
          "senderName": myUsername,
          "message": text,
        }),
      );
    } catch (_) {}

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    final conversationId =
        getConversationId(currentUser.uid, widget.otherUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherUsername,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .collection('messages')
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  markMessagesAsRead();
                });

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      "No messages yet.\nStart the conversation.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: Colors.black54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUser.uid;
                    final text = msg['text'] ?? '';

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          text,
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.orange.shade700,
                    child: IconButton(
                      onPressed: sendMessage,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
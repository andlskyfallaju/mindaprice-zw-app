import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String getConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Messenger",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
      ),
      body: currentUser == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('username')
                  .snapshots(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!userSnapshot.hasData || userSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No users found."));
                }

                final users = userSnapshot.data!.docs
                    .where((doc) => doc.id != currentUser.uid)
                    .toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final username = user['username'] ?? 'Unknown User';
                    final email = user['email'] ?? '';
                    final role = user.data().toString().contains('role')
                        ? (user['role'] ?? 'user')
                        : 'user';

                    final conversationId =
                        getConversationId(currentUser.uid, user.id);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(conversationId)
                          .snapshots(),
                      builder: (context, convoSnapshot) {
                        int unreadCount = 0;
                        String subtitle = email;

                        if (convoSnapshot.hasData &&
                            convoSnapshot.data!.exists) {
                          final data = Map<String, dynamic>.from(
                            convoSnapshot.data!.data() as Map,
                          );
                          final unreadCounts =
                            Map<String, dynamic>.from(data['unreadCounts'] ?? {});
                          unreadCount =
                              (unreadCounts[currentUser.uid] ?? 0) as int;
                          subtitle = (data['lastMessage'] ?? email).toString();
                        }

                        return Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    otherUserId: user.id,
                                    otherUsername: username,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    child: Text(
                                      username.toString().isNotEmpty
                                          ? username.toString()[0].toUpperCase()
                                          : "?",
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      if (role == "admin")
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            "Admin",
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      if (unreadCount > 0) ...[
                                        const SizedBox(height: 8),
                                        Badge(
                                          label: Text(unreadCount.toString()),
                                        ),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
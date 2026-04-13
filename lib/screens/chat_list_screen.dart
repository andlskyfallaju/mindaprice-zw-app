import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'user_search_screen.dart';
import '../widgets/app_background.dart';
import '../services/chat_service.dart';
import '../widgets/app_gradient.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  String getConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final ChatService chatService = ChatService();

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        flexibleSpace: const AppGradient(),
        automaticallyImplyLeading: false,
        elevation: 2,
        title: Text(
          "MindaPrice Chat",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text("Not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: chatService.getContacts(),
              builder: (context, contactSnapshot) {
                if (contactSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final contacts = contactSnapshot.data?.docs ?? [];

                if (contacts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "No contacts yet.",
                          style: GoogleFonts.montserrat(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UserSearchScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                          ),
                          child: const Text("Search for Users", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final username = contact['username'] ?? 'Unknown User';
                    final otherUid = contact.id;

                    final conversationId = getConversationId(currentUser.uid, otherUid);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conversations')
                          .doc(conversationId)
                          .snapshots(),
                      builder: (context, convoSnapshot) {
                        String lastMessage = "Tap to chat";
                        String timeText = "";
                        int unreadCount = 0;

                        if (convoSnapshot.hasData && convoSnapshot.data!.exists) {
                          final data = convoSnapshot.data!.data() as Map<String, dynamic>;
                          lastMessage = data['lastMessage'] ?? "Tap to chat";
                          
                          if (data['lastUpdated'] != null) {
                            final DateTime date = (data['lastUpdated'] as Timestamp).toDate();
                            timeText = DateFormat('jm').format(date); // e.g. 10:45 AM
                          }

                          final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
                          unreadCount = (unreadCounts[currentUser.uid] ?? 0) as int;
                        }

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  otherUserId: otherUid,
                                  otherUsername: username,
                                ),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots(),
                            builder: (context, userSnapshot) {
                              String? pUrl;
                              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                pUrl = (userSnapshot.data!.data() as Map<String, dynamic>)['photoUrl'] as String?;
                              }

                              return CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFFD1D7DB),
                                backgroundImage: pUrl != null ? NetworkImage(pUrl) : null,
                                child: pUrl == null
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              );
                            },
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                username,
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unreadCount > 0 ? Colors.green[700] : Colors.grey,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green[700],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserSearchScreen()),
          );
        },
        backgroundColor: Colors.green[800],
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    ),
  );
}
}
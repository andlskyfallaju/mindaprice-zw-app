import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import '../services/chat_service.dart';
import '../widgets/rating_widgets.dart';


class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

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
          "Search Users",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: "Search by username...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildIncomingRequestsSection()
                : _buildSearchResults(),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildIncomingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Incoming Requests",
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatService.getIncomingRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) {
                return const Center(
                  child: Text("No incoming chat requests."),
                );
              }
              return ListView.builder(
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final req = requests[index];
                  final fromUsername = req['fromUsername'] ?? 'Unknown';
                  final fromUid = req['fromUid'];

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(fromUid).snapshots(),
                    builder: (context, userSnap) {
                      String? pUrl;
                      if (userSnap.hasData && userSnap.data!.exists) {
                        pUrl = (userSnap.data!.data() as Map<String, dynamic>)['photoUrl'] as String?;
                      }
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: pUrl != null ? NetworkImage(pUrl) : null,
                          child: pUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(fromUsername),
                        subtitle: const Text("Sent you a chat request"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _chatService.acceptChatRequest(
                                fromUid,
                                fromUsername,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _chatService.declineChatRequest(fromUid),
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
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.searchUsers(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snapshot.data?.docs
                .where((doc) => doc.id != _chatService.currentUid)
                .toList() ??
            [];

        if (users.isEmpty) {
          return const Center(child: Text("No users found."));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final username = user['username'] ?? 'Unknown';
            final photoUrl = (user.data() as Map<String, dynamic>)['photoUrl'] as String?;
            final ratingAvg = ((user.data() as Map<String, dynamic>)['ratingAverage'] ?? 0.0) as num;
            final ratingCount = ((user.data() as Map<String, dynamic>)['ratingCount'] ?? 0) as int;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person) : null,
              ),
              title: Text(username),
              subtitle: UserRatingBadge(
                average: ratingAvg.toDouble(),
                count: ratingCount,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rate $username',
                    icon: const Icon(Icons.star_outline_rounded, color: Colors.amber),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => RatingDialog(toUid: user.id, toUsername: username),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _chatService.sendChatRequest(user.id, username);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat request sent!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

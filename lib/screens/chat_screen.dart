import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../widgets/app_gradient.dart';
import '../services/wallpaper_service.dart';
import '../widgets/chat_wallpaper_picker.dart';

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final String baseUrl = "https://mindaprice-backend.onrender.com";

  WallpaperType _wallpaperType = WallpaperType.none;
  dynamic _wallpaperValue;

  String getConversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return "${ids[0]}_${ids[1]}";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updatePresence(true);
    markMessagesAsRead();
    _loadWallpaper();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);
    _messageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else {
      _updatePresence(false);
    }
  }

  Future<void> _loadWallpaper() async {
    try {
      final wp = await WallpaperService.getWallpaper();
      if (mounted) {
        setState(() {
          _wallpaperType = wp['type'];
          _wallpaperValue = wp['value'];
        });
      }
    } catch (e) {
      debugPrint("Error loading wallpaper: $e");
    }
  }

  Future<void> _updatePresence(bool isOnline) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'activeChatId': isOnline ? conversationId : null,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markMessagesAsRead() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final conversationId = getConversationId(currentUser.uid, widget.otherUserId);

      // Update unread counts
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .set({
        'participants': [currentUser.uid, widget.otherUserId],
        'unreadCounts.${currentUser.uid}': 0,
      }, SetOptions(merge: true));

      // Update individual messages sent by the other user to 'read'
      final unreadMessages = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: widget.otherUserId)
          .get();

      final messagesToUpdate = unreadMessages.docs.where((doc) {
        final data = doc.data();
        return data['status'] != 'read';
      }).toList();

      if (messagesToUpdate.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in messagesToUpdate) {
          batch.update(doc.reference, {
            'status': 'read',
            'isRead': true,
          });
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint("Error marking messages as read: $e");
    }
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

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);

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
      'status': 'sent',
      'isRead': false,
    });

    _messageController.clear();
    await batch.commit();

    final myUsername = await getMyUsername();

    try {
      await http.post(
        Uri.parse("$baseUrl/messages/notify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "recipientUid": widget.otherUserId,
          "senderUid": currentUser.uid,
          "senderName": myUsername,
          "message": text,
        }),
      );
    } catch (_) {}
  }

  BoxDecoration _buildWallpaperDecoration() {
    if (_wallpaperType == WallpaperType.color) {
      return BoxDecoration(color: _wallpaperValue as Color);
    } else if (_wallpaperType == WallpaperType.image) {
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(_wallpaperValue as File),
          fit: BoxFit.cover,
        ),
      );
    }
    // Default: dark grey for dark mode, classic WhatsApp beige for light
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5DDD5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const AppGradient(),
        elevation: 2,
        foregroundColor: Colors.black87,
        leadingWidth: 90,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
              builder: (context, snapshot) {
                String? pUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  pUrl = (snapshot.data!.data() as Map<String, dynamic>)['photoUrl'] as String?;
                }
                return CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFD1D7DB),
                  backgroundImage: pUrl != null ? NetworkImage(pUrl) : null,
                  child: pUrl == null ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
                );
              },
            ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUsername,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final activeChatId = userData['activeChatId'] as String?;
                final isOnline = activeChatId == conversationId;
                
                return Text(
                  isOnline ? "online" : "offline",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                );
              },
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'wallpaper') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatWallpaperPicker()),
                ).then((_) => _loadWallpaper());
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper, color: Colors.black54),
                    SizedBox(width: 8),
                    Text("Wallpaper"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: _buildWallpaperDecoration(),
        child: Column(
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
                    return const Center(child: Text("Say hello!"));
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderId'] == currentUser.uid;
                      final text = msg['text'] ?? '';
                      final timestamp = msg['sentAt'] as Timestamp?;
                      final status = msg.data().toString().contains('status') 
                          ? msg['status'] as String 
                          : 'sent';
                      
                      final time = timestamp != null
                          ? DateFormat('jm').format(timestamp.toDate())
                          : "";

                      return ChatBubble(
                        message: text,
                        isMe: isMe,
                        time: time,
                        status: status,
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C2C2C)
                : Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.grey),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.green[800],
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final String status;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bubbleColor = isMe 
      ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6)) 
      : (isDark ? const Color(0xFF202C33) : Colors.white);

    if (isMe) {
      if (status == 'failed') {
        bubbleColor = isDark ? Colors.red[900]! : Colors.red[100]!;
      } else if (status == 'read') {
        bubbleColor = isDark ? const Color(0xFF005C4B) : Colors.green[100]!;
      } else if (status == 'sent') {
        bubbleColor = isDark ? const Color(0xFF1A3A5C) : Colors.blue[100]!;
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: status == 'failed' 
                  ? (isDark ? Colors.red[200] : Colors.red[900]) 
                  : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10, 
                    color: isDark ? Colors.white60 : Colors.black54
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(isDark),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool isDark) {
    IconData iconData = Icons.done;
    Color iconColor = isDark ? Colors.white60 : Colors.black54;

    if (status == 'read') {
      iconData = Icons.done_all;
      iconColor = isDark ? Colors.greenAccent : Colors.blue;
    } else if (status == 'sent') {
      iconData = Icons.done;
    } else if (status == 'failed') {
      iconData = Icons.error_outline;
      iconColor = isDark ? Colors.redAccent : Colors.red;
    }

    return Icon(iconData, size: 14, color: iconColor);
  }
}
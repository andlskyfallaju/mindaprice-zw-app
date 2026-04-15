import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cloudinary_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/app_gradient.dart';
import '../services/wallpaper_service.dart';
import '../widgets/chat_wallpaper_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../widgets/chat_bubble.dart';

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
  bool isOffline = false;
  bool _isUploading = false;
  StreamSubscription? _connectivitySubscription;

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
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!mounted) return;
      setState(() {
        isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);
    _messageController.dispose();
    _connectivitySubscription?.cancel();
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final conversationId = getConversationId(currentUser.uid, widget.otherUserId);
      
      final wp = await WallpaperService.getWallpaper(chatId: conversationId);
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
        'unreadCounts': { currentUser.uid: 0 },
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

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);
    final docRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);

    if (forEveryone) {
      await docRef.update({
        'text': '🚫 This message was deleted',
        'isDeleted': true,
      });
    } else {
      await docRef.update({
        'deletedFor': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
  }

  Future<void> _clearConversation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat?"),
        content: const Text("This will remove all messages from your view."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);
    final messages = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messages.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([currentUser.uid]),
      });
    }
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Conversation cleared")),
    );
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

  Future<void> _pickAndSendImage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final conversationId = getConversationId(currentUser.uid, widget.otherUserId);
      final downloadUrl = await CloudinaryService.uploadChatImage(picked, conversationId);

      if (downloadUrl == null) throw Exception('Cloudinary upload failed.');

      await _sendMessagePayload(currentUser, conversationId, '', imageUrl: downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    final conversationId = getConversationId(currentUser.uid, widget.otherUserId);
    await _sendMessagePayload(currentUser, conversationId, text);
  }

  Future<void> _sendMessagePayload(User currentUser, String conversationId, String text, {String? imageUrl}) async {
    final conversationRef = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId);

    final messageRef = conversationRef.collection('messages').doc();
    final batch = FirebaseFirestore.instance.batch();

    final lastMessagePreview = imageUrl != null ? '📷 Photo' : text;

    batch.set(
      conversationRef,
      {
        'participants': [currentUser.uid, widget.otherUserId],
        'lastMessage': lastMessagePreview,
        'lastUpdated': FieldValue.serverTimestamp(),
        'unreadCounts': {
          widget.otherUserId: FieldValue.increment(1),
          currentUser.uid: 0,
        },
      },
      SetOptions(merge: true),
    );

    batch.set(messageRef, {
      'senderId': currentUser.uid,
      'text': text,
      'imageUrl': ?imageUrl,
      'sentAt': Timestamp.now(),
      'status': 'sent',
      'isRead': false,
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
      return;
    }

    final myUsername = await getMyUsername();
    try {
      await http.post(
        Uri.parse("$baseUrl/messages/notify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "recipientUid": widget.otherUserId,
          "senderUid": currentUser.uid,
          "senderName": myUsername,
          "message": lastMessagePreview,
        }),
      );
    } catch (_) {}
  }

  BoxDecoration _buildWallpaperDecoration() {
    if (_wallpaperType == WallpaperType.color) {
      return BoxDecoration(color: _wallpaperValue as Color);
    } else if (_wallpaperType == WallpaperType.image) {
      if (kIsWeb) {
        return BoxDecoration(
          image: DecorationImage(
            image: NetworkImage((_wallpaperValue as io.File).path),
            fit: BoxFit.cover,
          ),
        );
      }
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(_wallpaperValue as io.File),
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

    final conversationId =
        getConversationId(currentUser.uid, widget.otherUserId);

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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherUserId)
                  .snapshots(),
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
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox();
                }
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
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, color: Colors.black54),
                    SizedBox(width: 8),
                    Text("Clear Chat"),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'wallpaper') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatWallpaperPicker(
                      chatId: conversationId,
                      chatName: widget.otherUsername,
                    ),
                  ),
                ).then((_) => _loadWallpaper());
              } else if (value == 'clear') {
                _clearConversation();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isOffline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                "Waiting for network...",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Container(
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

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final allMessages = snapshot.data?.docs ?? [];
                        final isFromCache = snapshot.data?.metadata.isFromCache ?? false;

                        // Filter out messages deleted for ME
                        final messages = allMessages.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final deletedFor = data['deletedFor'] as List?;
                          return deletedFor == null || !deletedFor.contains(currentUser.uid);
                        }).toList();

                        if (messages.isEmpty) {
                          return const Center(child: Text("Say hello!"));
                        }

                        return Column(
                          children: [
                            if (isFromCache && !isOffline)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  "Syncing messages...",
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final data = msg.data() as Map<String, dynamic>;
                                  final isMe = data['senderId'] == currentUser.uid;
                                  final text = data['text'] ?? '';
                                  final timestamp = (data['sentAt'] ?? data['createdAt']) as Timestamp?;
                                  String status = data['status'] ?? 'sent';
                                  
                                  // If message is from cache and we sent it, mark as 'pending'
                                  if (isMe && msg.metadata.hasPendingWrites) {
                                    status = 'pending';
                                  }

                                  final time = timestamp != null
                                      ? DateFormat('jm').format(timestamp.toDate())
                                      : "";

                                  return GestureDetector(
                                    onLongPress: () => _showDeleteOptions(msg.id, isMe),
                                    child: ChatBubble(
                                      message: text,
                                      isMe: isMe,
                                      time: time,
                                      status: status,
                                      isDeleted: data['isDeleted'] == true,
                                      imageUrl: data['imageUrl'] as String?,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _buildMessageInput(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteOptions(String messageId, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text("Delete for me"),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId, false);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text("Delete for everyone"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId, true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isUploading)
          LinearProgressIndicator(
            backgroundColor: Colors.grey[300],
            color: Colors.green[700],
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: isDark ? const Color(0xFF1B1B1B) : Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                          onSubmitted: (_) => sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        onPressed: _isUploading ? null : _pickAndSendImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.grey),
                        onPressed: _isUploading ? null : _pickAndSendImage,
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
        ),
      ],
    );
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../widgets/app_gradient.dart';
import '../services/wallpaper_service.dart';
import '../widgets/chat_wallpaper_picker.dart';
import '../widgets/chat_bubble.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String baseUrl = "https://mindaprice-backend.onrender.com";
  
  bool _isThinking = false;
  String? farmProfile;
  String? locationName;
  double? lat;
  double? lon;
  String? preferredLanguage;
  XFile? _selectedImage;

  WallpaperType _wallpaperType = WallpaperType.none;
  dynamic _wallpaperValue;

  @override
  void initState() {
    super.initState();
    _loadUserContext();
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    try {
      final wp = await WallpaperService.getWallpaper(chatId: 'minda_advisor');
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

  Future<void> _loadUserContext() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        farmProfile = data['farmProfile'] as String?;
        locationName = data['locationName'] as String?;
        lat = data['lat'] as double?;
        lon = data['lon'] as double?;
        preferredLanguage = data['preferredLanguage'] as String?;
      });
    }
  }

  Future<void> _sendMessage({XFile? imageFile}) async {
    final text = _messageController.text.trim();
    if ((text.isEmpty && imageFile == null) || _isThinking) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _messageController.clear();
    final imageToSend = imageFile;
    setState(() {
      _isThinking = true;
      _selectedImage = null;
    });

    final chatRef = FirebaseFirestore.instance
        .collection('ai_farmer_chats')
        .doc(user.uid)
        .collection('messages');

    // 1. Save User Message
    await chatRef.add({
      'role': 'user',
      'senderId': user.uid,
      'text': text,
      'imageUrl': null, // may be updated below
      'createdAt': FieldValue.serverTimestamp(),
      'sentAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    });

    // Encode image to base64 if present
    String? imageBase64;
    String? imageMimeType;
    String? localImagePreviewUrl;
    if (imageToSend != null) {
      final bytes = await imageToSend.readAsBytes();
      imageBase64 = base64Encode(bytes);
      imageMimeType = 'image/jpeg';
      // Save a local path as temporary preview - we show it immediately
      localImagePreviewUrl = imageToSend.path;
      // Update the user message with image info (local path as placeholder)
      final lastMsg = await chatRef.orderBy('createdAt', descending: true).limit(1).get();
      if (lastMsg.docs.isNotEmpty) {
        await lastMsg.docs.first.reference.update({'imageLocalPath': localImagePreviewUrl});
      }
    }

    // 2. Prep History for AI
    final historySnap = await chatRef.orderBy('createdAt', descending: true).limit(10).get();
    final history = historySnap.docs.reversed.map((d) => {
      'role': d['role'],
      'text': d['text'],
    }).toList();

    try {
      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse("$baseUrl/ai/advisor-chat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $idToken",
        },
        body: jsonEncode({
          "message": text,
          "history": history,
          "farmProfile": farmProfile,
          "location": locationName,
          "lat": lat,
          "lon": lon,
          "preferredLanguage": preferredLanguage ?? "English",
          "imageBase64": imageBase64,
          "imageMimeType": imageMimeType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['response'];

        // 3. Save AI Response
        await chatRef.add({
          'role': 'model',
          'senderId': 'minda_ai',
          'text': aiResponse,
          'createdAt': FieldValue.serverTimestamp(),
          'sentAt': FieldValue.serverTimestamp(),
          'status': 'read', // AI responses are "read" by default
        });
      } else {
        throw Exception("Server Error: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Minda had a connection issue: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isThinking = false);
    }
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('ai_farmer_chats')
        .doc(user.uid)
        .collection('messages')
        .doc(messageId);

    if (forEveryone) {
      // In AI chat, for everyone just marks it as deleted
      await docRef.update({
        'text': '🚫 This message was deleted',
        'isDeleted': true,
      });
    } else {
      await docRef.update({
        'deletedFor': FieldValue.arrayUnion([user.uid]),
      });
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE5DDD5),
    );
  }

  Future<void> _clearChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("This will permanently delete your conversation with Minda."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final chatRef = FirebaseFirestore.instance
          .collection('ai_farmer_chats')
          .doc(user.uid)
          .collection('messages');
      
      final messages = await chatRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Login required")));

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const AppGradient(),
        elevation: 2,
        foregroundColor: Colors.white,
        leadingWidth: 90,
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: AssetImage('assets/minda_avatar.png'),
            ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Minda Advisor",
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              "online",
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
                    builder: (context) => const ChatWallpaperPicker(
                      chatId: 'minda_advisor',
                      chatName: 'Minda Advisor',
                    ),
                  ),
                ).then((_) => _loadWallpaper());
              } else if (value == 'clear') {
                _clearChat();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: _buildWallpaperDecoration(),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ai_farmer_chats')
                    .doc(user.uid)
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final allMessages = snapshot.data!.docs;

                  // Filter out messages deleted for ME
                  final messages = allMessages.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final deletedFor = data['deletedFor'] as List?;
                    return deletedFor == null || !deletedFor.contains(user.uid);
                  }).toList();

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundImage: AssetImage('assets/minda_avatar.png'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Hello! I am Minda.\nHow can I help your farm today?",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 16, 
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[800]
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final data = msg.data() as Map<String, dynamic>;
                      final isMe = data['role'] == 'user';
                      final text = data['text'] ?? '';
                      final timestamp = (data['sentAt'] ?? data['createdAt']) as Timestamp?;
                      final status = data['status'] ?? 'sent';
                      // Use local path for temp preview, url for stored images
                      final imageLocalPath = data['imageLocalPath'] as String?;
                      final imageUrl = data['imageUrl'] as String?;
                      final displayImageUrl = imageUrl ?? (imageLocalPath != null ? 'file://$imageLocalPath' : null);
                      
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
                          imageUrl: displayImageUrl,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (_isThinking)
            Container(
              width: double.infinity,
              color: Colors.black12,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                "Minda is thinking...", 
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.blueGrey)
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() => _selectedImage = picked);
    }
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image preview strip
        if (_selectedImage != null)
          Container(
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                    ? Image.network(_selectedImage!.path, height: 80, width: 80, fit: BoxFit.cover)
                    : Image.file(io.File(_selectedImage!.path), height: 80, width: 80, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Image attached',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Text('Minda will analyse it 🌿', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => setState(() => _selectedImage = null),
                ),
              ],
            ),
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
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(
                            hintText: "Ask Minda anything...",
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(imageFile: _selectedImage),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          color: _selectedImage != null ? Colors.green : Colors.grey,
                        ),
                        onPressed: _pickImage,
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
                  onPressed: () => _sendMessage(imageFile: _selectedImage),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

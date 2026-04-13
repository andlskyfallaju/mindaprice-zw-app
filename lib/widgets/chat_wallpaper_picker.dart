import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/wallpaper_service.dart';
import '../widgets/app_gradient.dart';

class ChatWallpaperPicker extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const ChatWallpaperPicker({
    super.key, 
    this.chatId,
    this.chatName,
  });

  @override
  State<ChatWallpaperPicker> createState() => _ChatWallpaperPickerState();
}

class _ChatWallpaperPickerState extends State<ChatWallpaperPicker> {
  final List<Color> _solidColors = [
    const Color(0xFFE5DDD5), // Default Beige
    const Color(0xFFECE5DD), // Light Beige
    const Color(0xFFCFD8DC), // Blue Gray
    const Color(0xFFF8BBD0), // Pink
    const Color(0xFFC8E6C9), // Pale Green
    const Color(0xFFFFF9C4), // Pale Yellow
    const Color(0xFFB2EBF2), // Pale Cyan
    const Color(0xFFD1C4E9), // Pale Purple
    const Color(0xFF263238), // Dark Gray
    const Color(0xFF075E54), // WhatsApp Teal
    const Color(0xFF128C7E), // WhatsApp Light Teal
    const Color(0xFF25D366), // WhatsApp Green
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      await WallpaperService.setWallpaperImage(
        File(pickedFile.path),
        chatId: widget.chatId,
      );
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat wallpaper updated!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const AppGradient(),
        elevation: 2,
        foregroundColor: Colors.black87,
        title: Text(
          widget.chatName != null ? "Wallpaper: ${widget.chatName}" : "Chat Wallpaper",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionTile(
              icon: Icons.image_outlined,
              title: "Choose from Gallery",
              subtitle: "Select a custom photo from your phone",
              onTap: _pickImage,
            ),
            const SizedBox(height: 12),
            _buildSelectionTile(
              icon: Icons.refresh_outlined,
              title: "Reset to Default",
              subtitle: "Back to the standard background",
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                
                await WallpaperService.resetWallpaper(chatId: widget.chatId);
                
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Wallpaper reset to default.')),
                );
                navigator.pop();
              },
            ),
            const SizedBox(height: 30),
            Text(
              "Solid Colors",
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _solidColors.length,
              itemBuilder: (context, index) {
                final color = _solidColors[index];
                return GestureDetector(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    
                    await WallpaperService.setWallpaperColor(color, chatId: widget.chatId);
                    
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Wallpaper color updated!')),
                    );
                    navigator.pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              child: Icon(icon, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.black.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

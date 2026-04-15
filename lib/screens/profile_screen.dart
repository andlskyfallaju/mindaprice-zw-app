import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import 'package:image_picker/image_picker.dart';
import 'location_picker_screen.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = '';
  String email = '';
  String? photoUrl;
  String role = 'user';
  String accountType = 'farmer';
  String farmProfile = '';
  String phone = '';
  String location = '';
  String preferredLanguage = 'English';
  bool isLoading = true;
  bool isUpdating = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        username = (data['username'] ?? '').toString();
        email = (data['email'] ?? user.email ?? '').toString();
        photoUrl = data['photoUrl'] as String?;
        role = (data['role'] ?? 'user').toString();
        accountType = (data['accountType'] ?? 'farmer').toString();
        farmProfile = (data['farmProfile'] ?? '').toString();
        phone = (data['phone'] ?? '').toString();
        location = (data['location'] ?? '').toString();
        preferredLanguage = (data['preferredLanguage'] ?? 'English').toString();
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        email = user.email ?? '';
        isLoading = false;
      });
    }
  }

  Widget buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[300]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 20, color: Colors.green[300]),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Future<void> _updateUsername() async {
    final TextEditingController controller = TextEditingController(text: username);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Username", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new username"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != username) {
      if (!mounted) return;
      setState(() => isUpdating = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'username': newName,
          });
          if (!mounted) return;
          setState(() => username = newName);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username updated!")),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e")),
        );
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _updateFarmProfile() async {
    final TextEditingController controller = TextEditingController(text: farmProfile);
    
    final newProfile = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Farm Details", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "Describe your crops, livestock, acreage, etc.",
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newProfile != null && newProfile != farmProfile) {
      if (!mounted) return;
      setState(() => isUpdating = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'farmProfile': newProfile,
          });
          if (!mounted) return;
          setState(() => farmProfile = newProfile);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Farm details updated!")),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e")),
        );
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _updateLanguage() async {
    String? newLang = await showDialog<String>(
      context: context,
      builder: (context) {
        String selectedLang = preferredLanguage;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Select Language", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              content: DropdownButton<String>(
                value: selectedLang,
                isExpanded: true,
                items: ['English', 'Shona', 'Ndebele'].map((lang) {
                  return DropdownMenuItem(value: lang, child: Text(lang));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedLang = val);
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedLang),
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      },
    );

    if (newLang != null && newLang != preferredLanguage) {
      if (!mounted) return;
      setState(() => isUpdating = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'preferredLanguage': newLang,
          });
          if (mounted) setState(() => preferredLanguage = newLang);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Language updated!")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _updatePhone() async {
    final TextEditingController controller = TextEditingController(text: phone);
    final newPhone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Contact Number", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "Enter your phone number"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newPhone != null && newPhone != phone) {
      if (!mounted) return;
      setState(() => isUpdating = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({'phone': newPhone});
          if (mounted) setState(() => phone = newPhone);
        }
      } catch (_) {} finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _updateLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(),
      ),
    );

    if (result != null && result.locationName != location) {
      if (!mounted) return;
      setState(() => isUpdating = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'location': result.locationName,
            'latitude': result.location.latitude,
            'longitude': result.location.longitude,
          });
          if (mounted) setState(() => location = result.locationName);
        }
      } catch (_) {} finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
      );

      if (image == null) return;

      setState(() => isUpdating = true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final url = await CloudinaryService.uploadProfilePicture(image, uid);

      if (url == null) {
        throw Exception("Cloudinary upload failed.");
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': url,
      });

      if (!mounted) return;
      setState(() => photoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload image: $e")),
      );
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Widget buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[800],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text(
            "Profile",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        buildAvatar(),
                        const SizedBox(height: 18),
                        Text(
                          username.isNotEmpty ? username : 'MindaPrice User',
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 26),
                        buildInfoCard(
                          icon: Icons.person_outline,
                          title: 'Username',
                          value: username.isNotEmpty ? username : 'Not set',
                          onEdit: _updateUsername,
                        ),
                        buildInfoCard(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          value: email.isNotEmpty ? email : 'Not set',
                        ),
                        buildInfoCard(
                          icon: Icons.verified_user_outlined,
                          title: 'Account Role',
                          value: role.toUpperCase(),
                        ),
                        buildInfoCard(
                          icon: Icons.badge_outlined,
                          title: 'I am a...',
                          value: accountType.toUpperCase(),
                        ),
                        if (accountType.toLowerCase() == 'farmer')
                          buildInfoCard(
                            icon: Icons.agriculture_outlined,
                            title: 'Farm Details',
                            value: farmProfile.isNotEmpty ? farmProfile : 'Not set (tap to describe your farm)',
                            onEdit: _updateFarmProfile,
                          ),
                        buildInfoCard(
                          icon: Icons.phone_outlined,
                          title: 'Contact Number',
                          value: phone.isNotEmpty ? phone : 'Not set',
                          onEdit: _updatePhone,
                        ),
                        buildInfoCard(
                          icon: Icons.location_on_outlined,
                          title: 'Location',
                          value: location.isNotEmpty ? location : 'Not set',
                          onEdit: _updateLocation,
                        ),
                        buildInfoCard(
                          icon: Icons.language_outlined,
                          title: 'Preferred Language',
                          value: preferredLanguage,
                          onEdit: _updateLanguage,
                        ),
                      ],
                    ),
                  ),
                  if (isUpdating)
                    Container(
                      color: Colors.black45,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
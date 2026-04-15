import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../models/product.dart';
import '../services/user_service.dart';
import '../services/marketplace_service.dart';
import '../services/rating_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import 'chat_screen.dart';
import 'product_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerProfileScreen extends StatefulWidget {
  final String farmerId;
  final String farmerName;

  const FarmerProfileScreen({
    super.key,
    required this.farmerId,
    required this.farmerName,
  });

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final UserService _userService = UserService();
  final MarketplaceService _marketplaceService = MarketplaceService();
  bool _isLoading = true;
  MindaUser? _farmer;

  @override
  void initState() {
    super.initState();
    _loadFarmer();
  }

  Future<void> _loadFarmer() async {
    final user = await _userService.getUserProfile(widget.farmerId);
    if (mounted) {
      setState(() {
        _farmer = user;
        _isLoading = false;
      });
    }
  }

  void _showReportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Report User", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Reason for reporting..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _userService.reportUser(
                  reportedUid: widget.farmerId,
                  reason: controller.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User reported. Thank you.")),
                  );
                }
              }
            },
            child: const Text("Report", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppBackground(child: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    if (_farmer == null) {
      return AppBackground(child: Scaffold(body: Center(child: Text("User not found", style: GoogleFonts.montserrat()))));
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text("Farmer Profile", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            if (_farmer!.uid != FirebaseAuth.instance.currentUser?.uid)
              IconButton(
                icon: const Icon(Icons.report_problem_outlined, color: Colors.white),
                onPressed: _showReportDialog,
                tooltip: "Report User",
              ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 20),
              _buildContactSection(),
              const SizedBox(height: 25),
              _buildInventorySection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green[100],
                backgroundImage: _farmer!.photoUrl != null ? NetworkImage(_farmer!.photoUrl!) : null,
                child: _farmer!.photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.green) : null,
              ),
              if (_farmer!.isVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.verified, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _farmer!.username,
            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < _farmer!.ratingAverage.floor() ? Icons.star : Icons.star_border,
                  color: Colors.orange,
                  size: 20,
                );
              }),
              const SizedBox(width: 8),
              Text(
                "(${_farmer!.ratingCount} reviews)",
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          if (_farmer!.farmProfile.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _farmer!.farmProfile,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("Rating", _farmer!.ratingAverage.toStringAsFixed(1), Icons.star_outline),
          _buildStatItem("Joined", "${_farmer!.joinedAt.year}", Icons.calendar_today_outlined),
          _buildStatItem("Verified", _farmer!.isVerified ? "Yes" : "No", Icons.verified_outlined),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.green[300], size: 22),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildContactSection() {
    final bool isSelf = _farmer!.uid == FirebaseAuth.instance.currentUser?.uid;
    if (isSelf) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUserId: widget.farmerId,
                          otherUsername: widget.farmerName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text("Message"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_farmer!.phone != null) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => launchUrl(Uri.parse("tel:${_farmer!.phone}")),
                  icon: const Icon(Icons.phone),
                  color: Colors.green[800],
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showRatingDialog,
              icon: const Icon(Icons.star_outline, color: Colors.orange),
              label: const Text("Rate this Seller", style: TextStyle(color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Check if already rated
    final alreadyRated = await RatingService.hasRated(widget.farmerId);

    if (!mounted) return;

    if (alreadyRated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have already rated this seller.")),
      );
      return;
    }

    int selectedStars = 0;
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            "Rate ${_farmer!.username}",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Tap to select rating:", style: GoogleFonts.montserrat(fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedStars = i + 1),
                    child: Icon(
                      i < selectedStars ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Leave a comment (optional)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: selectedStars == 0
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await RatingService.submitRating(
                        toUid: widget.farmerId,
                        toUsername: widget.farmerName,
                        score: selectedStars,
                        comment: commentController.text.trim(),
                      );
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? "Rating submitted! Thank you ⭐"
                              : "You have already rated this seller."),
                        ),
                      );
                    },
              child: const Text("Submit", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Active Listings",
            style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Product>>(
          stream: _marketplaceService.getProductsBySeller(widget.farmerId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final products = snapshot.data!;

            if (products.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text("No active listings", style: GoogleFonts.montserrat(color: Colors.grey)),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product))),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: product.imageUrls.isNotEmpty
                              ? Image.network(product.imageUrls[0], fit: BoxFit.cover, width: double.infinity)
                              : Container(color: Colors.grey[200]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.title, maxLines: 1, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("USD ${product.price}", style: GoogleFonts.montserrat(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

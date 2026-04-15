import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../widgets/app_background.dart';
import '../widgets/app_gradient.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_screen.dart';
import 'farmer_profile_screen.dart';
import 'map_screen.dart';
import 'package:latlong2/latlong.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          flexibleSpace: const AppGradient(),
          elevation: 0,
          title: Text(
            "Product Details",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Carousel (Simple version for now)
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: product.imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: product.imageUrls.length,
                        itemBuilder: (context, index) {
                          return Image.network(
                            product.imageUrls[index],
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.title,
                            style: GoogleFonts.montserrat(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          "USD ${product.price.toStringAsFixed(2)}",
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.category,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.green[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.location,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            LatLng? explicitLocation;
                            if (product.latitude != null && product.longitude != null) {
                              explicitLocation = LatLng(product.latitude!, product.longitude!);
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MapScreen(
                                  locationString: product.location,
                                  title: product.title,
                                  exactLocation: explicitLocation,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map, size: 16),
                          label: const Text("View Map"),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Description",
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Seller Info
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FarmerProfileScreen(
                              farmerId: product.sellerId,
                              farmerName: product.sellerName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.green[100],
                              child: const Icon(Icons.person, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                      product.sellerName,
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('users').doc(product.sellerId).get(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) return const SizedBox.shrink();
                                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                                        final rating = data?['ratingAverage'] ?? 0.0;
                                        final count = data?['ratingCount'] ?? 0;
                                        
                                        if (count == 0) {
                                          return Text(
                                            "New Seller",
                                            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.greenAccent),
                                          );
                                        }

                                        return Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${rating.toStringAsFixed(1)} ($count reviews)",
                                              style: GoogleFonts.montserrat(
                                                fontSize: 12,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            if (product.sellerId != FirebaseAuth.instance.currentUser?.uid)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        otherUserId: product.sellerId,
                                        otherUsername: product.sellerName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: const Text("Chat"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[800],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../models/product.dart';
import 'cloudinary_service.dart';

class MarketplaceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // Fetch all active products
  Stream<List<Product>> getProducts() {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Fetch all products for a specific seller (server-side filter)
  Stream<List<Product>> getProductsBySeller(String sellerId) {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'active')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Fetch products by category
  Stream<List<Product>> getProductsByCategory(String category) {
    return _db
        .collection('products')
        .where('status', isEqualTo: 'active')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList());
  }

  // Add a new product listing
  Future<String?> addProduct({
    required String title,
    required String description,
    required double price,
    required String category,
    required List<XFile> images,
    required String location,
    double? latitude,
    double? longitude,
  }) async {
    final uid = currentUid;
    if (uid == null) return "Not authenticated";

    try {
      // 1. Fetch user info for the listing
      final userDoc = await _db.collection('users').doc(uid).get();
      final sellerName = userDoc.data()?['username'] ?? 'User';

      // 2. Upload images to Cloudinary
      List<String> imageUrls = [];
      for (var imageFile in images) {
        final url = await CloudinaryService.uploadProductImage(imageFile, uid);
        if (url != null) imageUrls.add(url);
      }

      if (imageUrls.isEmpty && images.isNotEmpty) {
        return "Failed to upload images";
      }

      // 3. Create product document
      await _db.collection('products').add({
        'title': title,
        'description': description,
        'price': price,
        'category': category,
        'imageUrls': imageUrls,
        'sellerId': uid,
        'sellerName': sellerName,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  // Mark product as sold
  Future<void> markAsSold(String productId) async {
    await _db.collection('products').doc(productId).update({'status': 'sold'});
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    await _db.collection('products').doc(productId).delete();
  }
}

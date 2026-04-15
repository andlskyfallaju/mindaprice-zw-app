import 'package:cloud_firestore/cloud_firestore.dart';

class MindaUser {
  final String uid;
  final String username;
  final String email;
  final String? photoUrl;
  final String accountType; // 'farmer', 'buyer', 'admin'
  final String farmProfile;
  final String? phone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool isVerified;
  final double ratingAverage;
  final int ratingCount;
  final DateTime joinedAt;

  MindaUser({
    required this.uid,
    required this.username,
    required this.email,
    this.photoUrl,
    required this.accountType,
    required this.farmProfile,
    this.phone,
    this.location,
    this.latitude,
    this.longitude,
    this.isVerified = false,
    this.ratingAverage = 0.0,
    this.ratingCount = 0,
    required this.joinedAt,
  });

  factory MindaUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MindaUser(
      uid: doc.id,
      username: data['username'] ?? 'User',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      accountType: data['accountType'] ?? 'farmer',
      farmProfile: data['farmProfile'] ?? '',
      phone: data['phone'],
      location: data['location'],
      latitude: data['latitude'] != null ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] != null ? (data['longitude'] as num).toDouble() : null,
      isVerified: data['isVerified'] == true || data['isVerified'] == 'true',
      ratingAverage: double.tryParse(data['ratingAverage']?.toString() ?? '0.0') ?? 0.0,
      ratingCount: int.tryParse(data['ratingCount']?.toString() ?? '0') ?? 0,
      joinedAt: (data['joinedAt'] is Timestamp 
          ? (data['joinedAt'] as Timestamp).toDate() 
          : (data['createdAt'] is Timestamp 
              ? (data['createdAt'] as Timestamp).toDate() 
              : DateTime.now())),
    );
  }
}

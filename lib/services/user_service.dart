import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<MindaUser?> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return MindaUser.fromFirestore(doc);
    } catch (e, stack) {
      debugPrint('Error loading user profile: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  Future<void> reportUser({
    required String reportedUid,
    required String reason,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _db.collection('reports').add({
      'reporterUid': currentUser.uid,
      'reportedUid': reportedUid,
      'reason': reason,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

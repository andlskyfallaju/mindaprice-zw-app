import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  static final _db = FirebaseFirestore.instance;

  /// Submit a rating from the current user to [toUid].
  /// Returns true on success, false if they already rated this user.
  static Future<bool> submitRating({
    required String toUid,
    required String toUsername,
    required int score,
    String comment = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Prevent duplicate ratings: one rating per fromUid→toUid pair
    final existing = await _db
        .collection('ratings')
        .where('fromUid', isEqualTo: user.uid)
        .where('toUid', isEqualTo: toUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return false;

    final batch = _db.batch();

    // Write the rating record
    final ratingRef = _db.collection('ratings').doc();
    batch.set(ratingRef, {
      'fromUid': user.uid,
      'toUid': toUid,
      'toUsername': toUsername,
      'score': score,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Update the cached average on the user's document (non-blocking)
    _recalculateAverage(toUid);

    return true;
  }

  /// Fetches the average rating and count for a given user.
  static Future<Map<String, dynamic>> getRatingSummary(String uid) async {
    final snap = await _db
        .collection('ratings')
        .where('toUid', isEqualTo: uid)
        .get();

    if (snap.docs.isEmpty) return {'average': 0.0, 'count': 0};

    final total = snap.docs.fold<int>(0, (totalSum, d) => totalSum + (d['score'] as int));
    final average = total / snap.docs.length;
    return {'average': average, 'count': snap.docs.length};
  }

  /// Checks if the current user has already rated [toUid].
  static Future<bool> hasRated(String toUid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final snap = await _db
        .collection('ratings')
        .where('fromUid', isEqualTo: user.uid)
        .where('toUid', isEqualTo: toUid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Recalculates and caches the average rating on the user's document.
  static Future<void> _recalculateAverage(String uid) async {
    try {
      final summary = await getRatingSummary(uid);
      await _db.collection('users').doc(uid).update({
        'ratingAverage': summary['average'],
        'ratingCount': summary['count'],
      });
    } catch (_) {}
  }
}

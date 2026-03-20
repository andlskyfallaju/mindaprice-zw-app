import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // Search users by username (case-insensitive search is tricky in Firestore, 
  // usually requires a lowercase field, but we'll do a simple prefix search for now)
  Stream<QuerySnapshot> searchUsers(String query) {
    return _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots();
  }

  Future<void> sendChatRequest(String toUid, String toUsername) async {
    final fromUid = currentUid;
    if (fromUid == null) return;

    final fromDoc = await _db.collection('users').doc(fromUid).get();
    final fromUsername = fromDoc.data()?['username'] ?? 'User';

    final requestId = "${fromUid}_$toUid";
    
    await _db.collection('chat_requests').doc(requestId).set({
      'fromUid': fromUid,
      'toUid': toUid,
      'fromUsername': fromUsername,
      'toUsername': toUsername,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptChatRequest(String fromUid, String fromUsername) async {
    final toUid = currentUid;
    if (toUid == null) return;

    final toDoc = await _db.collection('users').doc(toUid).get();
    final toUsername = toDoc.data()?['username'] ?? 'User';

    final requestId = "${fromUid}_$toUid";

    final batch = _db.batch();

    // 1. Mark request as accepted (or delete it)
    batch.delete(_db.collection('chat_requests').doc(requestId));

    // 2. Add to current user's contacts
    batch.set(_db.collection('users').doc(toUid).collection('contacts').doc(fromUid), {
      'uid': fromUid,
      'username': fromUsername,
      'status': 'accepted',
      'addedAt': FieldValue.serverTimestamp(),
    });

    // 3. Add current user to sender's contacts
    batch.set(_db.collection('users').doc(fromUid).collection('contacts').doc(toUid), {
      'uid': toUid,
      'username': toUsername,
      'status': 'accepted',
      'addedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineChatRequest(String fromUid) async {
    final toUid = currentUid;
    if (toUid == null) return;
    final requestId = "${fromUid}_$toUid";
    await _db.collection('chat_requests').doc(requestId).delete();
  }

  Stream<QuerySnapshot> getIncomingRequests() {
    return _db
        .collection('chat_requests')
        .where('toUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot> getContacts() {
    return _db
        .collection('users')
        .doc(currentUid)
        .collection('contacts')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }
}

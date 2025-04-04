import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> deleteUserDataOnly() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in.');

    final userDoc = _db.collection('users').doc(user.uid);

    // 1. Delete subcollections
    final subcollections = ['symptoms', 'cleaningLogs', 'sensorData'];
    for (final sub in subcollections) {
      final snapshots = await userDoc.collection(sub).get();
      for (final doc in snapshots.docs) {
        await doc.reference.delete();
      }
    }
  }
}

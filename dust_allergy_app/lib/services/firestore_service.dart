import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addSymptom(String userId, SymptomEntry entry) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('symptoms')
        .add(entry.toMap());
  }


  Future<void> addCleaning(String userId, CleaningEntry entry) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('cleaningLogs')
        .add(entry.toMap());
  }

  Future<void> createUserProfile({
    required String userId,
    required String? email,
    required String? name,
  }) async {
    final userDoc = _db.collection('users').doc(userId);

    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'profile': {
          'name': name ?? '',
          'email': email ?? '',
          'allergySeverity': '',
          'otherPreferences': {},
        },
      });
    }
  }

}

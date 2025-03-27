import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/symptom_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addSymptom(String userId, SymptomEntry entry) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('symptoms')
        .add(entry.toMap());
  }

}

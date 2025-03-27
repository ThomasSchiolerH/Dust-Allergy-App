import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/symptom_entry.dart';

class SymptomLogScreen extends StatefulWidget {
  const SymptomLogScreen({super.key});

  @override
  _SymptomLogScreenState createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  int _severity = 1;
  final _descController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  void _submitEntry() async {
    User? user = FirebaseAuth.instance.currentUser;

    // Sign in anonymously if not already signed in
    if (user == null) {
      try {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;
        print('Signed in anonymously as: ${user?.uid}');
      } catch (e) {
        print('Anonymous sign-in failed: $e');
        return;
      }
    }

    if (user != null) {
      final entry = SymptomEntry(
        date: DateTime.now(),
        severity: _severity,
        description: _descController.text,
      );
      try {
        await _firestoreService.addSymptom(user.uid, entry);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom logged!')),
        );
      } catch (e) {
        print('Failed to log symptom: $e');
      }
      _descController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Today\'s Symptoms')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Severity (1-5): $_severity', style: const TextStyle(fontSize: 18)),
            Slider(
              value: _severity.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: _severity.toString(),
              onChanged: (value) {
                setState(() {
                  _severity = value.toInt();
                });
              },
            ),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Optional notes'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitEntry,
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

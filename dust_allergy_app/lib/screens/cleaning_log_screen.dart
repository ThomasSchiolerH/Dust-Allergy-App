import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/cleaning_entry.dart';

class CleaningLogScreen extends StatefulWidget {
  const CleaningLogScreen({super.key});

  @override
  State<CleaningLogScreen> createState() => _CleaningLogScreenState();
}

class _CleaningLogScreenState extends State<CleaningLogScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _windowOpened = false;
  int _windowDuration = 0;
  bool _vacuumed = false;
  bool _floorWashed = false;
  bool _bedsheetsWashed = false;
  bool _clothesOnFloor = false;

  void _submitCleaning() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;
      } catch (e) {
        return;
      }
    }

    if (user != null) {
      final entry = CleaningEntry(
        date: DateTime.now(),
        windowOpened: _windowOpened,
        windowDuration: _windowOpened ? _windowDuration : 0,
        vacuumed: _vacuumed,
        floorWashed: _floorWashed,
        bedsheetsWashed: _bedsheetsWashed,
        clothesOnFloor: _clothesOnFloor,
      );

      try {
        await _firestoreService.addCleaning(user.uid, entry);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cleaning log saved!')),
        );
        setState(() {
          _windowOpened = false;
          _windowDuration = 0;
          _vacuumed = false;
          _floorWashed = false;
          _bedsheetsWashed = false;
          _clothesOnFloor = false;
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Cleaning Activity')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Opened window for fresh air?'),
              value: _windowOpened,
              onChanged: (value) => setState(() => _windowOpened = value),
            ),
            if (_windowOpened)
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'How many minutes?'),
                onChanged: (val) {
                  setState(() {
                    _windowDuration = int.tryParse(val) ?? 0;
                  });
                },
              ),
            CheckboxListTile(
              title: const Text('Vacuum cleaned room'),
              value: _vacuumed,
              onChanged: (val) => setState(() => _vacuumed = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Washed floor'),
              value: _floorWashed,
              onChanged: (val) => setState(() => _floorWashed = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Washed bed sheets'),
              value: _bedsheetsWashed,
              onChanged: (val) => setState(() => _bedsheetsWashed = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Clothes laying on floor'),
              value: _clothesOnFloor,
              onChanged: (val) => setState(() => _clothesOnFloor = val ?? false),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitCleaning,
              child: const Text('Save Cleaning Log'),
            ),
          ],
        ),
      ),
    );
  }
}

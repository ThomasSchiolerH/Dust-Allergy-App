import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/symptom_entry.dart';
import 'package:intl/intl.dart';


class SymptomLogScreen extends StatefulWidget {
  const SymptomLogScreen({super.key});

  @override
  State<SymptomLogScreen> createState() => _SymptomLogScreenState();
}

class _SymptomLogScreenState extends State<SymptomLogScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _congestion = false;
  bool _itchingEyes = false;
  bool _headache = false;

  int _severity = 1;
  final _descController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  void _submitEntry() async {
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
      final entry = SymptomEntry(
        date: _selectedDate,
        severity: _severity,
        description: _descController.text,
        congestion: _congestion,
        itchingEyes: _itchingEyes,
        headache: _headache,
      );
      try {
        await _firestoreService.addSymptom(user.uid, entry);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom logged!')),
        );
        _descController.clear();
      } catch (_) {}
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
              onChanged: (value) => setState(() => _severity = value.toInt()),
            ),
            ListTile(
              title: Text("Selected: ${_formatDateTime(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_selectedDate),
                  );
                  if (pickedTime != null) {
                    setState(() {
                      _selectedDate = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );
                    });
                  }
                }
              },
            ),

            CheckboxListTile(
              title: const Text('Congestion'),
              value: _congestion,
              onChanged: (val) => setState(() => _congestion = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Itching Eyes'),
              value: _itchingEyes,
              onChanged: (val) => setState(() => _itchingEyes = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Headache'),
              value: _headache,
              onChanged: (val) => setState(() => _headache = val ?? false),
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
String _formatDateTime(DateTime dateTime) {
  return DateFormat('EEE, MMM d, y - h:mm a').format(dateTime);
}

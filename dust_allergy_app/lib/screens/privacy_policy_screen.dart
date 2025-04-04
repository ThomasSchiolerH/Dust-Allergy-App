import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This app collects and processes your data in accordance with the General Data Protection Regulation (GDPR). By using the Dust Allergy Tracker app, you agree to the practices outlined in this policy.',
            ),
            const SizedBox(height: 24),
            const Text(
              '1. Data Controller',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'The data controller responsible for your information is the research group at Danmarks Tekniske Universitet (DTU). Contact: s214963@dtu.dk.',
            ),
            const SizedBox(height: 16),
            const Text(
              '2. Data We Collect',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'We collect personal data including:\n- Name and email (if signed in)\n- Symptom reports\n- Cleaning activity logs\n- Sensor data (humidity, dust, temperature)',
            ),
            const SizedBox(height: 16),
            const Text(
              '3. Purpose of Data Use',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'We use your data to help identify allergy triggers, recommend cleaning routines, and visualize correlations between symptoms and environment.',
            ),
            const SizedBox(height: 16),
            const Text(
              '4. Data Sharing',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'We do not share your data with third parties. Only anonymized, aggregate results may be used in research.',
            ),
            const SizedBox(height: 16),
            const Text(
              '5. Your Rights',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'You have the right to:\n- Access your data\n- Correct inaccuracies\n- Delete your account and data\n- Withdraw your consent\n- File a complaint with your local data protection authority',
            ),
            const SizedBox(height: 16),
            const Text(
              '6. Data Retention',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Your data is stored until you delete your account or withdraw consent. You can request deletion at any time.',
            ),
            const SizedBox(height: 16),
            const Text(
              '7. Contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'For privacy questions or to exercise your rights, contact us at: s214963@dtu.dk',
            ),
            const SizedBox(height: 24),
            const Text(
              'Thank you for trusting Dust Allergy Tracker to improve your daily life.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            const Text('Advanced',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
              'If you would like to delete all your data permanently, you can do so below. '
              'This action is irreversible.',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete My Data'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Your Data?'),
        content: const Text(
          'Before you delete your data, would you like to export it for your own records?',
        ),
        actions: [
          TextButton(
            child: const Text('Export First'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _exportData(context);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Now'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _deleteUser(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(BuildContext context) async {
    final userService = UserService();
    try {
      await userService.deleteUserDataOnly();

      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Your account and personal data have been cleared.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting data: $e')),
        );
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      final profileSnap = await userDoc.get();
      final profile = profileSnap.data()?['profile'] ?? {};

      final symptomsSnap = await userDoc.collection('symptoms').get();
      final cleaningSnap = await userDoc.collection('cleaningLogs').get();

      final symptoms = symptomsSnap.docs.map((d) {
        final data = d.data();
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      final cleaning = cleaningSnap.docs.map((d) {
        final data = d.data();
        if (data['date'] is Timestamp) {
          data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      final export = {
        'profile': profile,
        'symptoms': symptoms,
        'cleaningLogs': cleaning,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(export);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'allergy_data_export_$timestamp.json';
      final file = File('${dir.path}/$filename');

      await file.writeAsString(jsonString);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export Complete'),
            content: const Text('Your data has been saved as a JSON file.'),
            actions: [
              TextButton(
                child: const Text('Open'),
                onPressed: () {
                  Navigator.pop(context);
                  OpenFilex.open(file.path);
                },
              ),
              TextButton(
                child: const Text('Share'),
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(file.path)],
                      text: 'Here is my allergy data export');
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

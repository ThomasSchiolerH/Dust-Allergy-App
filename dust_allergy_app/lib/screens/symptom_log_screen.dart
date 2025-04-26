import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/symptom_entry.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/notification_service.dart';

TimeOfDay? _reminderTime;

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
  bool _isSubmitting = false;

  int _severity = 1;
  final _descController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  void _submitEntry() async {
    setState(() {
      _isSubmitting = true;
    });

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
    }

    if (user != null) {
      final entry = SymptomEntry(
        date: _selectedDate,
        createdAt: DateTime.now(),
        severity: _severity,
        description: _descController.text,
        congestion: _congestion,
        itchingEyes: _itchingEyes,
        headache: _headache,
      );
      try {
        await _firestoreService.addSymptom(user.uid, entry);
        _showMessage('Symptom logged!');
        _descController.clear();
        setState(() {
          _congestion = false;
          _itchingEyes = false;
          _headache = false;
          _severity = 1;
        });
      } catch (e) {
        _showMessage('Error: Unable to log symptom');
      }
    }

    setState(() {
      _isSubmitting = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Log Symptoms'),
              background: Container(
                color: isDark
                    ? theme.cardColor
                    : theme.primaryColor.withOpacity(0.05),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                      context, 'When did you experience symptoms?'),
                  _buildDateTimeCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Symptom Severity'),
                  _buildSeverityCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Symptoms Experienced'),
                  _buildSymptomsCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Additional Notes'),
                  _buildNotesCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Reminders'),
                  _buildReminderCard(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, y').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityCard() {
    final List<Color> severityColors = [
      Colors.green,
      Colors.lightGreen,
      Colors.amber,
      Colors.orange,
      Colors.redAccent,
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Current Severity: ',
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),
                  TextSpan(
                    text: '$_severity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: severityColors[_severity - 1],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: severityColors[_severity - 1],
                inactiveTrackColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white24
                        : Colors.black12,
                thumbColor: severityColors[_severity - 1],
                overlayColor: severityColors[_severity - 1].withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _severity.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (value) => setState(() => _severity = value.toInt()),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mild',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black45,
                  ),
                ),
                Text(
                  'Severe',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _buildSymptomTile(
              'Nasal Congestion',
              Icons.sick,
              _congestion,
              (value) => setState(() => _congestion = value ?? false),
            ),
            _buildSymptomTile(
              'Itching Eyes',
              Icons.remove_red_eye,
              _itchingEyes,
              (value) => setState(() => _itchingEyes = value ?? false),
            ),
            _buildSymptomTile(
              'Headache',
              Icons.person,
              _headache,
              (value) => setState(() => _headache = value ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomTile(
      String title, IconData icon, bool value, ValueChanged<bool?> onChanged) {
    return CheckboxListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: value
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.black45,
          size: 20,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Any additional notes about your symptoms...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );

          if (pickedTime != null) {
            setState(() => _reminderTime = pickedTime);

            final now = DateTime.now();
            final scheduled = DateTime(
              now.year,
              now.month,
              now.day,
              pickedTime.hour,
              pickedTime.minute,
            );

            await NotificationService.scheduleDailyReminder(
              id: 1,
              title: 'Allergy Tracker',
              body: "Don't forget to log today's symptoms.",
              scheduledTime: scheduled,
            );

            _showMessage('Reminder set for ${pickedTime.format(context)}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_none,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Reminder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reminderTime != null
                          ? 'Set for ${_reminderTime!.format(context)}'
                          : 'Tap to set a daily reminder',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54
                    : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitEntry,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Save Symptom Log'),
      ),
    );
  }
}

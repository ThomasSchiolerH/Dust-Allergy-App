import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/cleaning_entry.dart';
import 'package:intl/intl.dart';

class CleaningLogScreen extends StatefulWidget {
  const CleaningLogScreen({super.key});

  @override
  State<CleaningLogScreen> createState() => _CleaningLogScreenState();
}

class _CleaningLogScreenState extends State<CleaningLogScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now();
  bool _windowOpened = false;
  int _windowDuration = 0;
  bool _vacuumed = false;
  bool _floorWashed = false;
  bool _bedsheetsWashed = false;
  bool _clothesOnFloor = false;
  bool _isSubmitting = false;
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  void _submitCleaning() async {
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
      final entry = CleaningEntry(
        date: _selectedDate,
        windowOpened: _windowOpened,
        windowDuration: _windowOpened ? _windowDuration : 0,
        vacuumed: _vacuumed,
        floorWashed: _floorWashed,
        bedsheetsWashed: _bedsheetsWashed,
        clothesOnFloor: _clothesOnFloor,
      );

      try {
        await _firestoreService.addCleaning(user.uid, entry);
        _showMessage('Cleaning log saved!');
        setState(() {
          _windowOpened = false;
          _windowDuration = 0;
          _durationController.clear();
          _vacuumed = false;
          _floorWashed = false;
          _bedsheetsWashed = false;
          _clothesOnFloor = false;
        });
      } catch (e) {
        _showMessage('Error: Unable to save cleaning log');
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
              title: const Text('Log Cleaning'),
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
                  _buildSectionHeader(context, 'When did you clean?'),
                  _buildDateTimeCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Cleaning Activities'),
                  _buildCleaningCard(),
                  const SizedBox(height: 24),
                  _buildWindowSection(),
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

  Widget _buildCleaningCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            _buildCleaningTile(
              'Vacuum Cleaned',
              Icons.cleaning_services_outlined,
              _vacuumed,
              (value) => setState(() => _vacuumed = value ?? false),
            ),
            _buildCleaningTile(
              'Floor Washed',
              Icons.opacity_outlined,
              _floorWashed,
              (value) => setState(() => _floorWashed = value ?? false),
            ),
            _buildCleaningTile(
              'Bed Sheets Washed',
              Icons.bed_outlined,
              _bedsheetsWashed,
              (value) => setState(() => _bedsheetsWashed = value ?? false),
            ),
            _buildCleaningTile(
              'Clothes on Floor',
              Icons.checkroom_outlined,
              _clothesOnFloor,
              (value) => setState(() => _clothesOnFloor = value ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleaningTile(
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

  Widget _buildWindowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Window Ventilation'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Opened window for fresh air',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  value: _windowOpened,
                  onChanged: (value) => setState(() => _windowOpened = value),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _windowOpened
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1)
                          : Theme.of(context).brightness == Brightness.dark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.window_outlined,
                      color: _windowOpened
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).brightness == Brightness.dark
                              ? Colors.white54
                              : Colors.black45,
                      size: 20,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                ),
                if (_windowOpened) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'How many minutes?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixText: 'minutes',
                      ),
                      onChanged: (val) {
                        setState(() {
                          _windowDuration = int.tryParse(val) ?? 0;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitCleaning,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Save Cleaning Log'),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  return DateFormat('EEE, MMM d, y - h:mm a').format(dateTime);
}

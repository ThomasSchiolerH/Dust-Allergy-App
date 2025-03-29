// widgets/bottom_nav_wrapper.dart
import 'package:flutter/material.dart';
import '../screens/symptom_log_screen.dart';
import '../screens/cleaning_log_screen.dart';
import '../screens/dashboard_screen.dart';

class BottomNavWrapper extends StatefulWidget {
  final int selectedIndex;

  const BottomNavWrapper({super.key, this.selectedIndex = 0});

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const SymptomLogScreen(),
    const CleaningLogScreen(),
    const DashboardScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => BottomNavWrapper(selectedIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sick),
            label: 'Symptoms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cleaning_services),
            label: 'Cleaning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

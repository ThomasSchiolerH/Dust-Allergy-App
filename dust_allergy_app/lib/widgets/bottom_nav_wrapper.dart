import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/symptom_log_screen.dart';
import '../screens/cleaning_log_screen.dart';
import '../screens/dashboard_screen.dart';
import '../widgets/auth_gate.dart';
import '../screens/privacy_policy_screen.dart';

class BottomNavWrapper extends StatefulWidget {
  final int selectedIndex;

  const BottomNavWrapper({super.key, this.selectedIndex = 0});

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  late int _currentIndex;

  final List<Map<String, dynamic>> _tabs = [
    {
      'title': 'Symptom Log',
      'screen': const SymptomLogScreen(),
    },
    {
      'title': 'Cleaning Log',
      'screen': const CleaningLogScreen(),
    },
    {
      'title': 'Dashboard',
      'screen': const DashboardScreen(),
    },
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(tab['title']),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'privacy') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'privacy',
                child: Text('Privacy Policy'),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          )
        ],
      ),
      body: tab['screen'],
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

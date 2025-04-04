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
      'icon': Icons.sick_outlined,
      'activeIcon': Icons.sick,
    },
    {
      'title': 'Cleaning Log',
      'screen': const CleaningLogScreen(),
      'icon': Icons.cleaning_services_outlined,
      'activeIcon': Icons.cleaning_services,
    },
    {
      'title': 'Dashboard',
      'screen': const DashboardScreen(),
      'icon': Icons.insights_outlined,
      'activeIcon': Icons.insights,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(tab['title']),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('Privacy Policy'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout_outlined),
                        title: const Text('Logout'),
                        onTap: () {
                          Navigator.pop(context);
                          _logout();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: tab['screen'],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                final isSelected = index == _currentIndex;
                return _buildNavItem(
                  icon: isSelected
                      ? _tabs[index]['activeIcon']
                      : _tabs[index]['icon'],
                  label: _tabs[index]['label'] ??
                      _tabs[index]['title'].toString().split(' ')[0],
                  isSelected: isSelected,
                  onTap: () => _onTabTapped(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.brightness == Brightness.dark
            ? const Color(0xFFAAAAAA)
            : const Color(0xFF999999);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

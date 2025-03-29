import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';
import 'dart:math';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SymptomEntry> _symptomEntries = [];
  List<CleaningEntry> _cleaningEntries = [];
  List<String> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final symptomsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('symptoms')
        .orderBy('date')
        .get();

    final cleaningSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cleaningLogs')
        .orderBy('date')
        .get();

    setState(() {
      _symptomEntries = symptomsSnapshot.docs.map((doc) {
        final data = doc.data();
        return SymptomEntry(
          date: (data['date'] as Timestamp).toDate(),
          severity: data['severity'],
          description: data['description'],
        );
      }).toList();

      _cleaningEntries = cleaningSnapshot.docs.map((doc) {
        final data = doc.data();
        return CleaningEntry(
          date: (data['date'] as Timestamp).toDate(),
          windowOpened: data['windowOpened'],
          windowDuration: data['windowDuration'],
          vacuumed: data['vacuumed'],
          floorWashed: data['floorWashed'],
          bedsheetsWashed: data['bedsheetsWashed'],
          clothesOnFloor: data['clothesOnFloor'],
        );
      }).toList();

      _generateRecommendations();
    });
  }

  List<FlSpot> _buildSymptomSpots() {
    return _symptomEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.severity.toDouble());
    }).toList();
  }

  List<VerticalLine> _buildCleaningMarkers() {
    List<VerticalLine> markers = [];
    for (int i = 0; i < _symptomEntries.length; i++) {
      final date = _symptomEntries[i].date;
      final hadCleaning = _cleaningEntries.any((c) =>
          c.date.year == date.year &&
          c.date.month == date.month &&
          c.date.day == date.day);
      if (hadCleaning) {
        markers.add(
          VerticalLine(
            x: i.toDouble(),
            color: Colors.greenAccent,
            strokeWidth: 1,
            dashArray: [4, 4], // Optional: Defines a dashed line pattern
          ),
        );
      }
    }
    return markers;
  }

  void _generateRecommendations() {
    if (_symptomEntries.length < 3 || _cleaningEntries.length < 1) return;

    final recent = _symptomEntries.sublist(max(0, _symptomEntries.length - 5));
    final avgSeverity =
        recent.map((e) => e.severity).reduce((a, b) => a + b) / recent.length;
    final lastCleaningDate = _cleaningEntries.last.date;
    final daysSinceLastClean =
        DateTime.now().difference(lastCleaningDate).inDays;

    _recommendations.clear();

    if (daysSinceLastClean >= 3 && avgSeverity >= 3) {
      _recommendations
          .add("Try cleaning every 2–3 days to reduce symptom spikes.");
    }
    if (_cleaningEntries.last.vacuumed == false) {
      _recommendations.add("Vacuuming may help improve symptoms.");
    }
    if (_cleaningEntries.last.windowOpened == false) {
      _recommendations.add(
          "Try opening windows briefly to circulate air (if weather allows).");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _symptomEntries.isEmpty
            ? const Center(child: Text('No data to display'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Symptom Severity Over Time',
                        style: TextStyle(fontSize: 18)),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _buildSymptomSpots(),
                              isCurved: true,
                              dotData: FlDotData(show: true),
                            ),
                          ],
                          extraLinesData: ExtraLinesData(
                              verticalLines: _buildCleaningMarkers()),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Recent Cleaning Events',
                        style: TextStyle(fontSize: 18)),
                    ..._cleaningEntries.reversed
                        .take(5)
                        .map((entry) => ListTile(
                              title: Text(entry.date
                                  .toLocal()
                                  .toString()
                                  .split(" ")[0]),
                              subtitle: Text(_formatCleaningSummary(entry)),
                            )),
                    const SizedBox(height: 24),
                    const Text('Recommendations',
                        style: TextStyle(fontSize: 18)),
                    if (_recommendations.isEmpty)
                      const Text("No suggestions at the moment.")
                    else
                      ..._recommendations.map((rec) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 18, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                Expanded(child: Text(rec)),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatCleaningSummary(CleaningEntry entry) {
    List<String> activities = [];
    if (entry.vacuumed) activities.add("Vacuumed");
    if (entry.floorWashed) activities.add("Floor Washed");
    if (entry.bedsheetsWashed) activities.add("Bed Sheets Washed");
    if (entry.clothesOnFloor) activities.add("Clothes on Floor");
    if (entry.windowOpened)
      activities.add("Window Opened (\${entry.windowDuration} min)");
    return activities.join(", ");
  }
}

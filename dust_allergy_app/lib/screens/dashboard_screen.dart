import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SymptomEntry> _symptomEntries = [];
  List<CleaningEntry> _cleaningEntries = [];
  List<String> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

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
      _isLoading = false;
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
            dashArray: [4, 4],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _symptomEntries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 120,
                        pinned: true,
                        flexibleSpace: FlexibleSpaceBar(
                          title: const Text('Insights'),
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
                                  context, 'Symptom Severity Over Time'),
                              _buildChartCard(),
                              const SizedBox(height: 24),
                              _buildSectionHeader(
                                  context, 'Recent Cleaning Events'),
                              _buildCleaningEventsList(),
                              const SizedBox(height: 24),
                              _buildSectionHeader(context, 'Recommendations'),
                              _buildRecommendationsList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Data Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Log symptoms and cleaning events to see insights',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: _buildSymptomSpots(),
                  isCurved: true,
                  dotData: FlDotData(show: true),
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
              extraLinesData: ExtraLinesData(
                verticalLines: _buildCleaningMarkers(),
              ),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 ||
                          index >= _symptomEntries.length ||
                          index % 5 != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          DateFormat('MMM d')
                              .format(_symptomEntries[index].date),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value % 1 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleaningEventsList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_cleaningEntries.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No cleaning events recorded yet',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: _cleaningEntries.reversed
              .take(5)
              .map((entry) => ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.cleaning_services_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          DateFormat.MMMd().format(entry.date),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.jm().format(entry.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(_formatCleaningSummary(entry)),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildRecommendationsList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_recommendations.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No suggestions at the moment',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _recommendations
              .map((rec) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.tips_and_updates_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rec,
                            style: TextStyle(
                              height: 1.3,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  String _formatCleaningSummary(CleaningEntry entry) {
    List<String> activities = [];
    if (entry.vacuumed) activities.add("Vacuumed");
    if (entry.floorWashed) activities.add("Floor Washed");
    if (entry.bedsheetsWashed) activities.add("Bed Sheets Washed");
    if (entry.windowOpened) {
      activities.add("Window Opened (${entry.windowDuration} min)");
    }
    if (entry.clothesOnFloor) activities.add("Clothes on Floor");

    return activities.join(" • ");
  }
}

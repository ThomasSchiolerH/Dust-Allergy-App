import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:collection';
import '../services/ai_service.dart';
import '../screens/ai_chat_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
// import '../widgets/combined_line_cleaning_chart.dart';
import '../widgets/cleaning_effect_chart.dart';
import '../widgets/event_effect_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SymptomEntry> _symptomEntries = [];
  List<CleaningEntry> _cleaningEntries = [];
  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = true;
  bool _isLoadingAI = false;

  // Data analysis fields
  Map<String, List<double>> _symptomTypeTrends = {};
  Map<String, double> _cleaningImpactScores = {};
  Map<String, int> _timeOfDaySymptomCounts = {
    'Morning': 0,
    'Afternoon': 0,
    'Evening': 0,
    'Night': 0
  };
  String _selectedTimeframe = 'Last 30 days';

  // Filter options
  final List<String> _timeframeOptions = [
    'Last 7 days',
    'Last 30 days',
    'Last 3 months',
    'All time'
  ];

  // Add a field to track the selected chart
  String _selectedChart = 'Symptom Severity Over Time';

  // Define chart options
  final List<String> _chartOptions = [
    'Symptom Severity Over Time',
    'Before vs. After Cleaning Effect',
    'Symptom Analysis',
    'Cleaning Impact',
    'Time of Day Patterns',
  ];

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
        // parse required date
        final dateTs = data['date'] as Timestamp;
        final date = dateTs.toDate();
        // safely parse createdAt or fall back to date
        final createdAtTs = data['createdAt'] as Timestamp?;
        final createdAt = createdAtTs?.toDate() ?? date;

        return SymptomEntry(
          date: date,
          createdAt: createdAt,
          severity: data['severity'] as int,
          description: data['description'] as String?,
          congestion: data['congestion'] as bool? ?? false,
          itchingEyes: data['itchingEyes'] as bool? ?? false,
          headache: data['headache'] as bool? ?? false,
        );
      }).toList();

      _cleaningEntries = cleaningSnapshot.docs.map((doc) {
        final data = doc.data();
        return CleaningEntry(
          date: (data['date'] as Timestamp).toDate(),
          windowOpened: data['windowOpened'] as bool,
          windowDuration: data['windowDuration'] as int,
          vacuumed: data['vacuumed'] as bool,
          floorWashed: data['floorWashed'] as bool,
          bedsheetsWashed: data['bedsheetsWashed'] as bool,
          clothesOnFloor: data['clothesOnFloor'] as bool,
        );
      }).toList();

      _generateRecommendations();
      _analyzeSymptomTrends();
      _analyzeCleaningImpact();
      _analyzeTimeOfDayPatterns();
      _isLoading = false;
    });

    // Load AI recommendations if available
    _loadAIRecommendations();
  }

  List<FlSpot> _buildSymptomSpots() {
    // Get filtered entries based on selected timeframe
    List<SymptomEntry> filteredEntries = _getFilteredSymptomEntries();

    return filteredEntries.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.severity.toDouble());
    }).toList();
  }

  List<VerticalLine> _buildCleaningMarkers() {
    // Get filtered entries based on selected timeframe
    List<SymptomEntry> filteredEntries = _getFilteredSymptomEntries();

    // Filter cleaning entries to match the selected timeframe
    final now = DateTime.now();
    List<CleaningEntry> filteredCleaningEntries;

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
        break;
      case 'Last 30 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
        break;
      case 'Last 3 months':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
        break;
      case 'All time':
      default:
        filteredCleaningEntries = List.from(_cleaningEntries);
    }

    List<VerticalLine> markers = [];
    for (int i = 0; i < filteredEntries.length; i++) {
      final date = filteredEntries[i].date;
      final hadCleaning = filteredCleaningEntries.any((c) =>
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
      _recommendations.add({
        'content': "Try cleaning every 2–3 days to reduce symptom spikes.",
        'isAI': false
      });
    }
    if (_cleaningEntries.last.vacuumed == false) {
      _recommendations.add(
          {'content': "Vacuuming may help improve symptoms.", 'isAI': false});
    }
    if (_cleaningEntries.last.windowOpened == false) {
      _recommendations.add({
        'content':
            "Try opening windows briefly to circulate air (if weather allows).",
        'isAI': false
      });
    }
  }

  // Load AI-powered recommendations
  Future<void> _loadAIRecommendations() async {
    if (_symptomEntries.isEmpty || _cleaningEntries.isEmpty) return;

    setState(() {
      _isLoadingAI = true;
    });

    try {
      // Import the AIService
      final aiRecommendations = await AIService.generateRecommendations(
        symptoms: _symptomEntries,
        cleaning: _cleaningEntries,
      );

      setState(() {
        // Add AI recommendations to the existing ones
        _recommendations = [
          ..._recommendations.where((rec) => rec['isAI'] == false),
          ...aiRecommendations
        ];
        _isLoadingAI = false;
      });
    } catch (e) {
      print('Error loading AI recommendations: $e');
      setState(() {
        _isLoadingAI = false;
      });
    }
  }

  // Navigate to AI chat screen
  void _navigateToAIChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIChatScreen(
          symptoms: _symptomEntries,
          cleaning: _cleaningEntries,
        ),
      ),
    );
  }

  // Analyze symptoms data to identify trends by symptom type
  void _analyzeSymptomTrends() {
    if (_symptomEntries.isEmpty) return;

    // Initialize symptom type tracking
    _symptomTypeTrends = {
      'Overall Severity': [],
      'Congestion': [],
      'Itching Eyes': [],
      'Headache': [],
    };

    // Get filtered entries based on selected timeframe
    List<SymptomEntry> filteredEntries = _getFilteredSymptomEntries();

    // Collect trends over time
    for (var entry in filteredEntries) {
      _symptomTypeTrends['Overall Severity']!.add(entry.severity.toDouble());
      _symptomTypeTrends['Congestion']!.add(entry.congestion ? 1.0 : 0.0);
      _symptomTypeTrends['Itching Eyes']!.add(entry.itchingEyes ? 1.0 : 0.0);
      _symptomTypeTrends['Headache']!.add(entry.headache ? 1.0 : 0.0);
    }
  }

  // Analyze cleaning impact on symptom severity
  void _analyzeCleaningImpact() {
    if (_symptomEntries.isEmpty || _cleaningEntries.isEmpty) return;

    _cleaningImpactScores = {
      'Vacuuming': 0.0,
      'Floor Washing': 0.0,
      'Bedsheets': 0.0,
      'Windows Opened': 0.0,
      'No Clothes on Floor': 0.0,
    };

    // Get filtered entries based on selected timeframe
    List<SymptomEntry> filteredEntries = _getFilteredSymptomEntries();
    if (filteredEntries.isEmpty) return;

    // Filter cleaning entries to match the selected timeframe
    final now = DateTime.now();
    List<CleaningEntry> filteredCleaningEntries;

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
        break;
      case 'Last 30 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
        break;
      case 'Last 3 months':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
        break;
      case 'All time':
      default:
        filteredCleaningEntries = List.from(_cleaningEntries);
    }

    if (filteredCleaningEntries.isEmpty) return;

    // Find severity changes after cleaning events
    for (var cleanEntry in filteredCleaningEntries) {
      // Find symptoms before and after this cleaning
      var beforeCleaning = filteredEntries
          .where((s) => s.date.isBefore(cleanEntry.date))
          .toList();
      var afterCleaning = filteredEntries
          .where((s) =>
              s.date.isAfter(cleanEntry.date) &&
              s.date.difference(cleanEntry.date).inDays <= 3)
          .toList();

      if (beforeCleaning.isEmpty || afterCleaning.isEmpty) continue;

      // Calculate avg severity before and after
      double beforeAvg =
          beforeCleaning.map((e) => e.severity).reduce((a, b) => a + b) /
              beforeCleaning.length;
      double afterAvg =
          afterCleaning.map((e) => e.severity).reduce((a, b) => a + b) /
              afterCleaning.length;

      // Impact is the reduction in symptom severity
      double impact = max(0, beforeAvg - afterAvg);

      // Attribute impact to specific cleaning activities
      if (cleanEntry.vacuumed) {
        _cleaningImpactScores['Vacuuming'] =
            (_cleaningImpactScores['Vacuuming']! + impact) / 2;
      }
      if (cleanEntry.floorWashed) {
        _cleaningImpactScores['Floor Washing'] =
            (_cleaningImpactScores['Floor Washing']! + impact) / 2;
      }
      if (cleanEntry.bedsheetsWashed) {
        _cleaningImpactScores['Bedsheets'] =
            (_cleaningImpactScores['Bedsheets']! + impact) / 2;
      }
      if (cleanEntry.windowOpened) {
        _cleaningImpactScores['Windows Opened'] =
            (_cleaningImpactScores['Windows Opened']! + impact) / 2;
      }
      if (!cleanEntry.clothesOnFloor) {
        _cleaningImpactScores['No Clothes on Floor'] =
            (_cleaningImpactScores['No Clothes on Floor']! + impact) / 2;
      }
    }
  }

  // Analyze the time of day patterns in symptoms
  void _analyzeTimeOfDayPatterns() {
    _timeOfDaySymptomCounts = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0
    };

    // Get filtered entries based on selected timeframe
    List<SymptomEntry> filteredEntries = _getFilteredSymptomEntries();

    for (var entry in filteredEntries) {
      int hour = entry.date.hour;

      if (hour >= 5 && hour < 12) {
        _timeOfDaySymptomCounts['Morning'] =
            _timeOfDaySymptomCounts['Morning']! + 1;
      } else if (hour >= 12 && hour < 17) {
        _timeOfDaySymptomCounts['Afternoon'] =
            _timeOfDaySymptomCounts['Afternoon']! + 1;
      } else if (hour >= 17 && hour < 22) {
        _timeOfDaySymptomCounts['Evening'] =
            _timeOfDaySymptomCounts['Evening']! + 1;
      } else {
        _timeOfDaySymptomCounts['Night'] =
            _timeOfDaySymptomCounts['Night']! + 1;
      }
    }
  }

  /// Returns only the cleaning entries in the currently selected timeframe.
  List<CleaningEntry> _getFilteredCleaningEntries() {
    final now = DateTime.now();

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        return _cleaningEntries
            .where((e) => e.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
      case 'Last 30 days':
        return _cleaningEntries
            .where(
                (e) => e.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
      case 'Last 3 months':
        return _cleaningEntries
            .where(
                (e) => e.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
      case 'All time':
      default:
        return List.from(_cleaningEntries);
    }
  }

  // Helper to filter symptom entries based on selected timeframe
  List<SymptomEntry> _getFilteredSymptomEntries() {
    final now = DateTime.now();

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        return _symptomEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
      case 'Last 30 days':
        return _symptomEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
      case 'Last 3 months':
        return _symptomEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
      case 'All time':
      default:
        return List.from(_symptomEntries);
    }
  }

  // Add a method to build the chart based on the selected option
  Widget _buildSelectedChart() {
    switch (_selectedChart) {
      case 'Before vs. After Cleaning Effect':
        return SizedBox(
          height: 300,
          child: CleaningEffectChart(
            symptoms: _getFilteredSymptomEntries(),
            cleanings: _getFilteredCleaningEntries(),
          ),
        );
      case 'Symptom Analysis':
        return _buildSymptomTypesChart();
      case 'Cleaning Impact':
        return _buildCleaningImpactChart();
      case 'Time of Day Patterns':
        return _buildTimeOfDayChart();
      case 'Symptom Severity Over Time':
      default:
        return SizedBox(
          height: 300,
          child: EventEffectChart(
            symptoms: _getFilteredSymptomEntries(),
            cleanings: _getFilteredCleaningEntries(),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _symptomEntries.isEmpty
                  ? Stack(
                      children: [
                        _buildEmptyState(),
                        ListView(), // enables pull‐to‐refresh on empty
                      ],
                    )
                  : CustomScrollView(
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

                        // One big sliver containing your selector + all charts
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTimeframeSelector(),
                                const SizedBox(height: 16),

                                // Dropdown for chart selection
                                Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Select Chart:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                        Expanded(
                                          child: DropdownButton<String>(
                                            value: _selectedChart,
                                            underline: const SizedBox(),
                                            isExpanded: true,
                                            items: _chartOptions.map((String option) {
                                              return DropdownMenuItem<String>(
                                                value: option,
                                                child: Align(
                                                  alignment: Alignment.centerRight, // Align text to the right
                                                  child: Text(
                                                    option,
                                                    style: TextStyle(
                                                      fontSize: 14, // Adjusted font size for better UX
                                                      fontWeight: FontWeight.w400,
                                                      color: isDark ? Colors.white70 : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                setState(() {
                                                  _selectedChart = newValue;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Display the selected chart
                                _buildSelectedChart(),

                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                    context, 'Recent Cleaning Events'),
                                _buildCleaningEventsList(),

                                const SizedBox(height: 24),
                                _buildSectionHeader(
                                    context, 'Recommendations'),
                                _buildRecommendationsSection(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
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

  Widget _buildFreshnessLegend() {
    Widget dot(Color c) => Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(c),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(Colors.green, '< 2h'),
        item(Colors.yellow, '< 10h'),
        item(Colors.red, '≥ 10h'),
      ],
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
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date = _symptomEntries[spot.x.toInt()].date;
                      final formattedDate =
                          DateFormat('MMM d, yyyy').format(date);
                      return LineTooltipItem(
                        '${formattedDate}\nSeverity: ${spot.y.toInt()}',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _buildSymptomSpots(),
                  isCurved: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                        strokeColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.white,
                      );
                    },
                  ),
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
                      final filteredEntries = _getFilteredSymptomEntries();
                      if (index < 0 ||
                          index >= filteredEntries.length ||
                          index % 5 != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          DateFormat('MMM d')
                              .format(filteredEntries[index].date),
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

    // Filter cleaning entries based on selected timeframe
    final now = DateTime.now();
    List<CleaningEntry> filteredCleaningEntries;

    switch (_selectedTimeframe) {
      case 'Last 7 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 7))))
            .toList();
        break;
      case 'Last 30 days':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
        break;
      case 'Last 3 months':
        filteredCleaningEntries = _cleaningEntries
            .where((entry) =>
                entry.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
        break;
      case 'All time':
      default:
        filteredCleaningEntries = List.from(_cleaningEntries);
    }

    if (filteredCleaningEntries.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No cleaning events recorded in the selected timeframe',
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
          children: filteredCleaningEntries.reversed
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

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Row(
              children: [
                if (_isLoadingAI)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 18),
                    onPressed: _loadAIRecommendations,
                    tooltip: 'Get AI Recommendations',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                IconButton(
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  onPressed: _navigateToAIChat,
                  tooltip: 'Chat with AI',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recommendations.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'No recommendations available yet. Try logging more data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show basic recommendations first
              ..._buildRecommendationsByType(false),

              // Show AI recommendations with header if they exist
              if (_recommendations.any((rec) => rec['isAI'] == true)) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildRecommendationsByType(true),
                const SizedBox(height: 12),
                // Medical disclaimer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.amber[800],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AIService.medicalDisclaimer,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // Helper method to build recommendation cards by type (AI or basic)
  List<Widget> _buildRecommendationsByType(bool isAI) {
    final filteredRecs =
        _recommendations.where((rec) => rec['isAI'] == isAI).toList();

    if (filteredRecs.isEmpty) {
      return [];
    }

    return filteredRecs.map((rec) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isAI ? Icons.psychology_outlined : Icons.lightbulb_outline,
                color: isAI
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rec['content'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
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

  // Widget for selecting the data timeframe
  Widget _buildTimeframeSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Data Timeframe:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
              ),
            ),
            DropdownButton<String>(
              value: _selectedTimeframe,
              underline: const SizedBox(),
              items: _timeframeOptions.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedTimeframe = newValue;
                    _analyzeSymptomTrends();
                    _analyzeCleaningImpact();
                    _analyzeTimeOfDayPatterns();
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget for visualizing different symptom types over time
  Widget _buildSymptomTypesChart() {
    if (_symptomTypeTrends.isEmpty ||
        _symptomTypeTrends['Overall Severity']!.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Not enough data to show symptom type patterns',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    // Extract unique symptom types and create data for radar chart
    List<String> symptomTypes = ['Congestion', 'Itching Eyes', 'Headache'];
    Map<String, double> symptomTypeAverages = {};

    // Calculate averages for each symptom type
    for (String type in symptomTypes) {
      if (_symptomTypeTrends[type] != null &&
          _symptomTypeTrends[type]!.isNotEmpty) {
        double sum = _symptomTypeTrends[type]!.reduce((a, b) => a + b);
        symptomTypeAverages[type] = sum / _symptomTypeTrends[type]!.length;
      } else {
        symptomTypeAverages[type] = 0.0;
      }
    }

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
            Text(
              'Symptom Type Distribution',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barTouchData: BarTouchData(enabled: false),
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
                          int index = value.toInt();
                          if (index < 0 || index >= symptomTypes.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              symptomTypes[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value != 0 && value != 0.5 && value != 1.0) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(fontSize: 10),
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
                  barGroups: List.generate(
                    symptomTypes.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: symptomTypeAverages[symptomTypes[index]] ?? 0,
                          color: _getSymptomTypeColor(symptomTypes[index]),
                          width: 25,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This chart shows how often each symptom type occurs.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get color for different symptom types
  Color _getSymptomTypeColor(String symptomType) {
    final theme = Theme.of(context);

    switch (symptomType) {
      case 'Congestion':
        return Colors.blue;
      case 'Itching Eyes':
        return Colors.amber;
      case 'Headache':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }

  // Widget for visualizing the impact of different cleaning activities
  Widget _buildCleaningImpactChart() {
    if (_cleaningImpactScores.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Not enough data to analyze cleaning impact',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    // Sort activities by impact
    List<MapEntry<String, double>> sortedImpacts = _cleaningImpactScores.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            Text(
              'Most Effective Cleaning Activities',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 200,
              ),
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: sortedImpacts.length,
                itemBuilder: (context, index) {
                  final activity = sortedImpacts[index].key;
                  final impact = sortedImpacts[index].value;

                  // Normalize to percentage (0-100%)
                  final normalizedImpact = (impact /
                          (sortedImpacts.first.value > 0
                              ? sortedImpacts.first.value
                              : 1)) *
                      100;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              activity,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${normalizedImpact.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: normalizedImpact > 50
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: normalizedImpact / 100,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            normalizedImpact > 50
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Based on improvement in symptoms after cleaning activities.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget for visualizing symptom patterns by time of day
  Widget _buildTimeOfDayChart() {
    final timeOfDayMap = _timeOfDaySymptomCounts;

    if (timeOfDayMap.values.every((value) => value == 0)) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Not enough data for time of day analysis',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    // Calculate percentages for pie chart
    final total = timeOfDayMap.values.reduce((a, b) => a + b);
    final List<PieChartSectionData> sections = [];

    final Map<String, Color> timeColors = {
      'Morning': Colors.yellow.shade700,
      'Afternoon': Colors.orange,
      'Evening': Colors.deepPurple,
      'Night': Colors.indigo,
    };

    timeOfDayMap.forEach((time, count) {
      if (count > 0) {
        final percentage = (count / total) * 100;
        sections.add(
          PieChartSectionData(
            value: percentage,
            title: '${percentage.toStringAsFixed(0)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            color: timeColors[time] ?? Theme.of(context).colorScheme.primary,
          ),
        );
      }
    });

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
            Text(
              'When Are Your Symptoms Worst?',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: timeOfDayMap.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: timeColors[entry.key],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Track time patterns to identify environmental triggers.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

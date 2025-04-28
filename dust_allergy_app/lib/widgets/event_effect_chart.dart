import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';

class EventEffectChart extends StatelessWidget {
  final List<SymptomEntry> symptoms;
  final List<CleaningEntry> cleanings;

  const EventEffectChart({
    Key? key,
    required this.symptoms,
    required this.cleanings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (symptoms.isEmpty) {
      return const Center(child: Text('No symptom data'));
    }

    final sortedSymptoms = List.of(symptoms)
      ..sort((a, b) => a.date.compareTo(b.date));
    final axisMin = sortedSymptoms.first.date.subtract(const Duration(days: 1));
    final axisMax = sortedSymptoms.last.date.add(const Duration(days: 1));

    return SizedBox(
      height: 360, // enough for chart + legend together
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SfCartesianChart(
              tooltipBehavior: TooltipBehavior(
                enable: true,
                builder: (dynamic data, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  if (data is SymptomEntry) {
                    return _buildCustomTooltip(context, data);
                  }
                  return const SizedBox();
                },
              ),
              primaryXAxis: DateTimeAxis(
                minimum: axisMin,
                maximum: axisMax,
                intervalType: DateTimeIntervalType.days,
                dateFormat: DateFormat.MMMd(),
                majorGridLines: const MajorGridLines(width: 0),
                plotBands: _buildLightCleaningBands(),
              ),
              primaryYAxis: NumericAxis(
                minimum: 1,
                maximum: 5,
                interval: 1,
                title: AxisTitle(
                  text: 'Symptom Severity',
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              series: [
                AreaSeries<SymptomEntry, DateTime>(
                  name: 'Symptoms',
                  dataSource: sortedSymptoms,
                  xValueMapper: (entry, _) => entry.date,
                  yValueMapper: (entry, _) => entry.severity,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderColor: Theme.of(context).colorScheme.primary,
                  borderWidth: 2,
                  markerSettings: const MarkerSettings(isVisible: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildColorLegend(),
        ],
      ),
    );
  }

  Widget _buildCustomTooltip(BuildContext context, SymptomEntry entry) {
    final dateKey = DateFormat('yyyy-MM-dd').format(entry.date);

    final cleaningsOnDay = cleanings.where((c) {
      return DateFormat('yyyy-MM-dd').format(c.date) == dateKey;
    }).toList();

    String cleaningText;
    if (cleaningsOnDay.isEmpty) {
      cleaningText = 'No cleaning';
    } else {
      final cleaning = cleaningsOnDay.first;
      final types = <String>[];
      if (cleaning.vacuumed) types.add('Vacuumed');
      if (cleaning.bedsheetsWashed) types.add('Bedsheets');
      if (cleaning.floorWashed) types.add('Floor');
      if (cleaning.windowOpened) {
        types.add('Window Opened (${cleaning.windowDuration} min)');
      }
      if (!cleaning.clothesOnFloor) types.add('Clothes picked up');
      cleaningText = types.isEmpty ? 'Cleaning done' : types.join(', ');
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM d, yyyy').format(entry.date)),
            const SizedBox(height: 4),
            Text('Severity: ${entry.severity}'),
            const SizedBox(height: 4),
            Text('Cleaning: $cleaningText'),
          ],
        ),
      ),
    );
  }

  Widget _buildColorLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          _buildLegendItem(Colors.blue.withOpacity(0.6), 'Vacuumed'),
          _buildLegendItem(Colors.green.withOpacity(0.6), 'Bedsheets'),
          _buildLegendItem(Colors.orange.withOpacity(0.6), 'Floor Washed'),
          _buildLegendItem(Colors.purple.withOpacity(0.6), 'Window Opened'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  List<PlotBand> _buildLightCleaningBands() {
    final List<PlotBand> bands = [];
    final Map<String, CleaningEntry> firstCleaningPerDay = {};

    for (final cleaning in cleanings) {
      final dateKey = DateFormat('yyyy-MM-dd').format(cleaning.date);
      if (!firstCleaningPerDay.containsKey(dateKey)) {
        firstCleaningPerDay[dateKey] = cleaning;
      }
    }

    for (final entry in firstCleaningPerDay.entries) {
      final cleaning = entry.value;
      Color color = Colors.blueGrey.withOpacity(0.05); // ultra-light base

      if (cleaning.vacuumed)
        color = Colors.blue.withOpacity(0.1);
      else if (cleaning.floorWashed)
        color = Colors.orange.withOpacity(0.1);
      else if (cleaning.bedsheetsWashed)
        color = Colors.green.withOpacity(0.1);
      else if (cleaning.windowOpened) {
        final minutes = cleaning.windowDuration;
        if (minutes > 60) {
          color = Colors.purple.withOpacity(0.12);
        } else if (minutes > 30) {
          color = Colors.purple.withOpacity(0.1);
        } else {
          color = Colors.purple.withOpacity(0.08);
        }
      }

      bands.add(
        PlotBand(
          isVisible: true,
          start: cleaning.date.subtract(const Duration(hours: 6)),
          end: cleaning.date.add(const Duration(hours: 6)),
          color: color,
        ),
      );
    }

    return bands;
  }
}

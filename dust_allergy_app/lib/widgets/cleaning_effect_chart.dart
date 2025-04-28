// lib/widgets/cleaning_effect_chart.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../models/symptom_entry.dart';
import '../models/cleaning_entry.dart';

/// Holds the before/after averages and reliability for one cleaning type.
class _EffectData {
  final String type;
  final double beforeAvg;
  final double afterAvg;
  final double reliability; // between 0 and 1

  _EffectData(this.type, this.beforeAvg, this.afterAvg, this.reliability);
}

class CleaningEffectChart extends StatelessWidget {
  final List<SymptomEntry> symptoms;
  final List<CleaningEntry> cleanings;

  const CleaningEffectChart({
    Key? key,
    required this.symptoms,
    required this.cleanings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Maps to accumulate per‐event averages
    final Map<String, List<double>> eventBefore = {};
    final Map<String, List<double>> eventAfter  = {};
    final Map<String, int> totalEvents   = {};
    final Map<String, int> betterEvents  = {};

    for (var c in cleanings) {
      // collect symptom scores 1 day before
      final beforeList = symptoms
          .where((s) =>
      s.date.isAfter(c.date.subtract(const Duration(days: 2))) &&
          s.date.isBefore(c.date))
          .map((s) => s.severity.toDouble())
          .toList();

      // collect symptom scores 1 day after
      final afterList = symptoms
          .where((s) =>
      s.date.isAfter(c.date) &&
          s.date.isBefore(c.date.add(const Duration(days: 2))))
          .map((s) => s.severity.toDouble())
          .toList();

      if (beforeList.isEmpty || afterList.isEmpty) continue;

      final beforeAvg = beforeList.reduce((a, b) => a + b) / beforeList.length;
      final afterAvg  = afterList .reduce((a, b) => a + b) / afterList.length;

      // helper to record for a given cleaning type
      void record(String type) {
        eventBefore.putIfAbsent(type, () => []).add(beforeAvg);
        eventAfter .putIfAbsent(type, () => []).add(afterAvg);
        totalEvents[type] = (totalEvents[type] ?? 0) + 1;
        if (afterAvg < beforeAvg) {
          betterEvents[type] = (betterEvents[type] ?? 0) + 1;
        }
      }

      if (c.vacuumed)        record('Vacuumed');
      if (c.bedsheetsWashed) record('Bedsheets');
      if (c.floorWashed)     record('Floor Washed');
      if (c.windowOpened)    record('Window Opened');
      if (!c.clothesOnFloor) record('No Clothes on Floor');
    }

    // build the final list of _EffectData
    final List<_EffectData> data = [];
    for (var type in eventBefore.keys) {
      final beforeList = eventBefore[type]!;
      final afterList  = eventAfter[type]!;

      final pooledBefore = beforeList.reduce((a, b) => a + b) / beforeList.length;
      final pooledAfter  = afterList .reduce((a, b) => a + b) / afterList.length;
      final total = totalEvents[type]!;
      final better = betterEvents[type] ?? 0;
      final reliability = total > 0 ? better / total : 0.0;

      data.add(_EffectData(type, pooledBefore, pooledAfter, reliability));
    }

    if (data.isEmpty) {
      return const Center(child: Text('Not enough data for effect chart'));
    }

    return SfCartesianChart(
      legend: Legend(
        isVisible: true,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      primaryXAxis: CategoryAxis(),
      primaryYAxis: NumericAxis(
        minimum: 1,
        maximum: 5,
        interval: 1,
        title: const AxisTitle(text: 'Avg Severity'),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'relAxis',
          opposedPosition: true,
          minimum: 0,
          maximum: 1,
          interval: 0.25,
          title: const AxisTitle(text: 'Reliability'),
          labelFormat: '{value}×',
        )
      ],
      tooltipBehavior: TooltipBehavior(enable: true),
      series: <CartesianSeries<_EffectData, String>>[
        ColumnSeries<_EffectData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.type,
          yValueMapper: (d, _) => d.beforeAvg,
          name: '1 Day Before',
          // dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
        ColumnSeries<_EffectData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.type,
          yValueMapper: (d, _) => d.afterAvg,
          name: '1 Day After',
          // dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
        LineSeries<_EffectData, String>(
          dataSource: data,
          xValueMapper: (d, _) => d.type,
          yValueMapper: (d, _) => d.reliability,
          name: 'Reliability',
          yAxisName: 'relAxis',
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }
}

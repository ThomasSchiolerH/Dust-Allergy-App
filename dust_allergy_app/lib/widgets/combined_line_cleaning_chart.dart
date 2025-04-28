// // lib/widgets/combined_line_cleaning_chart.dart

// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:intl/intl.dart';
// import '../models/symptom_entry.dart';
// import '../models/cleaning_entry.dart';

// class CombinedLineCleaningChart extends StatelessWidget {
//   final List<SymptomEntry> symptoms;
//   final List<CleaningEntry> cleanings;

//   const CombinedLineCleaningChart({
//     Key? key,
//     required this.symptoms,
//     required this.cleanings,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // 1) Sort entries
//     final recentSymptoms = List.of(symptoms)
//       ..sort((a, b) => a.date.compareTo(b.date));

//     if (recentSymptoms.isEmpty) {
//       return const Center(child: Text("No data"));
//     }

//     // 2) Axis bounds
//     final firstDate = recentSymptoms.first.date;
//     final lastDate  = recentSymptoms.last.date;
//     final axisMin   = firstDate.subtract(const Duration(hours: 12));
//     final axisMax   = lastDate .add(const Duration(hours: 12));

//     // 3) Flatten cleaning
//     final allPoints = <_CleaningPoint>[];
//     final typeColors = <String, Color>{
//       'Vacuumed': Colors.blue,
//       'Bedsheets': Colors.green,
//       'Floor Washed': Colors.orange,
//       'Window Opened': Colors.purple,
//       'No Clothes on Floor': Colors.teal,
//     };
//     for (var c in cleanings.where((c) =>
//     c.date.isAfter(axisMin) && c.date.isBefore(axisMax))) {
//       if (c.vacuumed)        allPoints.add(_CleaningPoint(c.date, 'Vacuumed'));
//       if (c.bedsheetsWashed) allPoints.add(_CleaningPoint(c.date, 'Bedsheets'));
//       if (c.floorWashed)     allPoints.add(_CleaningPoint(c.date, 'Floor Washed'));
//       if (c.windowOpened)    allPoints.add(_CleaningPoint(c.date, 'Window Opened'));
//       if (!c.clothesOnFloor) allPoints.add(_CleaningPoint(c.date, 'No Clothes on Floor'));
//     }

//     // 4) Group by type
//     final grouped = <String, List<_CleaningPoint>>{};
//     for (var p in allPoints) {
//       grouped.putIfAbsent(p.type, () => []).add(p);
//     }

//     return SfCartesianChart(
//       legend: Legend(
//         isVisible: true,
//         position: LegendPosition.bottom,
//         overflowMode: LegendItemOverflowMode.wrap,
//         textStyle: const TextStyle(fontSize: 12),
//       ),
//       tooltipBehavior: TooltipBehavior(
//         enable: true,
//         builder: (data, point, series, pi, si) {
//           final fmt = DateFormat('MMM d, yyyy');
//           if (series is ScatterSeries<_CleaningPoint, DateTime>) {
//             final cp = data as _CleaningPoint;
//             final sev = (point.y as double).toInt();
//             return _tooltip(fmt.format(cp.date), sev, cp.type);
//           } else {
//             final s = data as SymptomEntry;
//             return _tooltip(fmt.format(s.date), s.severity, null);
//           }
//         },
//       ),
//       primaryXAxis: DateTimeAxis(
//         minimum: axisMin,
//         maximum: axisMax,
//         intervalType: DateTimeIntervalType.days,
//         interval: 1,
//         dateFormat: DateFormat.MMMd(),
//         edgeLabelPlacement: EdgeLabelPlacement.shift,
//       ),
//       primaryYAxis: NumericAxis(
//         minimum: 1,
//         maximum: 5,
//         interval: 1,
//         title: AxisTitle(
//           text: 'Severity',
//           textStyle: const TextStyle(fontSize: 12),
//         ),
//       ),
//       series: <CartesianSeries>[
//         // A) Severity line, hidden from legend
//         LineSeries<SymptomEntry, DateTime>(
//           name: 'Severity',
//           isVisibleInLegend: false,
//           dataSource: recentSymptoms,
//           xValueMapper: (s, _) => s.date,
//           yValueMapper: (s, _) => s.severity.toDouble(),
//           color: Theme.of(context).colorScheme.primary,
//           width: 2,
//           pointColorMapper: (s, _) {
//             final hoursDiff =
//             s.createdAt.difference(s.date).inHours.abs();
//             if (hoursDiff < 2)  return Colors.green;
//             if (hoursDiff < 10) return Colors.yellow;
//             return Colors.red;
//           },
//           markerSettings: const MarkerSettings(isVisible: true, width: 6, height: 6),
//         ),

//         // B) Cleaning events
//         for (var entry in grouped.entries)
//           ScatterSeries<_CleaningPoint, DateTime>(
//             name: entry.key,
//             dataSource: entry.value,
//             xValueMapper: (p, _) => p.date,
//             yValueMapper: (p, _) {
//               final fallback = SymptomEntry(
//                 date:        p.date,
//                 createdAt:   p.date,
//                 severity:    1,
//                 description: '',
//                 congestion:  false,
//                 itchingEyes: false,
//                 headache:    false,
//               );
//               final match = recentSymptoms.lastWhere(
//                     (s) =>
//                 s.date.year  == p.date.year &&
//                     s.date.month == p.date.month &&
//                     s.date.day   == p.date.day,
//                 orElse: () => fallback,
//               );
//               return match.severity.toDouble();
//             },
//             pointColorMapper: (_, __) => typeColors[entry.key]!,
//             markerSettings: const MarkerSettings(
//               isVisible: true,
//               shape: DataMarkerType.diamond,
//               width: 10,
//               height: 10,
//             ),
//           ),

//         // C) Freshness buckets
//         ScatterSeries<Null, DateTime>(
//           name: '< 2h',
//           dataSource: [null],
//           xValueMapper: (_, __) => axisMin,
//           yValueMapper: (_, __) => 0.0,
//           markerSettings: const MarkerSettings(isVisible: true, width: 8, height: 8, color: Colors.green),
//         ),
//         ScatterSeries<Null, DateTime>(
//           name: '< 10h',
//           dataSource: [null],
//           xValueMapper: (_, __) => axisMin,
//           yValueMapper: (_, __) => 0.0,
//           markerSettings: const MarkerSettings(isVisible: true, width: 8, height: 8, color: Colors.yellow),
//         ),
//         ScatterSeries<Null, DateTime>(
//           name: '≥ 10h',
//           dataSource: [null],
//           xValueMapper: (_, __) => axisMin,
//           yValueMapper: (_, __) => 0.0,
//           markerSettings: const MarkerSettings(isVisible: true, width: 8, height: 8, color: Colors.red),
//         ),
//       ],
//     );
//   }

//   Widget _tooltip(String date, int severity, String? cleanType) {
//     return Container(
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
//       child: Text(
//         cleanType == null
//             ? '$date\nSeverity: $severity'
//             : '$date\nSeverity: $severity\nClean: $cleanType',
//         style: const TextStyle(color: Colors.white, fontSize: 12),
//       ),
//     );
//   }
// }

// class _CleaningPoint {
//   final DateTime date;
//   final String type;
//   _CleaningPoint(this.date, this.type);
// }

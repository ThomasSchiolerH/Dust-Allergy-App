import 'package:cloud_firestore/cloud_firestore.dart';

class SymptomEntry {
  final DateTime date;        // when your symptoms occurred
  final DateTime createdAt;   // when you actually logged them
  final int severity;
  final String? description;
  final bool congestion;
  final bool itchingEyes;
  final bool headache;

  SymptomEntry({
    required this.date,
    required this.createdAt,
    required this.severity,
    this.description,
    this.congestion = false,
    this.itchingEyes = false,
    this.headache = false,
  });

  /// Serialize for Firestore; use serverTimestamp() for createdAt
  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'createdAt': FieldValue.serverTimestamp(),
    'severity': severity,
    'description': description,
    'congestion': congestion,
    'itchingEyes': itchingEyes,
    'headache': headache,
  };

  /// Deserialize from Firestore document
  factory SymptomEntry.fromMap(Map<String, dynamic> data) {
    return SymptomEntry(
      date:      (data['date']      as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      severity:  data['severity']   as int,
      description: data['description'] as String?,
      congestion:  data['congestion'] as bool? ?? false,
      itchingEyes: data['itchingEyes'] as bool? ?? false,
      headache:    data['headache']    as bool? ?? false,
    );
  }
}

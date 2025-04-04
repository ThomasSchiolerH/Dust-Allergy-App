class SymptomEntry {
  final DateTime date;
  final int severity;
  final String? description;
  final bool congestion;
  final bool itchingEyes;
  final bool headache;

  SymptomEntry({
    required this.date,
    required this.severity,
    this.description,
    this.congestion = false,
    this.itchingEyes = false,
    this.headache = false,
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'severity': severity,
    'description': description,
    'congestion': congestion,
    'itchingEyes': itchingEyes,
    'headache': headache,
  };
}

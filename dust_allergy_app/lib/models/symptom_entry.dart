class SymptomEntry {
  final DateTime date;
  final int severity;
  final String? description;

  SymptomEntry({required this.date, required this.severity, this.description});

  Map<String, dynamic> toMap() => {
    'date': date,
    'severity': severity,
    'description': description,
  };
}

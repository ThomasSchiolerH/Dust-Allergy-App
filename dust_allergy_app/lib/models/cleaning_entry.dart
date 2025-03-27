class CleaningEntry {
  final DateTime date;
  final bool windowOpened;
  final int windowDuration; // in minutes
  final bool vacuumed;
  final bool floorWashed;
  final bool bedsheetsWashed;
  final bool clothesOnFloor;

  CleaningEntry({
    required this.date,
    required this.windowOpened,
    required this.windowDuration,
    required this.vacuumed,
    required this.floorWashed,
    required this.bedsheetsWashed,
    required this.clothesOnFloor,
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'windowOpened': windowOpened,
    'windowDuration': windowDuration,
    'vacuumed': vacuumed,
    'floorWashed': floorWashed,
    'bedsheetsWashed': bedsheetsWashed,
    'clothesOnFloor': clothesOnFloor,
  };
}

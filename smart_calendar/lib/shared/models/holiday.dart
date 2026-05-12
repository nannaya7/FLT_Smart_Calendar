class Holiday {
  final int? id;
  final String date; // YYYY-MM-DD
  final String name;
  final String type;
  // anniversary | rest_day | national_holiday | solar_term

  const Holiday({
    this.id,
    required this.date,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'name': name,
    'type': type,
  };

  static Holiday fromMap(Map<String, dynamic> m) => Holiday(
    id: m['id'] as int?,
    date: m['date'] as String,
    name: m['name'] as String,
    type: m['type'] as String,
  );
}

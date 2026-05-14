class Holiday {
  final int? id;
  final String date; // YYYY-MM-DD
  final String name;
  final String type; // anniversary | rest_day | national_holiday | solar_term

  const Holiday({
    this.id,
    required this.date,
    required this.name,
    required this.type,
  });

  // ── Type predicates ──────────────────────────────────────────────────────────

  bool get isPublicHoliday => type == 'rest_day';
  bool get isAnniversary => type == 'anniversary';

  static int _priority(String type) =>
      const {'rest_day': 50, 'solar_term': 40, 'national_holiday': 35, 'anniversary': 20}[type] ?? 0;

  /// 우선순위가 높은 항목을 [map]에 유지한다.
  static void insertPriority(Map<String, Holiday> map, Holiday h) {
    final existing = map[h.date];
    if (existing == null || _priority(h.type) > _priority(existing.type)) {
      map[h.date] = h;
    }
  }

  // ── DB serialization ─────────────────────────────────────────────────────────

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

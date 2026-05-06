class Schedule {
  final int? id;
  final String title;
  final String? memo;
  final String solarDate;  // YYYY-MM-DD
  final String? time;       // HH:mm
  final bool isLunar;
  final int? alarmMinutesBefore;
  final int categoryColor;

  const Schedule({
    this.id,
    required this.title,
    this.memo,
    required this.solarDate,
    this.time,
    this.isLunar = false,
    this.alarmMinutesBefore,
    this.categoryColor = 0xFF2196F3,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'memo': memo,
      'solar_date': solarDate,
      'time': time,
      'is_lunar': isLunar ? 1 : 0,
      'alarm_minutes_before': alarmMinutesBefore,
      'category_color': categoryColor,
    };
  }

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      id: map['id'] as int?,
      title: map['title'] as String,
      memo: map['memo'] as String?,
      solarDate: map['solar_date'] as String,
      time: map['time'] as String?,
      isLunar: (map['is_lunar'] as int) == 1,
      alarmMinutesBefore: map['alarm_minutes_before'] as int?,
      categoryColor: map['category_color'] as int,
    );
  }

  Schedule copyWith({
    int? id,
    String? title,
    String? memo,
    String? solarDate,
    String? time,
    bool? isLunar,
    int? alarmMinutesBefore,
    int? categoryColor,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      memo: memo ?? this.memo,
      solarDate: solarDate ?? this.solarDate,
      time: time ?? this.time,
      isLunar: isLunar ?? this.isLunar,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }
}

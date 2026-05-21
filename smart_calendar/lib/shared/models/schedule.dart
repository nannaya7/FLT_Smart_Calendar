class Schedule {
  final int? id;
  final String title;
  final String? emoji;
  final String? memo;
  final String solarDate; // YYYY-MM-DD
  final String? time; // HH:mm
  final String? endTime; // HH:mm
  final String? location;
  final bool isLunar;
  final int? alarmMinutesBefore;
  final int categoryColor;
  final String? repeatType; // null | 'daily' | 'monthly' | 'yearly'
  final int? lunarMonth;
  final int? lunarDay;
  final int? displayOrder;

  const Schedule({
    this.id,
    required this.title,
    this.emoji,
    this.memo,
    required this.solarDate,
    this.time,
    this.endTime,
    this.location,
    this.isLunar = false,
    this.alarmMinutesBefore,
    this.categoryColor = 0xFF2196F3,
    this.repeatType,
    this.lunarMonth,
    this.lunarDay,
    this.displayOrder,
  });

  Schedule copyWith({
    int? id,
    String? title,
    Object? emoji = _sentinel,
    String? memo,
    String? solarDate,
    String? time,
    Object? endTime = _sentinel,
    Object? location = _sentinel,
    bool? isLunar,
    int? alarmMinutesBefore,
    int? categoryColor,
    Object? repeatType = _sentinel,
    Object? lunarMonth = _sentinel,
    Object? lunarDay = _sentinel,
    Object? displayOrder = _sentinel,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji == _sentinel ? this.emoji : emoji as String?,
      memo: memo ?? this.memo,
      solarDate: solarDate ?? this.solarDate,
      time: time ?? this.time,
      endTime: endTime == _sentinel ? this.endTime : endTime as String?,
      location: location == _sentinel ? this.location : location as String?,
      isLunar: isLunar ?? this.isLunar,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
      categoryColor: categoryColor ?? this.categoryColor,
      repeatType: repeatType == _sentinel
          ? this.repeatType
          : repeatType as String?,
      lunarMonth: lunarMonth == _sentinel
          ? this.lunarMonth
          : lunarMonth as int?,
      lunarDay: lunarDay == _sentinel ? this.lunarDay : lunarDay as int?,
      displayOrder: displayOrder == _sentinel
          ? this.displayOrder
          : displayOrder as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'emoji': emoji,
    'memo': memo,
    'solar_date': solarDate,
    'time': time,
    'end_time': endTime,
    'location': location,
    'is_lunar': isLunar ? 1 : 0,
    'alarm_minutes_before': alarmMinutesBefore,
    'category_color': categoryColor,
    'repeat_type': repeatType,
    'lunar_month': lunarMonth,
    'lunar_day': lunarDay,
    'display_order': displayOrder,
  };

  factory Schedule.fromMap(Map<String, dynamic> map) => Schedule(
    id: map['id'] as int?,
    title: map['title'] as String,
    emoji: map['emoji'] as String?,
    memo: map['memo'] as String?,
    solarDate: map['solar_date'] as String,
    time: map['time'] as String?,
    endTime: map['end_time'] as String?,
    location: map['location'] as String?,
    isLunar: (map['is_lunar'] as int) == 1,
    alarmMinutesBefore: map['alarm_minutes_before'] as int?,
    categoryColor: map['category_color'] as int,
    repeatType: map['repeat_type'] as String?,
    lunarMonth: map['lunar_month'] as int?,
    lunarDay: map['lunar_day'] as int?,
    displayOrder: map['display_order'] as int?,
  );

  static const _sentinel = Object();
}

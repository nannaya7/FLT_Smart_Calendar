import 'calendar_engine.dart';
import '../shared/models/schedule.dart';

/// 반복 일정 날짜 확장 로직 전담 헬퍼
abstract final class RepeatScheduleHelper {
  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// 반복 일정 [s]가 [month]에 해당하는 날짜 키(`YYYY-MM-DD`) 목록을 반환한다.
  static List<String> datesInMonth(
    Schedule s,
    DateTime month,
    CalendarEngine engine,
  ) {
    final reg = DateTime.parse(s.solarDate);
    switch (s.repeatType) {
      case 'daily':
        final days = _daysInMonth(month.year, month.month);
        return List.generate(
          days,
          (i) => _dateKey(DateTime(month.year, month.month, i + 1)),
        );
      case 'weekly':
        final weekday = reg.weekday;
        final totalDays = _daysInMonth(month.year, month.month);
        final result = <String>[];
        for (int d = 1; d <= totalDays; d++) {
          final date = DateTime(month.year, month.month, d);
          if (date.weekday == weekday) result.add(_dateKey(date));
        }
        return result;
      case 'monthly':
        if (s.isLunar) {
          if (s.lunarDay == null) return [];
          final days = _daysInMonth(month.year, month.month);
          for (int d = 1; d <= days; d++) {
            final solar = DateTime(month.year, month.month, d);
            if (engine.solarToLunar(solar).day == s.lunarDay) {
              return [_dateKey(solar)];
            }
          }
          return [];
        } else {
          final day = reg.day;
          if (day > _daysInMonth(month.year, month.month)) return [];
          return [_dateKey(DateTime(month.year, month.month, day))];
        }
      case 'yearly':
        if (s.isLunar) {
          if (s.lunarMonth == null || s.lunarDay == null) return [];
          final solar = engine.lunarToSolar(month.year, s.lunarMonth!, s.lunarDay!);
          if (solar == null || solar.month != month.month) return [];
          return [_dateKey(solar)];
        } else {
          if (reg.month != month.month) return [];
          final day = reg.day;
          if (day > _daysInMonth(month.year, month.month)) return [];
          return [_dateKey(DateTime(month.year, month.month, day))];
        }
      default:
        return [];
    }
  }

  /// 반복 일정 [s]가 특정 날짜 [day]에 해당하는지 반환한다.
  static bool matchesDay(Schedule s, DateTime day, CalendarEngine engine) {
    final reg = DateTime.parse(s.solarDate);
    switch (s.repeatType) {
      case 'daily':
        return true;
      case 'weekly':
        return day.weekday == reg.weekday;
      case 'monthly':
        if (s.isLunar) {
          if (s.lunarDay == null) return false;
          return engine.solarToLunar(day).day == s.lunarDay;
        } else {
          return day.day == reg.day;
        }
      case 'yearly':
        if (s.isLunar) {
          if (s.lunarMonth == null || s.lunarDay == null) return false;
          final lunar = engine.solarToLunar(day);
          return lunar.month == s.lunarMonth && lunar.day == s.lunarDay;
        } else {
          return day.month == reg.month && day.day == reg.day;
        }
      default:
        return false;
    }
  }
}

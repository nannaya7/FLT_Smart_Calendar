import 'package:korean_lunar_utils/korean_lunar_utils.dart';

/// 음력 변환 로직 전담 클래스 — UI 레이어에서 직접 korean_lunar_utils 호출 금지
class CalendarEngine {
  CalendarEngine._();
  static final instance = CalendarEngine._();

  // 음력 (월-일) → 전통 명절 이름
  static const _lunarHolidays = <String, String>{
    '1-1': '설날',
    '1-15': '대보름',
    '4-8': '초파일',
    '5-5': '단오',
    '7-7': '칠석',
    '8-15': '추석',
    '9-9': '중양절',
  };

  /// 날짜 셀 렌더링에 필요한 음력 정보를 한 번에 반환
  ///
  /// - [lunarLabel]: "월·일" 형식의 음력 날짜 (e.g. "1·15")
  /// - [holiday]: 명절 이름 — 해당 없으면 null
  /// - [isSpecial]: 음력 1일 또는 15일이면 true (금색 강조 대상)
  ({String lunarLabel, String? holiday, bool isSpecial}) cellInfo(
      DateTime solar) {
    final l = LunarSolarConverter.convertSolarToLunar(solar);
    final key = '${l.month}-${l.day}';
    return (
      lunarLabel: '${l.month}·${l.day}',
      holiday: _lunarHolidays[key],
      isSpecial: l.day == 1 || l.day == 15,
    );
  }

  /// 양력 날짜 → 음력 날짜 (반환 DateTime의 year·month·day = 음력 연·월·일)
  DateTime solarToLunar(DateTime solar) =>
      LunarSolarConverter.convertSolarToLunar(solar);

  /// 음력 연-월-일 → 양력 날짜 (변환 범위 초과 시 null)
  DateTime? lunarToSolar(int lunarYear, int lunarMonth, int lunarDay) {
    try {
      return LunarSolarConverter.convertLunarToSolar(
          DateTime(lunarYear, lunarMonth, lunarDay));
    } catch (_) {
      return null;
    }
  }
}

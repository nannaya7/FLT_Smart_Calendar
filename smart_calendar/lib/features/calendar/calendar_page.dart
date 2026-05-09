import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/calendar_engine.dart';
import '../../core/api/google_calendar_service.dart';
import '../../core/api/holiday_api_service.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/models/holiday.dart';
import '../../shared/models/schedule.dart';
import '../schedule/schedule_form_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  /// 날짜 키("YYYY-MM-DD") → 해당 날짜 일정 수
  Map<String, int> _scheduleCounts = {};

  List<Schedule> _selectedDaySchedules = [];

  /// 날짜 키("YYYY-MM-DD") → 공휴일 or 절기 정보
  final Map<String, Holiday> _holidays = {};
  final Set<int> _loadedHolidayYears = {};

  final _engine = CalendarEngine.instance;
  final _googleService = GoogleCalendarService();
  final _apiService = HolidayApiService(); // 24절기 전용

  static const _months = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

  static const _rowHeight = 80.0; // ← 날짜 행 높이
  static const _dowHeight = 32.0; // ← 요일 헤더 행 높이


  // ── 라이프사이클 ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSchedules(_focusedDay);
    _loadHolidays(_focusedDay.year);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      NotificationService.instance.requestAndroidPermission();
      await _refreshHolidaysIfNeeded();
    });
  }

  /// 최초 설치 또는 월말일에 공휴일 데이터를 갱신한다.
  Future<void> _refreshHolidaysIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // ── 최초 설치: 올해 + 내년 데이터 프리패치
    final initialized = prefs.getBool('holiday_initialized') ?? false;
    if (!initialized) {
      await Future.wait([
        _loadHolidays(now.year, forceRefresh: true),
        _loadHolidays(now.year + 1, forceRefresh: true),
      ]);
      await prefs.setBool('holiday_initialized', true);
      return;
    }

    // ── 월말일: 다음 달(연도)의 데이터 강제 갱신 (오늘 이미 했으면 건너뜀)
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    if (now.day != lastDayOfMonth) return;

    final refreshKey = 'holiday_refreshed_${now.year}_${now.month}';
    if (prefs.getBool(refreshKey) ?? false) return;

    final nextMonth = DateTime(now.year, now.month + 1);
    await _loadHolidays(nextMonth.year, forceRefresh: true);
    await prefs.setBool(refreshKey, true);
  }

  Future<void> _loadHolidays(int year, {bool forceRefresh = false}) async {
    if (!forceRefresh && _loadedHolidayYears.contains(year)) return;

    if (forceRefresh) {
      await DatabaseHelper.instance.clearHolidaysByYear(year);
      _loadedHolidayYears.remove(year);
    }

    final cached = await DatabaseHelper.instance.getHolidaysByYear(year);
    List<Holiday> all;

    if (cached.isEmpty) {
      // 공휴일: Google Calendar / 24절기: 공공데이터포털
      final results = await Future.wait([
        _googleService.fetchHolidays(year),
        _apiService.fetchSolarTerms(year),
      ]);
      all = [...results[0], ...results[1]];
      if (all.isNotEmpty) {
        await DatabaseHelper.instance.insertHolidays(all);
      }
    } else {
      all = cached;
    }

    if (!mounted) return;
    setState(() {
      for (final h in all) {
        _holidays[h.date] = h;
      }
      _loadedHolidayYears.add(year);
    });
  }

  Future<void> _loadSchedules(DateTime month) async {
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    // 비반복 일정: 이 달에 등록된 것만
    final list = await DatabaseHelper.instance.getSchedulesByMonth(ym);

    // 반복 일정 전체: 이 달에 해당하는 날짜로 확장
    final allRepeats = await DatabaseHelper.instance.getAllRepeatSchedules();

    if (!mounted) return;
    final counts = <String, int>{};

    for (final s in list) {
      if (s.repeatType != null) continue; // 반복 일정은 아래에서 처리
      counts[s.solarDate] = (counts[s.solarDate] ?? 0) + 1;
    }

    for (final s in allRepeats) {
      for (final key in _repeatDatesInMonth(s, month)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    setState(() => _scheduleCounts = counts);
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  /// 반복 일정이 주어진 달(month)에 나타나는 날짜 키 목록 반환
  List<String> _repeatDatesInMonth(Schedule s, DateTime month) {
    final reg = DateTime.parse(s.solarDate);
    switch (s.repeatType) {
      case 'daily':
        final days = _daysInMonth(month.year, month.month);
        return List.generate(
          days,
          (i) => _dateKey(DateTime(month.year, month.month, i + 1)),
        );
      case 'monthly':
        if (s.isLunar) {
          // 음력 매월: 이 달의 각 날짜에서 음력 day가 일치하는 날 탐색
          if (s.lunarDay == null) return [];
          final days = _daysInMonth(month.year, month.month);
          final results = <String>[];
          for (int d = 1; d <= days; d++) {
            final solar = DateTime(month.year, month.month, d);
            if (_engine.solarToLunar(solar).day == s.lunarDay) {
              results.add(_dateKey(solar));
              break; // 한 달에 한 번만
            }
          }
          return results;
        } else {
          // 양력 매월: 등록일의 day를 현재 달에 적용
          final day = reg.day;
          if (day > _daysInMonth(month.year, month.month)) return [];
          return [_dateKey(DateTime(month.year, month.month, day))];
        }
      case 'yearly':
        if (s.isLunar) {
          // 음력 매년: 이 연도의 해당 음력 날짜 → 양력 변환
          if (s.lunarMonth == null || s.lunarDay == null) return [];
          final solar = _engine.lunarToSolar(month.year, s.lunarMonth!, s.lunarDay!);
          if (solar == null || solar.month != month.month) return [];
          return [_dateKey(solar)];
        } else {
          // 양력 매년: 등록일의 월/day를 현재 연도에 적용
          if (reg.month != month.month) return [];
          final day = reg.day;
          if (day > _daysInMonth(month.year, month.month)) return [];
          return [_dateKey(DateTime(month.year, month.month, day))];
        }
      default:
        return [];
    }
  }

  /// 반복 일정이 특정 날짜(day)에 해당하는지 확인
  bool _isRepeatMatchingDay(Schedule s, DateTime day) {
    final reg = DateTime.parse(s.solarDate);
    switch (s.repeatType) {
      case 'daily':
        return true;
      case 'monthly':
        if (s.isLunar) {
          if (s.lunarDay == null) return false;
          return _engine.solarToLunar(day).day == s.lunarDay;
        } else {
          return day.day == reg.day;
        }
      case 'yearly':
        if (s.isLunar) {
          if (s.lunarMonth == null || s.lunarDay == null) return false;
          final lunar = _engine.solarToLunar(day);
          return lunar.month == s.lunarMonth && lunar.day == s.lunarDay;
        } else {
          return day.month == reg.month && day.day == reg.day;
        }
      default:
        return false;
    }
  }

  Future<void> _onDayTap(DateTime selected, DateTime focused) async {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    await _loadSelectedDaySchedules(selected);
  }

  Future<void> _loadSelectedDaySchedules(DateTime day) async {
    // 이 날짜에 등록된 일정 (비반복 + 원래 이 날 등록된 반복 포함)
    final regular =
        await DatabaseHelper.instance.getSchedulesByDate(_dateKey(day));
    final regularIds = regular.map((s) => s.id).toSet();

    // 모든 반복 일정 중 이 날에 해당하는 것 추가 (중복 제외)
    final allRepeats = await DatabaseHelper.instance.getAllRepeatSchedules();
    final matching = allRepeats.where((s) =>
        _isRepeatMatchingDay(s, day) && !regularIds.contains(s.id));

    if (!mounted) return;
    setState(() => _selectedDaySchedules = [...regular, ...matching]);
  }

  Future<void> _openAddForm() async {
    if (_selectedDay == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(date: _selectedDay!),
    );
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  Future<void> _deleteSchedule(Schedule s) async {
    await DatabaseHelper.instance.deleteSchedule(s.id!);
    if (s.alarmMinutesBefore != null) {
      await NotificationService.instance.cancel(s.id!);
    }
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  Future<void> _openEditForm(Schedule s) async {
    final date = DateTime.parse(s.solarDate);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(date: date, initialSchedule: s),
    );
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF97867B), Color(0xFF807169)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 4),
              _buildCalendar(),
              const SizedBox(height: 6),
              Expanded(child: _buildInfoPanel()),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더 ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Center(
        child: Text(
          '${_focusedDay.year}년 ${_months[_focusedDay.month - 1]}',
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontFamilyFallback: ['Pretendard'],
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFF3E0),
          ),
        ),
      ),
    );
  }

  // ── 달력 카드 ────────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE4D4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          onDaySelected: _onDayTap,
          onPageChanged: (focused) {
            setState(() => _focusedDay = focused);
            _loadSchedules(focused);
            _loadHolidays(focused.year);
          },
          headerVisible: false,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          rowHeight: _rowHeight,
          daysOfWeekHeight: _dowHeight,
          sixWeekMonthsEnforced: true,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            dowBuilder: (context, day) => _dowCell(day),
            defaultBuilder: (context, day, _) => _dayCell(day),
            todayBuilder: (context, day, _) =>
                _dayCell(day, isToday: true),
            selectedBuilder: (context, day, _) =>
                _dayCell(day, isSelected: true),
            outsideBuilder: (context, day, _) =>
                _dayCell(day, isOutside: true),
          ),
        ),
      ),
    );
  }

  // ── 인라인 정보창 ─────────────────────────────────────────────────────────────

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE4D4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: _selectedDay == null ? _panelPlaceholder() : _panelContent(),
    );
  }

  Widget _panelPlaceholder() => const Center(
        child: Text(
          '날짜를 선택하면 일정이 표시됩니다',
          style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFAA9898), fontSize: 13),
        ),
      );

  Widget _panelContent() {
    final d = _selectedDay!;
    final label = '${d.month}월 ${d.day}일 (${_weekdayNames[d.weekday - 1]})';

    // 음력 날짜
    final lunar = _engine.solarToLunar(d);
    final lunarLabel = '(음) ${lunar.month}월 ${lunar.day}일';

    // 절기 / 공휴일 / 전통명절 정보
    final apiEntry = _holidays[_dateKey(d)];
    final cellInfo = _engine.cellInfo(d);
    String? specialLabel;
    Color specialColor = const Color(0xFF80E080);
    if (apiEntry != null) {
      specialLabel = apiEntry.name;
      specialColor = apiEntry.type == 'solar_term'
          ? const Color(0xFF4CAF50)
          : const Color(0xFFFF8A65);
    } else if (cellInfo.holiday != null) {
      specialLabel = cellInfo.holiday;
      specialColor = const Color(0xFFFF8A65);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontFamilyFallback: ['Pretendard'],
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2B3A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lunarLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Pretendard'],
                            fontSize: 12,
                            color: Color(0xFFB8920A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (specialLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          specialLabel,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11,
                            color: specialColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openAddForm,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8C090),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+ 일정 추가',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF3D1E0A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFCEC5B4)),
        Expanded(
          child: _selectedDaySchedules.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 일정이 없습니다',
                    style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFAA9898), fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: _selectedDaySchedules.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFCEC5B4)),
                  itemBuilder: (_, i) {
                    final s = _selectedDaySchedules[i];
                    return Slidable(
                      key: Key('sp_${s.id}'),
                      endActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.4,
                        children: [
                          SlidableAction(
                            onPressed: (_) => _openEditForm(s),
                            backgroundColor: const Color(0xFF5B8DEF),
                            foregroundColor: Colors.white,
                            icon: Icons.edit_outlined,
                            label: '수정',
                          ),
                          SlidableAction(
                            onPressed: (_) => _deleteSchedule(s),
                            backgroundColor: const Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline,
                            label: '삭제',
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(s.categoryColor),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2D2B3A),
                                    ),
                                  ),
                                  if (s.time != null || s.memo != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (s.time != null) s.time!,
                                        if (s.memo != null) s.memo!,
                                      ].join('  ·  '),
                                      style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 12,
                                          color: Color(0xFFAA9898)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (s.isLunar)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB8920A)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('음력',
                                    style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 10,
                                        color: Color(0xFFB8920A),
                                        fontWeight: FontWeight.w600)),
                              ),
                            if (s.repeatType != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.repeat,
                                    color: Color(0xFF8B7CB8), size: 15),
                              ),
                            if (s.alarmMinutesBefore != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.notifications_outlined,
                                    color: Color(0xFFAA9898), size: 16),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── 요일 헤더 셀 ────────────────────────────────────────────────────────────

  Widget _dowCell(DateTime day) {
    const names = {
      1: '월', 2: '화', 3: '수',
      4: '목', 5: '금', 6: '토', 7: '일',
    };
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    return Container(
      color: const Color(0xFFDDD4C4),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        names[day.weekday] ?? '',
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: isSun
              ? const Color(0xFFE05555)
              : isSat
                  ? const Color(0xFF70A8FF)
                  : const Color(0xFF4A4865),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── 날짜 셀 (양력 + 음력/명절 + Dot 마커) ────────────────────────────────────

  Widget _dayCell(DateTime day,
      {bool isSelected = false, bool isToday = false, bool isOutside = false}) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    final info = _engine.cellInfo(day);
    final scheduleCount = _scheduleCounts[_dateKey(day)] ?? 0;
    final apiEntry = _holidays[_dateKey(day)];

    final bool isPublicHoliday = apiEntry?.type == 'holiday';
    final bool isSolarTerm = apiEntry?.type == 'solar_term';

    // 날짜 숫자 색상: API 공휴일 / 일요일만 빨강 (음력 전통명절은 제외)
    final Color dayColor = (isPublicHoliday || isSun)
        ? const Color(0xFFE05555)
        : isSat
            ? const Color(0xFF70A8FF)
            : const Color(0xFF2D2B3A);

    // 하단 텍스트: API 데이터 우선 → 음력명절 → 음력날짜
    final String subText;
    final Color subColor;
    final double subFontSize;
    if (apiEntry != null) {
      subText = apiEntry.name;
      subColor = isSolarTerm
          ? const Color(0xFF80E080)   // 절기 → 초록
          : const Color(0xFFFFAA88);  // 공휴일 → 주황
      subFontSize = 13;  // API 공휴일/절기 이름
    } else if (info.holiday != null) {
      subText = info.holiday!;
      subColor = const Color(0xFFFFAA88);
      subFontSize = 13;
    } else {
      subText = info.lunarLabel;
      subColor = info.isSpecial ? const Color(0xFFB8920A) : const Color(0xFFAA9898);
      subFontSize = 13; // 순수 음력 날짜 (예: '4월 12일')
    }

    return Opacity(
      opacity: isOutside ? 0.28 : 1.0,
      child: Center(
        child: Container(
        width: 52,
        height: _rowHeight - 8,
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey, width: 1.5),
              )
            : isToday
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF8B7CB8).withValues(alpha: 0.18),
                  )
                : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 양력 날짜
            Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                color: dayColor,
                fontSize: 23, // ← 날짜 숫자 폰트 크기
                fontWeight: FontWeight.bold,
              ),
            ),
            // 일정 Dot 마커 — 날짜 숫자 바로 아래 (최대 3개, 고정 높이로 레이아웃 안정)
            SizedBox(
              height: 10,
              child: scheduleCount > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        scheduleCount.clamp(1, 3),
                        (_) => Container(
                          width: 7,
                          height: 7,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF8B7CB8),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // 음력 날짜 또는 명절 이름
            Text(
              subText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontFamilyFallback: const ['Pretendard'],
                color: subColor,
                fontSize: subFontSize,
                fontWeight: (info.isSpecial || info.holiday != null)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/calendar_engine.dart';
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
  final _apiService = HolidayApiService();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestAndroidPermission();
    });
  }

  Future<void> _loadHolidays(int year) async {
    if (_loadedHolidayYears.contains(year)) return;

    final cached = await DatabaseHelper.instance.getHolidaysByYear(year);
    List<Holiday> all;

    if (cached.isEmpty) {
      final results = await Future.wait([
        _apiService.fetchHolidays(year),
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
    final ym =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final list = await DatabaseHelper.instance.getSchedulesByMonth(ym);

    // 음력 매년 반복 일정 → 이 달에 해당하는 양력 날짜 계산
    final lunarYearly =
        await DatabaseHelper.instance.getLunarYearlySchedules();
    final lunarKeys = <String>[];
    for (final s in lunarYearly) {
      if (s.lunarMonth != null && s.lunarDay != null) {
        final solar =
            _engine.lunarToSolar(month.year, s.lunarMonth!, s.lunarDay!);
        if (solar != null &&
            solar.year == month.year &&
            solar.month == month.month) {
          lunarKeys.add(_dateKey(solar));
        }
      }
    }

    if (!mounted) return;
    final counts = <String, int>{};
    // 음력 매년 반복은 lunarKeys에서 카운트하므로 regular에서 제외
    for (final s in list) {
      if (s.isLunar && s.repeatType == 'yearly') continue;
      counts[s.solarDate] = (counts[s.solarDate] ?? 0) + 1;
    }
    for (final key in lunarKeys) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
    setState(() => _scheduleCounts = counts);
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _goToPrev() {
    final d = DateTime(_focusedDay.year, _focusedDay.month - 1);
    setState(() => _focusedDay = d);
    _loadSchedules(d);
    _loadHolidays(d.year);
  }

  void _goToNext() {
    final d = DateTime(_focusedDay.year, _focusedDay.month + 1);
    setState(() => _focusedDay = d);
    _loadSchedules(d);
    _loadHolidays(d.year);
  }

  Future<void> _onDayTap(DateTime selected, DateTime focused) async {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    await _loadSelectedDaySchedules(selected);
  }

  Future<void> _loadSelectedDaySchedules(DateTime day) async {
    final regular =
        await DatabaseHelper.instance.getSchedulesByDate(_dateKey(day));

    // 이 날의 음력 월·일에 해당하는 음력 매년 반복 일정 (regular에 없는 것만)
    final lunar = _engine.solarToLunar(day);
    final lunarYearly =
        await DatabaseHelper.instance.getLunarYearlySchedules();
    final regularIds = regular.map((s) => s.id).toSet();
    final matching = lunarYearly.where((s) =>
        s.lunarMonth == lunar.month &&
        s.lunarDay == lunar.day &&
        !regularIds.contains(s.id));

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildCalendar(),
                      const SizedBox(height: 4),
                      SizedBox(height: 190, child: _buildInfoPanel()),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더 ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_focusedDay.year}년',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.1,
                  ),
                ),
                Text(
                  _months[_focusedDay.month - 1],
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _NavButton(label: '이전 달', onTap: _goToPrev),
              const SizedBox(height: 10),
              _NavButton(label: '다음 달', isAccented: true, onTap: _goToNext),
            ],
          ),
        ],
      ),
    );
  }

  // ── 달력 카드 ────────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE4D4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFCEC5B4),
          width: 1,
        ),
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
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
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
          ),
        ),
      ),
    );
  }

  // ── 인라인 정보창 ─────────────────────────────────────────────────────────────

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE4D4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCEC5B4), width: 1),
      ),
      child: _selectedDay == null ? _panelPlaceholder() : _panelContent(),
    );
  }

  Widget _panelPlaceholder() => const Center(
        child: Text(
          '날짜를 선택하면 일정이 표시됩니다',
          style: TextStyle(color: Color(0xFFAA9898), fontSize: 13),
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2B3A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lunarLabel,
                          style: const TextStyle(
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
                    style: TextStyle(color: Color(0xFFAA9898), fontSize: 13),
                  ),
                )
              : ListView.separated(
                  itemCount: _selectedDaySchedules.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFCEC5B4)),
                  itemBuilder: (_, i) {
                    final s = _selectedDaySchedules[i];
                    return Dismissible(
                      key: Key('sp_${s.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteSchedule(s),
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
          color: isSun
              ? const Color(0xFF8B7CB8)
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
      {bool isSelected = false, bool isToday = false}) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    final info = _engine.cellInfo(day);
    final scheduleCount = _scheduleCounts[_dateKey(day)] ?? 0;
    final apiEntry = _holidays[_dateKey(day)];

    final bool isPublicHoliday = apiEntry?.type == 'holiday';
    final bool isSolarTerm = apiEntry?.type == 'solar_term';

    // 날짜 숫자 색상: API 공휴일 / 일요일만 빨강 (음력 전통명절은 제외)
    final Color dayColor = (isPublicHoliday || isSun)
        ? const Color(0xFF8B7CB8)
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
      subFontSize = 13;
    } else if (info.holiday != null) {
      subText = info.holiday!;
      subColor = const Color(0xFFFFAA88);
      subFontSize = 13;
    } else {
      subText = info.lunarLabel;
      subColor = info.isSpecial ? const Color(0xFFB8920A) : const Color(0xFFAA9898);
      subFontSize = 18;
    }

    return Center(
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
                color: dayColor,
                fontSize: 23, // ← 날짜 숫자 폰트 크기
                fontWeight: FontWeight.bold,
              ),
            ),
            // 일정 Dot 마커 — 날짜 숫자 바로 아래 (최대 3개, 고정 높이로 레이아웃 안정)
            SizedBox(
              height: 3, // ← 날짜 숫자↔음력 텍스트 사이 간격 / 도트 영역 높이
              child: scheduleCount > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        scheduleCount.clamp(1, 3),
                        (_) => Container(
                          width: 5,
                          height: 5,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 1.5),
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
    );
  }
}

// ── 네비게이션 버튼 ──────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAccented;

  const _NavButton({
    required this.label,
    required this.onTap,
    this.isAccented = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: isAccented
              ? const Color(0xFFE8C090)
              : const Color(0xFFF2E8D8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3D1E0A),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

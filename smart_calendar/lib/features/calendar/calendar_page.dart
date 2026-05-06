import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/calendar_engine.dart';
import '../../core/api/holiday_api_service.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/models/holiday.dart';
import '../schedule/day_schedule_sheet.dart';

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

  /// 날짜 키("YYYY-MM-DD") → 공휴일 or 절기 정보
  final Map<String, Holiday> _holidays = {};
  final Set<int> _loadedHolidayYears = {};

  final _engine = CalendarEngine.instance;
  final _apiService = HolidayApiService();

  static const _months = [
    '1월', '2월', '3월', '4월', '5월', '6월',
    '7월', '8월', '9월', '10월', '11월', '12월',
  ];

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
    if (!mounted) return;
    final counts = <String, int>{};
    for (final s in list) {
      counts[s.solarDate] = (counts[s.solarDate] ?? 0) + 1;
    }
    setState(() => _scheduleCounts = counts);
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _seasonText {
    final m = _focusedDay.month;
    if (m >= 3 && m <= 5) return '봄이 살랑살랑...';
    if (m >= 6 && m <= 8) return '여름이 활짝...';
    if (m >= 9 && m <= 11) return '가을이 물들어...';
    return '겨울이 꿈꾸고...';
  }

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
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DayScheduleSheet(date: selected),
    );
    if (mounted) _loadSchedules(focused);
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7272), Color(0xFFCC7840)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildCalendar()),
              const SizedBox(height: 12),
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
                  _months[_focusedDay.month - 1],
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.0,
                  ),
                ),
                Text(
                  '${_focusedDay.year}년',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _seasonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF5C2A10),
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
        color: const Color(0x80203C3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
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
          rowHeight: 64,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            // 요일 헤더
            dowBuilder: (context, day) => _dowCell(day),
            // 날짜 셀
            defaultBuilder: (context, day, _) => _dayCell(day),
            todayBuilder: (context, day, _) => _dayCell(day, isToday: true),
            selectedBuilder: (context, day, _) =>
                _dayCell(day, isSelected: true),
          ),
        ),
      ),
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
      color: const Color(0xFF1B3A3A),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        names[day.weekday] ?? '',
        style: TextStyle(
          color: isSun
              ? const Color(0xFFFF7070)
              : isSat
                  ? const Color(0xFF70A8FF)
                  : Colors.white60,
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
        ? const Color(0xFFFF7070)
        : isSat
            ? const Color(0xFF70A8FF)
            : Colors.white;

    // 하단 텍스트: API 데이터 우선 → 음력명절 → 음력날짜
    final String subText;
    final Color subColor;
    if (apiEntry != null) {
      subText = apiEntry.name;
      subColor = isSolarTerm
          ? const Color(0xFF80E080)   // 절기 → 초록
          : const Color(0xFFFFAA88);  // 공휴일 → 주황
    } else if (info.holiday != null) {
      subText = info.holiday!;
      subColor = const Color(0xFFFFAA88);
    } else {
      subText = info.lunarLabel;
      subColor = info.isSpecial ? const Color(0xFFFFD060) : Colors.white38;
    }

    return Center(
      child: Container(
        width: 44,
        height: 58,
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              )
            : isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            // 음력 날짜 또는 명절 이름
            Text(
              subText,
              style: TextStyle(
                color: subColor,
                fontSize: 8,
                fontWeight: (info.isSpecial || info.holiday != null)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
            // 일정 Dot 마커 (최대 3개)
            if (scheduleCount > 0) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  scheduleCount.clamp(1, 3),
                  (_) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFD060),
                    ),
                  ),
                ),
              ),
            ],
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

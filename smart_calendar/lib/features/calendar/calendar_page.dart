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
  int _monthTransitionDirection = 1;

  /// 날짜 키("YYYY-MM-DD") → 해당 날짜 일정 수
  Map<String, int> _scheduleCounts = {};

  List<Schedule> _selectedDaySchedules = [];

  /// 날짜 키("YYYY-MM-DD") → 공휴일 or 절기 정보
  final Map<String, Holiday> _holidays = {};
  final Set<int> _loadedHolidayYears = {};

  final _engine = CalendarEngine.instance;
  final _googleService = GoogleCalendarService();
  final _apiService = HolidayApiService(); // 24절기 전용

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthImages = [
    'image/01_JAN.png',
    'image/02_FEB.png',
    'image/03_MAR.png',
    'image/04_APR.png',
    'image/05_MAY.png',
    'image/06_JUN.png',
    'image/07_JUL.png',
    'image/08_AUG.png',
    'image/09_SEP.png',
    'image/10_OCT.png',
    'image/11_NOV.png',
    'image/12_DEC.png',
  ];

  static const _rowHeight = 66.0; // 날짜 행 높이
  static const _dowHeight = 38.0; // 요일 헤더 행 높이

  // ── 라이프사이클 ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSchedules(_focusedDay);
    _loadHolidays(_focusedDay.year);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final path in _monthImages) {
        await precacheImage(AssetImage(path), context);
      }
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

  static int _monthIndex(DateTime d) => d.year * 12 + d.month;

  String get _monthPageKey => '${_focusedDay.year}-${_focusedDay.month}';

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
          final solar = _engine.lunarToSolar(
            month.year,
            s.lunarMonth!,
            s.lunarDay!,
          );
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
    final regular = await DatabaseHelper.instance.getSchedulesByDate(
      _dateKey(day),
    );
    final regularIds = regular.map((s) => s.id).toSet();

    // 모든 반복 일정 중 이 날에 해당하는 것 추가 (중복 제외)
    final allRepeats = await DatabaseHelper.instance.getAllRepeatSchedules();
    final matching = allRepeats.where(
      (s) => _isRepeatMatchingDay(s, day) && !regularIds.contains(s.id),
    );

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
      backgroundColor: const Color(0xFFF7F8F6),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey(_monthPageKey);
          final direction = _monthTransitionDirection.toDouble();
          final begin = Offset(isIncoming ? direction : -direction, 0);
          final offsetAnimation = Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(animation);

          return ClipRect(
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: Container(
          key: ValueKey(_monthPageKey),
          color: const Color(0xFFF7F8F6),
          child: Stack(
            children: [
              _buildHeroBackground(),
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 44, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 14),
                              _buildCalendar(),
                              const SizedBox(height: 12),
                              _buildInfoPanel(),
                              const SizedBox(height: 22),
                              _buildFooter(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${_focusedDay.month}',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 72,
            height: 0.86,
            fontWeight: FontWeight.w400,
            color: Color(0xFF2F3135),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_focusedDay.year}',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4D535B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _monthNames[_focusedDay.month - 1],
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 33,
                  height: 1.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2F3135),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBackground() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 330,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3F8),
            image: DecorationImage(
              image: AssetImage(_monthImages[_focusedDay.month - 1]),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              colorFilter: const ColorFilter.mode(
                Color(0x1AFFFFFF),
                BlendMode.screen,
              ),
            ),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x1AF2FAFF),
                  Color(0x14F7FBFF),
                  Color(0x08FFFFFF),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 달력 카드 ────────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
            final previousIndex = _monthIndex(_focusedDay);
            final nextIndex = _monthIndex(focused);
            setState(() {
              _monthTransitionDirection = nextIndex >= previousIndex ? 1 : -1;
              _focusedDay = focused;
            });
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
            todayBuilder: (context, day, _) => _dayCell(day, isToday: true),
            selectedBuilder: (context, day, _) =>
                _dayCell(day, isSelected: true),
            outsideBuilder: (context, day, _) => _dayCell(day, isOutside: true),
          ),
        ),
      ),
    );
  }

  // ── 인라인 정보창 ─────────────────────────────────────────────────────────────

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  Widget _buildInfoPanel() {
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _selectedDay == null ? _panelPlaceholder() : _panelContent(),
    );
  }

  Widget _panelPlaceholder() => const Center(
    child: Text(
      '날짜를 선택하면 일정이 표시됩니다',
      style: TextStyle(
        fontFamily: 'Pretendard',
        color: Color(0xFF8A8F98),
        fontSize: 13,
      ),
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
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3E4248),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lunarLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: ['Pretendard'],
                            fontSize: 11,
                            color: Color(0xFF7A818C),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+ 일정 추가',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF3C74D9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEAECEF)),
        Expanded(
          child: _selectedDaySchedules.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 일정이 없습니다',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF8A8F98),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _selectedDaySchedules.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEAECEF)),
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
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: Color(s.categoryColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF33373D),
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
                                        fontSize: 11,
                                        color: Color(0xFF747B86),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (s.isLunar)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFB8920A,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '음력',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 10,
                                    color: Color(0xFFB8920A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (s.repeatType != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.repeat,
                                  color: Color(0xFF8B7CB8),
                                  size: 15,
                                ),
                              ),
                            if (s.alarmMinutesBefore != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.notifications_outlined,
                                  color: Color(0xFFAA9898),
                                  size: 16,
                                ),
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
      1: 'MON',
      2: 'TUE',
      3: 'WED',
      4: 'THU',
      5: 'FRI',
      6: 'SAT',
      7: 'SUN',
    };
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Text(
        names[day.weekday] ?? '',
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: isSun
              ? const Color(0xFFFF3B30)
              : isSat
              ? const Color(0xFF2E73D8)
              : const Color(0xFF50545C),
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── 날짜 셀 (양력 + 음력/명절 + Dot 마커) ────────────────────────────────────

  Widget _dayCell(
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    final info = _engine.cellInfo(day);
    final scheduleCount = _scheduleCounts[_dateKey(day)] ?? 0;
    final apiEntry = _holidays[_dateKey(day)];

    final bool isPublicHoliday = apiEntry?.type == 'holiday';
    final bool isSolarTerm = apiEntry?.type == 'solar_term';

    // 날짜 숫자 색상: API 공휴일 / 일요일만 빨강 (음력 전통명절은 제외)
    final Color dayColor = (isPublicHoliday || isSun)
        ? const Color(0xFFFF3B30)
        : isSat
        ? const Color(0xFF2E73D8)
        : const Color(0xFF2F3135);

    // 하단 텍스트: API 데이터 우선 → 음력명절 → 음력날짜
    final String subText;
    final Color subColor;
    final double subFontSize;
    if (apiEntry != null) {
      subText = apiEntry.name;
      subColor = isSolarTerm
          ? const Color(0xFF4FA96A)
          : const Color(0xFFFF6E4A);
      subFontSize = 8.5;
    } else if (info.holiday != null) {
      subText = info.holiday!;
      subColor = const Color(0xFFFF6E4A);
      subFontSize = 8.5;
    } else {
      subText = info.lunarLabel;
      subColor = info.isSpecial
          ? const Color(0xFFB8920A)
          : const Color(0xFF656B75);
      subFontSize = 13;
    }

    return Opacity(
      opacity: isOutside ? 0.28 : 1.0,
      child: Center(
        child: Container(
          width: 43,
          height: _rowHeight - 4,
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEDEFF5),
                )
              : isToday
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFEAF2FF),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 양력 날짜 폰트 조절: fontFamily, fontSize, fontWeight 수정
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  color: dayColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // 일정 Dot 마커 — 날짜 숫자 바로 아래 (최대 3개, 고정 높이로 레이아웃 안정)
              SizedBox(
                height: 7,
                child: scheduleCount > 0
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          scheduleCount.clamp(1, 3),
                          (_) => Container(
                            width: 5,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF3678CF),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              // 음력 날짜 폰트 조절: subFontSize와 아래 TextStyle 수정
              Text(
                subText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['Pretendard'],
                  color: subColor,
                  fontSize: subFontSize,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        '오늘도 당신의 하루를 응원합니다',
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 12,
          color: Color(0xFF8A8F98),
        ),
      ),
    );
  }
}
